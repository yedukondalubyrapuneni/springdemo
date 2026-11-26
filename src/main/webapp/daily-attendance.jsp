<%@ page contentType="text/html;charset=UTF-8" %>
<%@ page import="com.example.demo.model.Attendance" %>
<%@ page import="com.example.demo.model.Employee" %>
<%@ page import="java.util.List" %>
<%@ page import="java.time.LocalDate" %>
<%@ page import="java.time.format.DateTimeFormatter" %>

<%
    Employee loggedIn = (Employee) session.getAttribute("loggedInEmployee");
    if (loggedIn == null || !loggedIn.isHrDesignation()) {
        response.sendRedirect(request.getContextPath() + "/login");
        return;
    }

    List<Attendance> records = (List<Attendance>) request.getAttribute("records");
    String filterStatus = request.getParameter("status");
    if (filterStatus == null || filterStatus.isBlank()) {
        filterStatus = "ALL";
    }

    String selectedDateStr = (String) request.getAttribute("selectedDate");
    if (selectedDateStr == null) {
        selectedDateStr = LocalDate.now().toString();
    }
%>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Daily Attendance Roster | EMS Enterprise</title>
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
            --emerald-surface: #ecfdf5;
            --amber: #f59e0b;
            --amber-surface: #fffbeb;
            --rose: #f43f5e;
            --rose-surface: #fff1f2;
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
            max-width: 1240px;
            margin: 32px auto;
            padding: 0 24px;
        }

        .header-tray {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 24px;
            flex-wrap: wrap;
            gap: 16px;
        }

        .header-tray h1 {
            font-size: 22px;
            font-weight: 800;
            letter-spacing: -0.02em;
        }

        .date-picker-form {
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .date-picker-input {
            height: 40px;
            border: 1px solid var(--border-subtle);
            border-radius: 8px;
            padding: 0 12px;
            font-family: inherit;
            font-size: 13px;
            color: var(--text-primary);
            outline: none;
        }

        .btn-filter {
            height: 40px;
            padding: 0 16px;
            background: var(--text-primary);
            color: white;
            border: none;
            border-radius: 8px;
            font-size: 13px;
            font-weight: 600;
            cursor: pointer;
        }

        /* Filter Pills */
        .filter-ribbon {
            display: flex;
            gap: 8px;
            margin-bottom: 20px;
            overflow-x: auto;
            padding-bottom: 4px;
        }

        .pill {
            text-decoration: none;
            font-size: 12px;
            font-weight: 700;
            padding: 8px 14px;
            border-radius: 20px;
            border: 1px solid var(--border-subtle);
            color: var(--text-secondary);
            background: var(--surface-card);
            transition: all 0.2s ease;
        }

        .pill:hover { border-color: var(--brand-primary); color: var(--brand-primary); }
        .pill.active {
            background: var(--brand-primary);
            color: white;
            border-color: var(--brand-primary);
        }

        /* Card & Table */
        .card {
            background: var(--surface-card);
            border: 1px solid var(--border-subtle);
            border-radius: 16px;
            box-shadow: var(--shadow-sm);
            overflow: hidden;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            font-size: 13px;
            text-align: left;
        }

        th {
            background: #f8fafc;
            padding: 14px 18px;
            font-size: 11px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: var(--text-secondary);
            border-bottom: 1px solid var(--border-subtle);
        }

        td {
            padding: 16px 18px;
            border-bottom: 1px solid var(--border-subtle);
            color: var(--text-primary);
            vertical-align: middle;
        }

        tr:last-child td { border-bottom: none; }
        tr:hover td { background: #fafbfc; }

        .badge-status {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            font-size: 11px;
            font-weight: 700;
            padding: 4px 10px;
            border-radius: 20px;
        }

        .st-PRESENT  { background: var(--emerald-surface); color: var(--emerald); }
        .st-HALF_DAY { background: #eff6ff; color: var(--brand-primary); }
        .st-PENDING  { background: var(--amber-surface); color: #d97706; }
        .st-LEAVE    { background: #f1f5f9; color: var(--text-secondary); }
        .st-ABSENT   { background: var(--rose-surface); color: var(--rose); }

        .btn-back {
            color: var(--brand-primary);
            text-decoration: none;
            font-size: 13px;
            font-weight: 600;
            display: inline-flex;
            align-items: center;
            gap: 6px;
        }
    </style>
</head>
<body>

<nav class="navbar">
    <div style="display:flex; align-items:center; gap: 12px;">
        <a href="<%= request.getContextPath() %>/attendance/dashboard" class="btn-back">&larr; Back to Dashboard</a>
        <span style="color:var(--border-subtle);">|</span>
        <strong style="font-size: 14px;">Daily Shift Roster</strong>
    </div>
    <div style="display:flex; align-items:center; gap: 14px;">
        <span style="font-size:13px; color:var(--text-secondary);">Logged as: <strong><%= loggedIn.getName() %></strong></span>
        <a href="<%= request.getContextPath() %>/logout" style="color:var(--rose); font-size:13px; text-decoration:none; font-weight:600;">Sign Out</a>
    </div>
</nav>

<main class="viewport">
    <div class="header-tray">
        <div>
            <h1>Daily Attendance Audit</h1>
            <p style="font-size: 13px; color: var(--text-secondary); margin-top: 2px;">
                Inspect daily employee attendance, active break states, and shift conclusions.
            </p>
        </div>

        <form action="<%= request.getContextPath() %>/attendance/daily" method="get" class="date-picker-form">
            <input type="date" name="date" class="date-picker-input" value="<%= selectedDateStr %>">
            <button type="submit" class="btn-filter">Load Roster</button>
        </form>
    </div>

    <!-- Filter Pills -->
    <div class="filter-ribbon">
        <a href="<%= request.getContextPath() %>/attendance/daily?date=<%= selectedDateStr %>&status=ALL" 
           class="pill <%= "ALL".equalsIgnoreCase(filterStatus) ? "active" : "" %>">All Staff</a>
        <a href="<%= request.getContextPath() %>/attendance/daily?date=<%= selectedDateStr %>&status=PRESENT" 
           class="pill <%= "PRESENT".equalsIgnoreCase(filterStatus) ? "active" : "" %>">Present</a>
        <a href="<%= request.getContextPath() %>/attendance/daily?date=<%= selectedDateStr %>&status=PENDING" 
           class="pill <%= "PENDING".equalsIgnoreCase(filterStatus) ? "active" : "" %>">Working (Pending)</a>
        <a href="<%= request.getContextPath() %>/attendance/daily?date=<%= selectedDateStr %>&status=HALF_DAY" 
           class="pill <%= "HALF_DAY".equalsIgnoreCase(filterStatus) ? "active" : "" %>">Half Day</a>
        <a href="<%= request.getContextPath() %>/attendance/daily?date=<%= selectedDateStr %>&status=ABSENT" 
           class="pill <%= "ABSENT".equalsIgnoreCase(filterStatus) ? "active" : "" %>">Absent</a>
        <a href="<%= request.getContextPath() %>/attendance/daily?date=<%= selectedDateStr %>&status=LEAVE" 
           class="pill <%= "LEAVE".equalsIgnoreCase(filterStatus) ? "active" : "" %>">On Leave</a>
    </div>

    <div class="card">
        <table>
            <thead>
                <tr>
                    <th>Emp ID</th>
                    <th>Date</th>
                    <th>Check In</th>
                    <th>Break 1</th>
                    <th>Break 2</th>
                    <th>Check Out</th>
                    <th>Net Working Time</th>
                    <th>Final Status</th>
                </tr>
            </thead>
            <tbody>
                <% 
                    boolean hasRecords = false;
                    if (records != null && !records.isEmpty()) { 
                        for (Attendance att : records) { 
                            if (!"ALL".equalsIgnoreCase(filterStatus) && !filterStatus.equalsIgnoreCase(att.getStatus())) {
                                continue;
                            }
                            hasRecords = true;
                %>
                            <tr>
                                <td><strong><%= att.getEmployeeId() %></strong></td>
                                <td><%= att.getFormattedDate() %></td>
                                <td><%= (att.getFormattedCheckInTime() != null) ? att.getFormattedCheckInTime() : "--" %></td>
                                <td>
                                    <% if (att.getBreak1StartTime() != null) { %>
                                        <%= att.getFormattedBreak1Start() %> - <%= (att.getBreak1EndTime() != null ? att.getFormattedBreak1End() : "In Progress") %>
                                    <% } else { %>
                                        --
                                    <% } %>
                                </td>
                                <td>
                                    <% if (att.getBreak2StartTime() != null) { %>
                                        <%= att.getFormattedBreak2Start() %> - <%= (att.getBreak2EndTime() != null ? att.getFormattedBreak2End() : "In Progress") %>
                                    <% } else { %>
                                        --
                                    <% } %>
                                </td>
                                <td><%= (att.getFormattedCheckOutTime() != null) ? att.getFormattedCheckOutTime() : "--" %></td>
                                <td><strong><%= att.getFormattedNetWorkingHours() %></strong></td>
                                <td>
                                    <span class="badge-status st-<%= att.getStatus() %>">
                                        &#9679; <%= att.getStatus() %>
                                    </span>
                                </td>
                            </tr>
                <%      } 
                    } 
                    if (!hasRecords) { %>
                    <tr>
                        <td colspan="8" style="text-align: center; color: var(--text-muted); padding: 36px;">
                            No records found matching status criteria '<%= filterStatus %>' for date <%= selectedDateStr %>.
                        </td>
                    </tr>
                <% } %>
            </tbody>
        </table>
    </div>
</main>

</body>
</html>