<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="com.example.demo.model.Payroll, java.math.BigDecimal, java.math.RoundingMode, java.time.Month, java.time.format.TextStyle, java.util.Locale" %>
<%@ page import="java.sql.Connection, java.sql.PreparedStatement, java.sql.ResultSet" %>
<%
    // =========================================================================
    // 1. DYNAMIC COMPANY BRANDING LOADER (Logo, Name, Address, Support Email)
    // =========================================================================
    String slipLogoUrl = (String) application.getAttribute("COMPANY_LOGO_URL");
    String slipCompanyName = (String) application.getAttribute("COMPANY_NAME");
    String slipCompanyAddress = (String) application.getAttribute("COMPANY_ADDRESS");
    String slipCompanyEmail = (String) application.getAttribute("COMPANY_EMAIL");

    try {
        String propsPath = application.getRealPath("/WEB-INF/branding.properties");
        java.io.File propFile = new java.io.File(propsPath);
        if (propFile.exists()) {
            java.util.Properties props = new java.util.Properties();
            try (java.io.FileInputStream fis = new java.io.FileInputStream(propFile)) {
                props.load(fis);
            }
            if (slipLogoUrl == null || slipLogoUrl.isBlank()) slipLogoUrl = props.getProperty("COMPANY_LOGO_URL", "");
            if (slipCompanyName == null || slipCompanyName.isBlank()) slipCompanyName = props.getProperty("COMPANY_NAME", "");
            if (slipCompanyAddress == null || slipCompanyAddress.isBlank()) slipCompanyAddress = props.getProperty("COMPANY_ADDRESS", "");
            if (slipCompanyEmail == null || slipCompanyEmail.isBlank()) slipCompanyEmail = props.getProperty("COMPANY_EMAIL", "");
        }
    } catch (Exception ignored) {}

    // Fallback to database system_settings if any field is still empty
    if (slipCompanyName == null || slipCompanyName.isBlank() ||
        slipCompanyAddress == null || slipCompanyAddress.isBlank() ||
        slipCompanyEmail == null || slipCompanyEmail.isBlank()) {
        try (Connection conn = com.Util.DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(
                 "SELECT setting_key, setting_value FROM system_settings WHERE setting_key IN ('COMPANY_NAME', 'COMPANY_ADDRESS', 'COMPANY_EMAIL')");
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                String k = rs.getString("setting_key");
                String v = rs.getString("setting_value");
                if ("COMPANY_NAME".equalsIgnoreCase(k) && v != null && !v.isBlank()) {
                    slipCompanyName = v.trim();
                    application.setAttribute("COMPANY_NAME", slipCompanyName);
                } else if ("COMPANY_ADDRESS".equalsIgnoreCase(k) && v != null && !v.isBlank()) {
                    slipCompanyAddress = v.trim();
                    application.setAttribute("COMPANY_ADDRESS", slipCompanyAddress);
                } else if ("COMPANY_EMAIL".equalsIgnoreCase(k) && v != null && !v.isBlank()) {
                    slipCompanyEmail = v.trim();
                    application.setAttribute("COMPANY_EMAIL", slipCompanyEmail);
                }
            }
        } catch (Exception ignored) {}
    }

    if (slipLogoUrl == null) slipLogoUrl = "";
    if (slipCompanyName == null || slipCompanyName.isBlank()) slipCompanyName = "SmartOffice Technologies Pvt Ltd";
    if (slipCompanyAddress == null || slipCompanyAddress.isBlank()) slipCompanyAddress = "HITEC City, Hyderabad";
    if (slipCompanyEmail == null || slipCompanyEmail.isBlank()) slipCompanyEmail = "support@smartoffice.com";

    // =========================================================================
    // 2. PAYROLL & EMPLOYEE DATA RESOLUTION
    // =========================================================================
    Payroll p = (Payroll) request.getAttribute("payroll");

    if (p == null) {
        String idStr = request.getParameter("id");
        if (idStr != null && !idStr.isBlank()) {
            com.dao.PayrollDAO dao = new com.dao.PayrollDAO();
            p = dao.getPayrollById(Integer.parseInt(idStr.trim()));
        }
    }

    if (p == null) {
        response.sendRedirect(request.getContextPath() + "/dashboard.jsp?tab=tab-allpayslips&error=Payroll+record+not+found");
        return;
    }

    com.dao.PayrollDAO dao = new com.dao.PayrollDAO();
    java.util.Map<String, String> profile = dao.getEmployeeProfileForSalary(p.getEmployeeId());

    String empId = p.getEmployeeId().trim();
    String empName = (p.getEmployeeName() != null && !p.getEmployeeName().isBlank()) ? p.getEmployeeName() : profile.getOrDefault("name", "Employee");
    String empDept = (p.getDepartment() != null && !p.getDepartment().isBlank()) ? p.getDepartment() : profile.getOrDefault("department", "IT");
    String designation = profile.getOrDefault("designation", "Staff");
    String joiningDate = profile.getOrDefault("joiningDate", "-");
    
    // Robust resolution of Bank Name, Account Number, PAN, and UAN
    String bankName = profile.get("bankName");
    String bankAcc = profile.get("bankAccount");
    String panNo = profile.getOrDefault("panNo", "-");
    String uanNo = profile.getOrDefault("uanNo", "-");

    // Deep lookup across employee tables to ensure no details are missed
    if (bankName == null || bankName.isBlank() || "-".equals(bankName.trim()) ||
        bankAcc == null || bankAcc.isBlank() || "-".equals(bankAcc.trim()) ||
        "-".equals(panNo) || "-".equals(uanNo)) {
        
        String sqlDeep = "SELECT bank_name, account_number, joining_date, pan_number, uan_number FROM employee WHERE LOWER(TRIM(REPLACE(employee_id, ' ', ''))) = LOWER(TRIM(REPLACE(?, ' ', ''))) LIMIT 1";
        try (Connection conn = com.Util.DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sqlDeep)) {
            ps.setString(1, empId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    String b = rs.getString("bank_name");
                    String a = rs.getString("account_number");
                    java.sql.Date jDate = rs.getDate("joining_date");
                    String pan = rs.getString("pan_number");
                    String uan = rs.getString("uan_number");

                    if (b != null && !b.isBlank() && !"-".equals(b.trim())) bankName = b.trim();
                    if (a != null && !a.isBlank() && !"-".equals(a.trim())) bankAcc = a.trim();
                    if (pan != null && !pan.isBlank() && !"-".equals(pan.trim())) panNo = pan.trim();
                    if (uan != null && !uan.isBlank() && !"-".equals(uan.trim())) uanNo = uan.trim();
                    if (jDate != null && ("-".equals(joiningDate) || joiningDate.isBlank())) joiningDate = jDate.toString();
                }
            }
        } catch (Exception ignored) {}
    }

    // Default formatting if still blank
    if (bankName == null || bankName.isBlank()) bankName = "--";
    if (bankAcc == null || bankAcc.isBlank()) bankAcc = "--";

    String monthName = Month.of(p.getPayrollMonth()).getDisplayName(TextStyle.FULL, Locale.ENGLISH);
    int yearVal = p.getPayrollYear();

    // Base salary components
    BigDecimal basic = p.getBasicSalary() != null ? p.getBasicSalary() : BigDecimal.ZERO;
    BigDecimal gross = p.getGrossSalary() != null ? p.getGrossSalary() : BigDecimal.ZERO;
    BigDecimal deductions = p.getTotalDeductions() != null ? p.getTotalDeductions() : BigDecimal.ZERO;

    // Overtime (OT) calculations (Standard: OT Rate = (Gross / 240) * 1.5)
    BigDecimal otHours = BigDecimal.ZERO;
    BigDecimal otHourlyRate = BigDecimal.ZERO;
    BigDecimal otAmount = BigDecimal.ZERO;

    try {
        java.lang.reflect.Method mHours = p.getClass().getMethod("getOtHours");
        Object valH = mHours.invoke(p);
        if (valH != null) otHours = new BigDecimal(valH.toString());

        java.lang.reflect.Method mAmount = p.getClass().getMethod("getOtAmount");
        Object valA = mAmount.invoke(p);
        if (valA != null) otAmount = new BigDecimal(valA.toString());
    } catch (Exception ignored) {}

    // Fallback: If not populated in model, pull live from database
    if (otHours.compareTo(BigDecimal.ZERO) == 0) {
        String sqlOt = "SELECT ot_hours, ot_hourly_rate, ot_amount FROM payroll WHERE id = ?";
        try (Connection conn = com.Util.DBConnection.getConnection();
             PreparedStatement psOt = conn.prepareStatement(sqlOt)) {
            psOt.setInt(1, p.getId());
            try (ResultSet rsOt = psOt.executeQuery()) {
                if (rsOt.next()) {
                    otHours = rsOt.getBigDecimal("ot_hours") != null ? rsOt.getBigDecimal("ot_hours") : BigDecimal.ZERO;
                    otHourlyRate = rsOt.getBigDecimal("ot_hourly_rate") != null ? rsOt.getBigDecimal("ot_hourly_rate") : BigDecimal.ZERO;
                    otAmount = rsOt.getBigDecimal("ot_amount") != null ? rsOt.getBigDecimal("ot_amount") : BigDecimal.ZERO;
                }
            }
        } catch (Exception ignored) {}
    }

    if (otHours.compareTo(BigDecimal.ZERO) > 0 && otAmount.compareTo(BigDecimal.ZERO) == 0 && gross.compareTo(BigDecimal.ZERO) > 0) {
        otHourlyRate = gross.divide(new BigDecimal("240"), 4, RoundingMode.HALF_UP).multiply(new BigDecimal("1.5")).setScale(2, RoundingMode.HALF_UP);
        otAmount = otHours.multiply(otHourlyRate).setScale(2, RoundingMode.HALF_UP);
    }

    // Standard Breakdown Allowances
    BigDecimal da = basic.multiply(new BigDecimal("0.55")).setScale(2, RoundingMode.HALF_UP);
    BigDecimal hra = basic.multiply(new BigDecimal("0.50")).setScale(2, RoundingMode.HALF_UP);
    BigDecimal conveyance = new BigDecimal("1600.00");
    BigDecimal medical = new BigDecimal("1250.00");

    BigDecimal fixedComponents = basic.add(da).add(hra).add(conveyance).add(medical);
    BigDecimal special = gross.subtract(fixedComponents);
    if (special.compareTo(BigDecimal.ZERO) < 0) special = BigDecimal.ZERO;

    // Deductions: PT, PF, and LOP
    BigDecimal profTax = new BigDecimal("200.00");
    BigDecimal pf = (gross.compareTo(new BigDecimal("40000.00")) >= 0) 
                    ? new BigDecimal("3600.00") 
                    : basic.multiply(new BigDecimal("0.12")).setScale(2, RoundingMode.HALF_UP);
    
    BigDecimal lopDeduction = deductions.subtract(profTax.add(pf));
    if (lopDeduction.compareTo(BigDecimal.ZERO) < 0) lopDeduction = BigDecimal.ZERO;

    // Accurate totals reconciliation
    BigDecimal totalEarnings = basic.add(da).add(hra).add(conveyance).add(medical).add(special).add(otAmount);
    BigDecimal totalDeductions = profTax.add(pf).add(lopDeduction);
    BigDecimal netTakeHome = totalEarnings.subtract(totalDeductions);
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Payslip for the month of <%= monthName %> <%= yearVal %> - <%= p.getEmployeeId() %></title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif; }
        body { background: #64748b; padding: 30px 15px; display: flex; flex-direction: column; align-items: center; }
        
        .top-action-bar { width: 100%; max-width: 800px; margin-bottom: 12px; display: flex; justify-content: space-between; }
        .btn-action { padding: 7px 16px; background: #fff; border: 1px solid #cbd5e1; border-radius: 6px; font-weight: 700; font-size: 13px; cursor: pointer; text-decoration: none; color: #0f172a; }
        .btn-action:hover { background: #f1f5f9; }

        .payslip-sheet { 
            background: #ffffff; 
            width: 100%; 
            max-width: 800px; 
            border: 1px solid #1e293b; 
            padding: 30px 36px; 
            box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.2); 
        }

        .header-title-box { text-align: center; margin-bottom: 18px; }
        .header-logo { height: 54px; max-width: 170px; object-fit: contain; margin: 0 auto 8px; display: block; }
        .header-title-box h2 { font-size: 18px; font-weight: 800; text-transform: uppercase; letter-spacing: 0.5px; color: #000; }
        .header-title-box p { font-size: 12px; margin-top: 3px; color: #333; }
        .header-title-box .payslip-sub { font-size: 13.5px; font-weight: 700; margin-top: 7px; color: #000; }

        .meta-grid-table { width: 100%; border-top: 1px solid #000; border-bottom: 1px solid #000; font-size: 12px; border-collapse: collapse; margin-bottom: 12px; }
        .meta-grid-table td { padding: 5px 8px; vertical-align: top; }
        .meta-grid-table td:nth-child(1), .meta-grid-table td:nth-child(3) { width: 18%; color: #222; }
        .meta-grid-table td:nth-child(2), .meta-grid-table td:nth-child(4) { width: 32%; font-weight: 600; color: #000; }

        .breakdown-table { width: 100%; border-collapse: collapse; font-size: 12px; margin-top: 6px; }
        .breakdown-table th { padding: 6px 8px; text-align: left; font-weight: 800; border-bottom: 1px solid #000; }
        .breakdown-table td { padding: 5px 8px; vertical-align: top; }
        .text-right { text-align: right; }

        .total-summary-row { border-top: 1px solid #000; border-bottom: 1px solid #000; font-weight: 800; }
        .net-salary-block { border-bottom: 1px solid #000; padding: 10px 8px; margin-top: 10px; font-size: 13px; color: #000; }

        .disclaimer-text { text-align: center; font-size: 11px; margin-top: 36px; color: #475569; }
        .company-bottom-sign { text-align: center; margin-top: 14px; font-size: 11px; color: #1e3a8a; }

        @media print {
            body { background: #fff; padding: 0; }
            .top-action-bar { display: none; }
            .payslip-sheet { border: none; box-shadow: none; max-width: 100%; padding: 0; }
        }
    </style>
</head>
<body>

<div class="top-action-bar">
    <button type="button" onclick="history.back()" class="btn-action">← Back</button>
    <button type="button" onclick="window.print()" class="btn-action">🖶 Print / Save PDF</button>
</div>

<div class="payslip-sheet">
    <div class="header-title-box">
        <% if (!slipLogoUrl.isEmpty()) { %>
            <img src="<%= slipLogoUrl %>" alt="Company Logo" class="header-logo">
        <% } %>
        <h2><%= slipCompanyName %></h2>
        <p><%= slipCompanyAddress %></p>
        <p class="payslip-sub">Payslip for the month of <%= monthName %> <%= yearVal %></p>
    </div>

    <!-- Employee Metadata Table -->
    <table class="meta-grid-table">
        <tr>
            <td>Name:</td>
            <td><%= empName %></td>
            <td>Employee No:</td>
            <td><%= p.getEmployeeId() %></td>
        </tr>
        <tr>
            <td>Joining Date:</td>
            <td><%= joiningDate %></td>
            <td>Bank Name:</td>
            <td><%= bankName %></td>
        </tr>
        <tr>
            <td>Designation:</td>
            <td><%= designation %></td>
            <td>Bank Account No:</td>
            <td><%= bankAcc %></td>
        </tr>
        <tr>
            <td>Department:</td>
            <td><%= empDept %></td>
            <td>PAN No:</td>
            <td><%= panNo %></td>
        </tr>
        <tr>
            <td>Work Days:</td>
            <td><%= p.getWorkingDays() %></td>
            <td>UAN No:</td>
            <td><%= uanNo %></td>
        </tr>
        <tr>
            <td>LOP Days:</td>
            <td><%= p.getUnpaidLeaveDays() %></td>
            <td></td>
            <td></td>
        </tr>
    </table>

    <!-- Compensation Breakdown Table -->
    <table class="breakdown-table">
        <thead>
            <tr>
                <th style="width: 34%;">Earnings</th>
                <th class="text-right" style="width: 16%;">Actual</th>
                <th style="width: 34%;">Deductions</th>
                <th class="text-right" style="width: 16%;">Actual</th>
            </tr>
        </thead>
        <tbody>
            <tr>
                <td>BASIC</td>
                <td class="text-right"><%= String.format("%.2f", basic) %></td>
                <td>PROF TAX</td>
                <td class="text-right"><%= String.format("%.2f", profTax) %></td>
            </tr>
            <tr>
                <td>DA</td>
                <td class="text-right"><%= String.format("%.2f", da) %></td>
                <td>PF</td>
                <td class="text-right"><%= String.format("%.2f", pf) %></td>
            </tr>
            <tr>
                <td>HRA</td>
                <td class="text-right"><%= String.format("%.2f", hra) %></td>
                <td>LOSS OF PAY</td>
                <td class="text-right"><%= String.format("%.2f", lopDeduction) %></td>
            </tr>
            <tr>
                <td>CONVEYANCE</td>
                <td class="text-right"><%= String.format("%.2f", conveyance) %></td>
                <td></td>
                <td class="text-right"></td>
            </tr>
            <tr>
                <td>MEDICAL ALLOWANCE</td>
                <td class="text-right"><%= String.format("%.2f", medical) %></td>
                <td></td>
                <td class="text-right"></td>
            </tr>
            <tr>
                <td>SPECIAL ALLOWANCE</td>
                <td class="text-right"><%= String.format("%.2f", special) %></td>
                <td></td>
                <td class="text-right"></td>
            </tr>
            <% if (otHours.compareTo(BigDecimal.ZERO) > 0) { %>
            <tr>
                <td style="color: #059669; font-weight: 700;">OVERTIME PAY (<%= otHours %> hrs @ 1.5x)</td>
                <td class="text-right" style="color: #059669; font-weight: 700;"><%= String.format("%.2f", otAmount) %></td>
                <td></td>
                <td class="text-right"></td>
            </tr>
            <% } %>
            <tr class="total-summary-row">
                <td>Total Earnings:</td>
                <td class="text-right">INR <%= String.format("%.2f", totalEarnings) %></td>
                <td>Total Deductions:</td>
                <td class="text-right">INR <%= String.format("%.2f", totalDeductions) %></td>
            </tr>
        </tbody>
    </table>

    <div class="net-salary-block">
        <strong>Net Pay for the month: INR <%= String.format("%.2f", netTakeHome) %></strong>
    </div>

    <div class="disclaimer-text">
        This is a system generated payslip and does not require a physical signature.
    </div>

    <div class="company-bottom-sign">
        <strong><%= slipCompanyName.toUpperCase() %></strong><br>
        <%= slipCompanyAddress %><br>
        Email: <%= slipCompanyEmail %>
    </div>
</div>

</body>
</html>l>