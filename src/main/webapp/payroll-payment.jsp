<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="com.example.demo.model.Employee,com.example.demo.model.Payroll, com.dao.PayrollDAO" %>
<%@ page import="java.time.Month, java.time.format.TextStyle, java.util.Locale" %>
<%
    Employee loggedIn = (Employee) session.getAttribute("loggedInEmployee");
    if (loggedIn == null) {
        response.sendRedirect(request.getContextPath() + "/login.jsp");
        return;
    }

    String role = (loggedIn.getRole() != null) ? loggedIn.getRole().trim().toUpperCase() : "";
    boolean isHr = "HR".equals(role) || loggedIn.isHrDesignation();
    if (!isHr) {
        response.sendRedirect(request.getContextPath() + "/dashboard.jsp?error=Access+Denied:+HR+Only");
        return;
    }

    String idParam = request.getParameter("id");
    PayrollDAO payrollDao = new PayrollDAO();
    Payroll payroll = null;

    if (idParam != null && !idParam.isBlank()) {
        try {
            payroll = payrollDao.getPayrollById(Integer.parseInt(idParam.trim()));
        } catch (Exception ignored) {}
    }

    String msg = request.getParameter("msg");
    String err = request.getParameter("error");
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Disbursement &amp; Payment Confirmation | EMS Enterprise</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com">
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@500;600;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --brand-primary: #2563eb;
            --brand-hover: #1d4ed8;
            --border-subtle: #e2e8f0;
            --text-main: #0f172a;
            --text-muted: #64748b;
            --surface-card: #ffffff;
            --surface-bg: #f8fafc;
        }

        * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Plus Jakarta Sans', sans-serif; }
        body { background: var(--surface-bg); color: var(--text-main); padding: 40px 20px; }
        .container { max-width: 720px; margin: 0 auto; }

        .card {
            background: var(--surface-card);
            border: 1px solid var(--border-subtle);
            border-radius: 16px;
            padding: 32px;
            box-shadow: 0 4px 20px -2px rgba(15, 23, 42, 0.05);
        }

        .header-bar {
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 1px solid var(--border-subtle);
            padding-bottom: 16px;
            margin-bottom: 24px;
        }
        .header-title h2 { font-size: 20px; font-weight: 800; }
        .header-title p { font-size: 13px; color: var(--text-muted); margin-top: 3px; }

        .back-link {
            text-decoration: none;
            color: var(--brand-primary);
            font-weight: 700;
            font-size: 13px;
        }

        .summary-box {
            background: #eff6ff;
            border: 1.5px solid #bfdbfe;
            border-radius: 12px;
            padding: 20px;
            margin-bottom: 24px;
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 14px;
        }
        .summary-item label {
            font-size: 11px;
            font-weight: 700;
            text-transform: uppercase;
            color: #1e40af;
            display: block;
        }
        .summary-item .val {
            font-size: 15px;
            font-weight: 800;
            margin-top: 2px;
        }
        .mono-val { font-family: 'JetBrains Mono', monospace; }

        .field-group {
            display: flex;
            flex-direction: column;
            gap: 6px;
            margin-bottom: 16px;
        }
        .field-label {
            font-size: 11px;
            font-weight: 700;
            color: var(--text-muted);
            text-transform: uppercase;
        }

        .input-base {
            height: 42px;
            border: 1px solid var(--border-subtle);
            border-radius: 8px;
            padding: 0 14px;
            font-size: 13.5px;
            outline: none;
            transition: all 0.15s ease;
        }
        .input-base:focus {
            border-color: var(--brand-primary);
            box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.1);
        }

        .btn-submit {
            width: 100%;
            height: 46px;
            background: var(--brand-primary);
            color: #fff;
            border: none;
            border-radius: 8px;
            font-size: 14px;
            font-weight: 800;
            cursor: pointer;
            transition: all 0.2s ease;
            margin-top: 10px;
        }
        .btn-submit:hover {
            background: var(--brand-hover);
        }

        .alert {
            padding: 12px 16px;
            border-radius: 8px;
            font-size: 13px;
            font-weight: 700;
            margin-bottom: 20px;
        }
        .alert-success { background: #ecfdf5; border: 1px solid #a7f3d0; color: #065f46; }
        .alert-error { background: #fef2f2; border: 1px solid #fecaca; color: #991b1b; }
    </style>
</head>
<body>

<div class="container">
    <div class="card">
        <div class="header-bar">
            <div class="header-title">
                <h2>Disbursement &amp; Payout Confirmation</h2>
                <p>Record transactional reference numbers and finalize disbursement.</p>
            </div>
            <a href="<%= request.getContextPath() %>/dashboard.jsp" class="back-link">&larr; Back to Dashboard</a>
        </div>

        <% if (msg != null) { %><div class="alert alert-success">✔ <%= msg %></div><% } %>
        <% if (err != null) { %><div class="alert alert-error">⚠ <%= err %></div><% } %>

        <% if (payroll != null) { 
            String pMonth = Month.of(payroll.getPayrollMonth()).getDisplayName(TextStyle.FULL, Locale.ENGLISH);
        %>
            <div class="summary-box">
                <div class="summary-item">
                    <label>Employee</label>
                    <div class="val"><%= payroll.getEmployeeName() %> (<span class="mono-val"><%= payroll.getEmployeeId() %></span>)</div>
                </div>
                <div class="summary-item">
                    <label>Payroll Period</label>
                    <div class="val"><%= pMonth %> <%= payroll.getPayrollYear() %></div>
                </div>
                <div class="summary-item">
                    <label>Gross Earnings</label>
                    <div class="val mono-val">₹ <%= String.format("%.2f", payroll.getGrossSalary()) %></div>
                </div>
                <div class="summary-item">
                    <label>Net Payable Amount</label>
                    <div class="val mono-val" style="color: #059669; font-size: 18px;">
                        ₹ <%= String.format("%.2f", payroll.getNetSalary()) %>
                    </div>
                </div>
            </div>

            <form method="post" action="<%= request.getContextPath() %>/payroll/disburse">
                <input type="hidden" name="payrollId" value="<%= payroll.getId() %>">
                <input type="hidden" name="employeeId" value="<%= payroll.getEmployeeId() %>">

                <div class="field-group">
                    <label class="field-label">Disbursement Method</label>
                    <select name="paymentMode" class="input-base" required>
                        <option value="BANK_TRANSFER">Direct Bank Transfer (NEFT / RTGS / IMPS)</option>
                        <option value="UPI">Corporate UPI</option>
                        <option value="CHEQUE">Company Cheque</option>
                    </select>
                </div>

                <div class="field-group">
                    <label class="field-label">Transaction / UTR Reference ID</label>
                    <input type="text" name="transactionRef" class="input-base mono-val" 
                           placeholder="e.g. UTR20261102984128" required>
                </div>

                <div class="field-group">
                    <label class="field-label">Disbursement Date</label>
                    <input type="date" name="paymentDate" class="input-base" 
                           value="<%= java.time.LocalDate.now() %>" required>
                </div>

                <button type="submit" class="btn-submit">
                    Record Payment &amp; Mark as Disbursed &rarr;
                </button>
            </form>
        <% } else { %>
            <div style="text-align: center; padding: 40px 20px; color: var(--text-muted);">
                <p style="font-weight: 700;">No payroll record specified.</p>
                <p style="font-size: 13px; margin-top: 6px;">Select an employee payslip record from the dashboard to process payment.</p>
                <a href="<%= request.getContextPath() %>/dashboard.jsp" class="btn-submit" style="display: inline-block; width: auto; padding: 10px 24px; text-decoration: none; margin-top: 16px;">
                    Return to Dashboard
                </a>
            </div>
        <% } %>
    </div>
</div>

</body>
</html>