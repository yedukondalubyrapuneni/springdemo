<%@ page contentType="text/html;charset=UTF-8" %>
<%@ page import="com.example.demo.model.Employee" %>
<%@ page import="com.example.demo.service.AttendanceService.MonthlySummary" %>
<%@ page import="java.time.YearMonth" %>
<%@ page import="java.time.format.DateTimeFormatter" %>

<%
    Employee loggedInUser = (Employee) session.getAttribute("loggedInEmployee");
    String role = (loggedInUser != null && loggedInUser.getRole() != null) ? loggedInUser.getRole().trim().toUpperCase() : "";

    // Allow both ADMIN and HR to access
    if (loggedInUser == null || (!role.contains("ADMIN") && !role.contains("HR") && !loggedInUser.isHrDesignation())) {
        response.sendError(HttpServletResponse.SC_FORBIDDEN, "Access Denied: Only Admins and HR can view monthly attendance.");
        return;
    }

    MonthlySummary summary = (MonthlySummary) request.getAttribute("monthlySummary");
    String queriedEmpId = (String) request.getAttribute("queriedEmpId");
    String queriedMonth = (String) request.getAttribute("queriedMonth");
    if (queriedMonth == null) {
        queriedMonth = YearMonth.now().toString();
    }
%>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Monthly Attendance Report | EMS Enterprise</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        :root {
            --brand-primary: #2563eb;
            --surface-bg: #f8fafc;
            --surface-card: #ffffff;
            --border-subtle: #e2e8f0;
            --text-primary: #0f172a;
            --text-secondary: #475569;
            --text-muted: #94a3b8;
            --emerald: #10b981;
            --amber: #f59e0b;
            --rose: #ef4444;
            --shadow-sm: 0 1px 2px 0 rgb(0 0 0 / 0.05);
            --shadow-md: 0 4px 6px -1px rgb(0 0 0 / 0.07);
        }

        * { box-sizing: border-box; margin: 0; padding: 0; }

        body {
            font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, sans-serif;
            background: var(--surface-bg);
            color: var(--text-primary);
            line-height: 1.5;
        }

        .navbar {
            background: rgba(255, 255, 255, 0.9);
            backdrop-filter: blur(10px);
            border-bottom: 1px solid var(--border-subtle);
            padding: 14px 28px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            position: sticky;
            top: 0;
            z-index: 50;
        }

        .viewport {
            max-width: 1040px;
            margin: 32px auto;
            padding: 0 24px;
        }

        .header-title h1 {
            font-size: 22px;
            font-weight: 800;
            letter-spacing: -0.02em;
        }

        .card {
            background: var(--surface-card);
            border: 1px solid var(--border-subtle);
            border-radius: 16px;
            padding: 24px;
            box-shadow: var(--shadow-sm);
            margin-top: 24px;
        }

        .query-form {
            display: grid;
            grid-template-columns: 1.5fr 1fr auto;
            gap: 14px;
            align-items: flex-end;
        }

        .form-group label {
            display: block;
            font-size: 11px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: var(--text-secondary);
            margin-bottom: 6px;
        }

        .form-control {
            width: 100%;
            height: 42px;
            border: 1px solid var(--border-subtle);
            border-radius: 8px;
            padding: 0 12px;
            font-family: inherit;
            font-size: 13px;
            color: var(--text-primary);
            outline: none;
        }

        .btn-query {
            height: 42px;
            padding: 0 20px;
            background: var(--brand-primary);
            color: white;
            border: none;
            border-radius: 8px;
            font-size: 13px;
            font-weight: 700;
            cursor: pointer;
        }

        /* Metric Grid */
        .summary-grid {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 16px;
            margin-top: 24px;
        }

        .metric-box {
            background: #f8fafc;
            border: 1px solid var(--border-subtle);
            border-radius: 12px;
            padding: 20px;
            text-align: center;
        }

        .metric-lbl {
            font-size: 11px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: var(--text-secondary);
            margin-bottom: 6px;
        }

        .metric-digit {
            font-size: 30px;
            font-weight: 800;
        }

        .rate-card {
            grid-column: span 3;
            background: linear-gradient(135deg, #1e293b 0%, #0f172a 100%);
            color: white;
            padding: 24px;
            border-radius: 14px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-top: 8px;
        }
    </style>
</head>
<body>

<nav class="navbar">
    <div style="display:flex; align-items:center; gap: 12px;">
        <a href="<%= request.getContextPath() %>/attendance/dashboard" style="color:var(--brand-primary); text-decoration:none; font-size:13px; font-weight:600;">&larr; Back to Dashboard</a>
        <span style="color:var(--border-subtle);">|</span>
        <strong style="font-size: 14px;">Monthly Attendance Report</strong>
    </div>
    <div style="display:flex; align-items:center; gap: 14px;">
        <a href="<%= request.getContextPath() %>/logout" style="color:var(--rose); font-size:13px; text-decoration:none; font-weight:600;">Sign Out</a>
    </div>
</nav>

<main class="viewport">
    <div class="header-title">
        <h1>Monthly Attendance Report</h1>
        <p style="font-size: 13px; color: var(--text-secondary); margin-top: 2px;">
            Calculate monthly attendance rates, approved leaves, and net compliance percentages per staff member.
        </p>
    </div>

    <div class="card">
        <form action="<%= request.getContextPath() %>/attendance/monthly" method="get" class="query-form">
            <div class="form-group">
                <label>Employee ID</label>
                <input type="text" name="employeeId" class="form-control" placeholder="e.g. EMP101" 
                       value="<%= (queriedEmpId != null) ? queriedEmpId : "" %>" required>
            </div>

            <div class="form-group">
                <label>Month & Year</label>
                <input type="month" name="month" class="form-control" value="<%= queriedMonth %>" required>
            </div>

            <button type="submit" class="btn-query">Generate Report</button>
        </form>

        <% if (summary != null) { %>
            <div class="summary-grid">
                <div class="metric-box">
                    <div class="metric-lbl">Total Working Days</div>
                    <div class="metric-digit" style="color: var(--brand-primary);"><%= summary.getWorkingDays() %></div>
                </div>

                <div class="metric-box">
                    <div class="metric-lbl">Full Days Present</div>
                    <div class="metric-digit" style="color: var(--emerald);"><%= summary.getPresentDays() %></div>
                </div>

                <div class="metric-box">
                    <div class="metric-lbl">Half Days Logged</div>
                    <div class="metric-digit" style="color: #0284c7;"><%= summary.getHalfDays() %></div>
                </div>

                <div class="metric-box">
                    <div class="metric-lbl">Approved Leaves</div>
                    <div class="metric-digit" style="color: var(--amber);"><%= summary.getLeaveDays() %></div>
                </div>

                <div class="metric-box">
                    <div class="metric-lbl">Unexcused Absences</div>
                    <div class="metric-digit" style="color: var(--rose);"><%= summary.getAbsentDays() %></div>
                </div>

                <div class="metric-box">
                    <div class="metric-lbl">Effective Days Present</div>
                    <div class="metric-digit"><%= summary.getPresentDays() + (summary.getHalfDays() * 0.5) %></div>
                </div>

                <div class="rate-card">
                    <div>
                        <div style="font-size: 11px; font-weight: 700; text-transform: uppercase; color: #94a3b8; letter-spacing: 0.05em;">Compliance Rating</div>
                        <div style="font-size: 13px; color: #cbd5e1; margin-top: 2px;">Monthly Net Performance Ratio</div>
                    </div>
                    <div style="font-size: 38px; font-weight: 800; color: #38bdf8;">
                        <%= String.format("%.1f", summary.getPercentage()) %>%
                    </div>
                </div>
            </div>
        <% } %>
    </div>
</main>

</body>
</html>