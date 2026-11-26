<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="com.example.demo.model.Employee,com.example.demo.model.Payroll, java.util.List, java.time.Month, java.time.format.TextStyle, java.util.Locale" %>
<%
    Employee loggedIn = (Employee) session.getAttribute("loggedInEmployee");
    if (loggedIn == null) {
        response.sendRedirect(request.getContextPath() + "/login.jsp");
        return;
    }

    String role = (loggedIn.getRole() != null) ? loggedIn.getRole().trim().toUpperCase() : "";
    boolean isHrOrAdmin = "HR".equals(role) || "ADMIN".equals(role) || loggedIn.isHrDesignation();

    List<Payroll> payrollList = (List<Payroll>) request.getAttribute("payrollList");
    if (payrollList == null) {
        com.dao.PayrollDAO dao = new com.dao.PayrollDAO();
        if (isHrOrAdmin) {
            payrollList = dao.getPayrollHistory(null, null, null);
        } else {
            payrollList = dao.getPayrollHistory(loggedIn.getEmployeeId(), null, null);
        }
    }
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Salary Management | Speshway HRMS</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@500;600&display=swap" rel="stylesheet">
    <style>
        :root {
            --brand-primary: #1e3a8a;
            --brand-accent: #2563eb;
            --slate-50: #f8fafc;
            --slate-100: #f1f5f9;
            --slate-200: #e2e8f0;
            --slate-300: #cbd5e1;
            --slate-500: #64748b;
            --slate-700: #334155;
            --slate-900: #0f172a;
            --radius-md: 10px;
            --radius-lg: 14px;
        }

        * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Plus Jakarta Sans', sans-serif; }
        body { background-color: #f4f6f9; color: var(--slate-900); padding: 34px 24px; }
        .container { max-width: 1140px; margin: 0 auto; }

        .card { 
            background: #ffffff; 
            border: 1px solid var(--slate-200); 
            border-radius: var(--radius-lg); 
            padding: 30px; 
            box-shadow: 0 4px 6px -1px rgba(15, 23, 42, 0.05); 
        }

        .header-bar { 
            display: flex; 
            justify-content: space-between; 
            align-items: center; 
            border-bottom: 1px solid var(--slate-200); 
            padding-bottom: 20px; 
            margin-bottom: 24px; 
        }
        .header-bar h1 { font-size: 22px; font-weight: 800; }
        .header-bar p { font-size: 13px; color: var(--slate-500); margin-top: 4px; }

        .btn { 
            font-family: inherit; 
            font-size: 13px; 
            font-weight: 700; 
            padding: 8px 16px; 
            border-radius: 8px; 
            cursor: pointer; 
            text-decoration: none; 
            display: inline-flex; 
            align-items: center; 
            gap: 6px; 
            border: 1px solid var(--slate-300);
            background: #fff;
            color: var(--slate-700);
        }
        .btn:hover { background: var(--slate-50); }
        .btn-primary { background: var(--brand-accent); color: #fff; border-color: var(--brand-accent); }
        .btn-primary:hover { background: #1d4ed8; }

        .filter-panel { 
            background: #f8fafc; 
            border: 1px solid var(--slate-200); 
            border-radius: var(--radius-md); 
            padding: 16px 20px; 
            margin-bottom: 24px; 
            display: flex; 
            gap: 16px; 
            align-items: flex-end; 
        }
        .filter-group { display: flex; flex-direction: column; gap: 5px; flex: 1; }
        .filter-label { font-size: 11px; font-weight: 700; color: var(--slate-500); text-transform: uppercase; }
        .filter-input { height: 38px; border: 1px solid var(--slate-300); border-radius: 6px; padding: 0 10px; font-size: 13px; background: #fff; }

        .table-responsive { width: 100%; overflow-x: auto; }
        .data-table { width: 100%; border-collapse: collapse; font-size: 13px; }
        .data-table th { 
            background: #f8fafc; 
            padding: 12px 14px; 
            text-align: left; 
            font-weight: 800; 
            color: var(--slate-500); 
            text-transform: uppercase; 
            font-size: 11px; 
            letter-spacing: 0.04em; 
            border-bottom: 1px solid var(--slate-200); 
        }
        .data-table td { padding: 14px; border-bottom: 1px solid var(--slate-200); vertical-align: middle; }
        .data-table tr:hover { background-color: #fafbfc; }

        .mono { font-family: 'JetBrains Mono', monospace; font-size: 13px; }
        .amount-green { color: #059669; font-weight: 700; }

        .badge-processed { 
            display: inline-flex; 
            align-items: center; 
            gap: 5px; 
            background: #fef3c7; 
            color: #92400e; 
            padding: 4px 10px; 
            border-radius: 20px; 
            font-size: 11.5px; 
            font-weight: 700; 
        }
        .badge-processed::before { content: "•"; font-size: 14px; }

        .action-link { 
            display: inline-flex; 
            align-items: center; 
            justify-content: center; 
            width: 32px; 
            height: 32px; 
            border-radius: 6px; 
            color: var(--slate-700); 
            text-decoration: none; 
            border: 1px solid var(--slate-200); 
        }
        .action-link:hover { background: #e2e8f0; }
    </style>
</head>
<body>

<div class="container">
    <div class="card">
        <div class="header-bar">
            <div>
                <h1>Salary Management</h1>
                <p>Organization-wide automated payroll distributions, vouchers, and audit trail[cite: 4].</p>
            </div>
            <div style="display: flex; gap: 10px;">

                <a href="<%= request.getContextPath() %>/dashboard.jsp" class="btn">&larr; Back to Dashboard</a>
            </div>
        </div>

        <!-- Filter Panel -->
        <form method="get" action="<%= request.getContextPath() %>/payroll/history" class="filter-panel">
            <div class="filter-group">
                <label class="filter-label">Filter Employee ID</label>
                <input type="text" name="empId" class="filter-input" placeholder="e.g. EMP101" value="<%= request.getParameter("empId") != null ? request.getParameter("empId") : "" %>">
            </div>
            <div class="filter-group">
                <label class="filter-label">Payroll Month</label>
                <select name="month" class="filter-input">
                    <option value="">All Months</option>
                    <% for (int m = 1; m <= 12; m++) { 
                        String mName = Month.of(m).getDisplayName(TextStyle.FULL, Locale.ENGLISH);
                    %>
                        <option value="<%= m %>"><%= mName %></option>
                    <% } %>
                </select>
            </div>
            <div class="filter-group">
                <label class="filter-label">Payroll Year</label>
                <input type="number" name="year" class="filter-input" value="2026">
            </div>
            <button type="submit" class="btn btn-primary" style="height: 38px;">Filter Records</button>
            <a href="<%= request.getContextPath() %>/payroll/history" class="btn" style="height: 38px;">Reset</a>
        </form>

        <h3 style="font-size: 15px; font-weight: 800; margin-bottom: 14px;">Salary Records</h3>
        <div class="table-responsive">
            <table class="data-table">
                <thead>
                    <tr>
                        <th style="width: 60px;">SNO</th>
                        <th>EMP ID</th>
                        <th>EMPLOYEE NAME</th>
                        <th>PERIOD</th>
                        <th>TOTAL EARNINGS</th>
                        <th>NET PAY</th>
                        <th>STATUS</th>
                        <th style="text-align: center; width: 100px;">ACTIONS</th>
                    </tr>
                </thead>
                <tbody>
                    <% if (payrollList != null && !payrollList.isEmpty()) { 
                        int count = 1;
                        for (Payroll p : payrollList) {
                            String pMonth = Month.of(p.getPayrollMonth()).getDisplayName(TextStyle.FULL, Locale.ENGLISH);
                    %>
                        <tr>
                            <td><%= count++ %></td>
                            <td class="mono" style="font-weight: 700;"><%= p.getEmployeeId() %></td>
                            <td>
                                <div style="font-weight: 700;"><%= p.getEmployeeName() != null ? p.getEmployeeName() : "Employee" %></div>
                                <div style="font-size: 11px; color: var(--slate-500);"><%= p.getDepartment() != null ? p.getDepartment() : "General" %></div>
                            </td>
                            <td>
                                <div style="font-weight: 600;"><%= pMonth %></div>
                                <div style="font-size: 11px; color: var(--slate-500);"><%= p.getPayrollYear() %></div>
                            </td>
                            <td class="mono">INR <%= String.format("%.2f", p.getGrossSalary() != null ? p.getGrossSalary() : java.math.BigDecimal.ZERO) %></td>
                            <td class="mono amount-green">INR <%= String.format("%.2f", p.getNetSalary() != null ? p.getNetSalary() : java.math.BigDecimal.ZERO) %></td>
                            <td>
                                <span class="badge-processed"><%= p.getStatus() != null ? p.getStatus() : "PROCESSED" %></span>
                            </td>
                            <td style="text-align: center;">
                                <a href="<%= request.getContextPath() %>/salary-slip.jsp?id=<%= p.getId() %>" class="action-link" title="View Payslip">&#128065;</a>
                                <a href="<%= request.getContextPath() %>/salary-slip.jsp?id=<%= p.getId() %>" class="action-link" title="Download Voucher" target="_blank">&#128229;</a>
                            </td>
                        </tr>
                    <%  } 
                       } else { %>
                        <tr>
                            <td colspan="8" style="text-align: center; padding: 40px; color: var(--slate-500);">
                                No payroll records generated yet. Baseline salary structures will auto-generate payslips on the 1st of every month.
                            </td>
                        </tr>
                    <% } %>
                </tbody>
            </table>
        </div>
    </div>
</div>

</body>
</html>