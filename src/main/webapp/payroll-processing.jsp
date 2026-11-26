<%@ page contentType="text/html;charset=UTF-8" %>
<%@ page import="com.example.demo.model.Payroll, java.util.List, java.time.Month, java.time.format.TextStyle, java.util.Locale" %>
<%
    List<Payroll> payrollList = (List<Payroll>) request.getAttribute("payrollList");
    int selectedMonth = (request.getAttribute("selectedMonth") != null) ? (Integer) request.getAttribute("selectedMonth") : java.time.LocalDate.now().getMonthValue();
    int selectedYear = (request.getAttribute("selectedYear") != null) ? (Integer) request.getAttribute("selectedYear") : java.time.LocalDate.now().getYear();
    String msg = request.getParameter("msg");
    String err = request.getParameter("error");
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Run Monthly Payroll Cycle | SmartOffice EMS</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@500;600&display=swap" rel="stylesheet">
    <style>
        :root {
            --brand-primary: #1e40af;
            --brand-accent: #2563eb;
            --slate-50: #f8fafc;
            --slate-100: #f1f5f9;
            --slate-200: #e2e8f0;
            --slate-300: #cbd5e1;
            --slate-500: #64748b;
            --slate-700: #334155;
            --slate-900: #0f172a;
            --emerald-bg: #ecfdf5;
            --emerald-text: #065f46;
            --emerald-border: #a7f3d0;
            --rose-bg: #fef2f2;
            --rose-text: #991b1b;
            --rose-border: #fecaca;
            --amber-bg: #fffbeb;
            --amber-text: #92400e;
            --amber-border: #fde68a;
            --shadow-card: 0 4px 6px -1px rgba(15, 23, 42, 0.04), 0 2px 4px -2px rgba(15, 23, 42, 0.03);
            --radius-md: 10px;
            --radius-lg: 14px;
        }

        * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Plus Jakarta Sans', sans-serif; }
        body { background-color: var(--slate-50); color: var(--slate-900); padding: 32px 28px; -webkit-font-smoothing: antialiased; }
        .container { max-width: 1200px; margin: 0 auto; display: flex; flex-direction: column; gap: 20px; }
        .card { background: #ffffff; border: 1px solid var(--slate-200); border-radius: var(--radius-lg); padding: 28px 32px; box-shadow: var(--shadow-card); }

        .header-strip { display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 16px; border-bottom: 1px solid var(--slate-200); padding-bottom: 20px; }
        .title-block h1 { font-size: 22px; font-weight: 800; letter-spacing: -0.02em; }
        .title-block p { font-size: 13px; color: var(--slate-500); margin-top: 2px; }

        .btn { font-family: inherit; font-size: 12.5px; font-weight: 700; padding: 8px 16px; border-radius: 8px; border: 1px solid transparent; cursor: pointer; text-decoration: none; display: inline-flex; align-items: center; gap: 6px; }
        .btn-primary { background: var(--brand-accent); color: #fff; }
        .btn-primary:hover { background: #1d4ed8; }
        .btn-outline { background: #fff; border-color: var(--slate-300); color: var(--slate-700); }
        .btn-outline:hover { background: var(--slate-50); }

        .grid-terminal { display: grid; grid-template-columns: 360px 1fr; gap: 24px; margin-top: 20px; }
        @media (max-width: 900px) { .grid-terminal { grid-template-columns: 1fr; } }

        .form-box { background: #f8fafc; border: 1px solid var(--slate-200); border-radius: var(--radius-md); padding: 20px; }
        .input-group { display: flex; flex-direction: column; gap: 5px; margin-bottom: 14px; }
        .input-label { font-size: 11px; font-weight: 700; text-transform: uppercase; color: var(--slate-500); letter-spacing: 0.04em; }
        .form-input, .form-select { height: 38px; border: 1px solid var(--slate-300); border-radius: 8px; padding: 0 12px; font-size: 13px; outline: none; background: #fff; font-family: inherit; }
        .form-input:focus, .form-select:focus { border-color: var(--brand-accent); box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.1); }

        .alert-success { background: var(--emerald-bg); border: 1px solid var(--emerald-border); color: var(--emerald-text); padding: 12px 18px; border-radius: 8px; font-size: 13px; font-weight: 700; margin-bottom: 16px; }
        .alert-error { background: var(--rose-bg); border: 1px solid var(--rose-border); color: var(--rose-text); padding: 12px 18px; border-radius: 8px; font-size: 13px; font-weight: 700; margin-bottom: 16px; }

        .table-wrap { border: 1px solid var(--slate-200); border-radius: var(--radius-md); overflow: hidden; background: #fff; }
        table { width: 100%; border-collapse: collapse; font-size: 13px; text-align: left; }
        th { background: #f8fafc; color: var(--slate-500); font-size: 11px; text-transform: uppercase; font-weight: 700; padding: 12px 16px; border-bottom: 1px solid var(--slate-200); letter-spacing: 0.04em; }
        td { padding: 12px 16px; border-bottom: 1px solid var(--slate-200); vertical-align: middle; color: var(--slate-700); }
        tr:last-child td { border-bottom: none; }
        
        .badge-pill { padding: 3px 8px; border-radius: 6px; font-size: 11px; font-weight: 700; }
        .badge-green { background: var(--emerald-bg); color: var(--emerald-text); }
        .badge-amber { background: var(--amber-bg); color: var(--amber-text); }
    </style>
</head>
<body>

<div class="container">
    <div class="card">
        <div class="header-strip">
            <div class="title-block">
                <h1>Payroll Calculation Terminal</h1>
                <p>Run automated attendance-linked cycles with 1 Sick + 1 Casual paid leave allowance logic.</p>
            </div>
            <div style="display: flex; gap: 8px;">
                <a href="<%= request.getContextPath() %>/payroll/history" class="btn btn-outline">&#128203; View History</a>
                <a href="<%= request.getContextPath() %>/salary-structure.jsp" class="btn btn-outline">&#9881; Setup Structure</a>
            </div>
        </div>

        <% if (msg != null && !msg.isBlank()) { %><div class="alert-success" style="margin-top: 16px;">&#10003; <%= msg %></div><% } %>
        <% if (err != null && !err.isBlank()) { %><div class="alert-error" style="margin-top: 16px;">&#9888; <%= err %></div><% } %>

        <div class="grid-terminal">
            <!-- Left Execution Form -->
            <div class="form-box">
                <h3 style="font-size: 15px; font-weight: 800; margin-bottom: 12px;">Execute Calculation</h3>
                
                <form method="post" action="<%= request.getContextPath() %>/payroll/process">
                    <div class="input-group">
                        <label class="input-label">Target Employee ID</label>
                        <input type="text" name="employeeId" class="form-input" placeholder="e.g. 9147" required>
                    </div>

                    <div class="input-group">
                        <label class="input-label">Payroll Month</label>
                        <select name="month" class="form-select" required>
                            <% for (int m = 1; m <= 12; m++) { 
                                String mName = Month.of(m).getDisplayName(TextStyle.FULL, Locale.ENGLISH);
                            %>
                                <option value="<%= m %>" <%= (m == selectedMonth) ? "selected" : "" %>><%= mName %></option>
                            <% } %>
                        </select>
                    </div>

                    <div class="input-group">
                        <label class="input-label">Payroll Year</label>
                        <input type="number" name="year" class="form-input" value="<%= selectedYear %>" required>
                    </div>

                    <button type="submit" class="btn btn-primary" style="width: 100%; justify-content: center; margin-top: 8px;">
                        Compute &amp; Commit Record
                    </button>
                </form>
            </div>

            <!-- Right Processed List for Cycle -->
            <div>
                <h3 style="font-size: 15px; font-weight: 800; margin-bottom: 12px;">Processed Records for Cycle</h3>
                <div class="table-wrap">
                    <table>
                        <thead>
                            <tr>
                                <th>Emp ID</th>
                                <th>Present / Total</th>
                                <th>LOP</th>
                                <th style="text-align: right;">Net Pay</th>
                                <th style="text-align: center;">Status</th>
                                <th style="text-align: center;">Payment</th>
                            </tr>
                        </thead>
                        <tbody>
                            <% if (payrollList != null && !payrollList.isEmpty()) { 
                                for (Payroll p : payrollList) { 
                                    boolean isPaid = "PAID".equalsIgnoreCase(p.getStatus());
                            %>
                                <tr>
                                    <td><strong style="font-family: 'JetBrains Mono', monospace;"><%= p.getEmployeeId() %></strong></td>
                                    <td><%= p.getPresentDays() %> / <%= p.getWorkingDays() %></td>
                                    <td style="color: <%= p.getUnpaidLeaveDays() > 0 ? "#dc2626" : "#64748b" %>; font-weight: 700;">
                                        <%= p.getUnpaidLeaveDays() %>
                                    </td>
                                    <td style="text-align: right; font-family: 'JetBrains Mono', monospace; font-weight: 700;">
                                        ₹ <%= p.getNetSalary() %>
                                    </td>
                                    <td style="text-align: center;">
                                        <span class="badge-pill <%= isPaid ? "badge-green" : "badge-amber" %>">
                                            <%= p.getStatus() %>
                                        </span>
                                    </td>
                                    <td style="text-align: center;">
                                        <% if (!isPaid) { %>
                                            <a href="<%= request.getContextPath() %>/payroll/payment?payrollId=<%= p.getId() %>" class="btn btn-primary" style="padding: 4px 10px; font-size: 11px;">
                                                Disburse
                                            </a>
                                        <% } else { %>
                                            <span style="font-size: 11.5px; color: #16a34a; font-weight: 700;">&#10003; Disbursed</span>
                                        <% } %>
                                    </td>
                                </tr>
                            <%  } 
                               } else { %>
                                <tr>
                                    <td colspan="6" style="text-align: center; color: var(--slate-500); padding: 32px;">
                                        No records processed for this monthly cycle yet.
                                    </td>
                                </tr>
                            <% } %>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>

</body>
</html>