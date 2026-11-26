<%@ page contentType="text/html;charset=UTF-8" %>
<%@ page import="com.example.demo.model.Attendance" %>
<%@ page import="com.example.demo.model.Employee" %>
<%@ page import="java.util.List" %>
<%@ page import="java.time.LocalDate" %>
<%@ page import="java.time.format.DateTimeFormatter" %>

<%
    Employee loggedIn = (Employee) session.getAttribute("loggedInEmployee");
    if (loggedIn == null) {
        response.sendRedirect(request.getContextPath() + "/login");
        return;
    }

    List<Attendance> myHistory = (List<Attendance>) request.getAttribute("myHistory");

    int totalPresent = 0;
    int totalLeaves = 0;
    int totalHalfDays = 0;
    
    LocalDate today = LocalDate.now();
    Attendance todayRecord = null;

    if (myHistory != null) {
        for (Attendance a : myHistory) {
            if ("PRESENT".equalsIgnoreCase(a.getStatus())) totalPresent++;
            else if ("HALF_DAY".equalsIgnoreCase(a.getStatus())) totalHalfDays++;
            else if ("LEAVE".equalsIgnoreCase(a.getStatus()) && "APPROVED".equalsIgnoreCase(a.getLeaveStatus())) totalLeaves++;

            if (today.equals(a.getAttendanceDate())) {
                todayRecord = a;
            }
        }
    }

    boolean isCheckedIn = (todayRecord != null && todayRecord.getCheckInTime() != null);
    boolean isCheckedOut = (todayRecord != null && todayRecord.getCheckOutTime() != null);

    boolean b1Running = (todayRecord != null && todayRecord.getBreak1StartTime() != null && todayRecord.getBreak1EndTime() == null);
    boolean b2Running = (todayRecord != null && todayRecord.getBreak2StartTime() != null && todayRecord.getBreak2EndTime() == null);
    boolean isAnyBreakActive = b1Running || b2Running;

    boolean allBreaksUsed = (todayRecord != null && todayRecord.getBreak2EndTime() != null);
    boolean isOnApprovedLeave = (todayRecord != null && "LEAVE".equalsIgnoreCase(todayRecord.getStatus()) 
                                 && "APPROVED".equalsIgnoreCase(todayRecord.getLeaveStatus()));
%>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Employee Workspace | EMS Enterprise Suite</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        :root {
            --brand-primary: #3b82f6;
            --brand-gradient: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
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
            --shadow-md: 0 4px 6px -1px rgb(0 0 0 / 0.07), 0 2px 4px -2px rgb(0 0 0 / 0.05);
            --shadow-lg: 0 10px 15px -3px rgb(0 0 0 / 0.08), 0 4px 6px -4px rgb(0 0 0 / 0.04);
        }

        * { box-sizing: border-box; margin: 0; padding: 0; }

        body {
            font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, sans-serif;
            background-color: var(--surface-bg);
            color: var(--text-primary);
            line-height: 1.5;
            -webkit-font-smoothing: antialiased;
        }

        /* Top Enterprise Navigation Header */
        .navbar {
            background: rgba(255, 255, 255, 0.85);
            backdrop-filter: blur(12px);
            border-bottom: 1px solid var(--border-subtle);
            position: sticky;
            top: 0;
            z-index: 50;
            padding: 14px 28px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .brand-cluster {
            display: flex;
            align-items: center;
            gap: 12px;
        }

        .brand-symbol {
            width: 38px;
            height: 38px;
            background: var(--brand-gradient);
            border-radius: 10px;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-weight: 800;
            box-shadow: 0 4px 10px rgba(37, 99, 235, 0.25);
        }

        .brand-meta h1 {
            font-size: 16px;
            font-weight: 700;
            letter-spacing: -0.02em;
            color: var(--text-primary);
        }

        .brand-meta span {
            font-size: 11px;
            font-weight: 600;
            color: var(--text-muted);
            letter-spacing: 0.04em;
            text-transform: uppercase;
        }

        .nav-actions {
            display: flex;
            align-items: center;
            gap: 16px;
        }

        .live-clock-pill {
            background: var(--surface-bg);
            border: 1px solid var(--border-subtle);
            border-radius: 20px;
            padding: 6px 14px;
            font-size: 12px;
            font-weight: 600;
            color: var(--text-secondary);
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .live-dot {
            width: 7px;
            height: 7px;
            background: var(--emerald);
            border-radius: 50%;
            box-shadow: 0 0 0 3px rgba(16, 185, 129, 0.2);
            animation: pulse-dot 2s infinite;
        }

        @keyframes pulse-dot {
            0%, 100% { opacity: 1; transform: scale(1); }
            50% { opacity: 0.6; transform: scale(0.9); }
        }

        .btn-ghost {
            font-size: 13px;
            font-weight: 600;
            color: var(--text-secondary);
            text-decoration: none;
            padding: 8px 14px;
            border-radius: 8px;
            transition: all 0.2s ease;
        }
        .btn-ghost:hover { background: var(--surface-bg); color: var(--text-primary); }

        .btn-signout {
            font-size: 13px;
            font-weight: 600;
            color: var(--rose);
            background: var(--rose-surface);
            border: 1px solid #fecdd3;
            text-decoration: none;
            padding: 8px 16px;
            border-radius: 8px;
            transition: all 0.2s ease;
        }
        .btn-signout:hover { background: #ffe4e6; }

        /* Workspace Viewport */
        .workspace {
            max-width: 1240px;
            margin: 32px auto;
            padding: 0 24px;
        }

        /* Profile & Live Status Banner */
        .identity-banner {
            background: var(--surface-card);
            border: 1px solid var(--border-subtle);
            border-radius: 16px;
            padding: 24px 28px;
            box-shadow: var(--shadow-sm);
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 28px;
            flex-wrap: wrap;
            gap: 20px;
        }

        .user-profile {
            display: flex;
            align-items: center;
            gap: 18px;
        }

        .avatar-box {
            width: 60px;
            height: 60px;
            border-radius: 14px;
            background: linear-gradient(135deg, #1e293b 0%, #0f172a 100%);
            color: #ffffff;
            font-size: 22px;
            font-weight: 700;
            display: flex;
            align-items: center;
            justify-content: center;
            box-shadow: var(--shadow-md);
        }

        .profile-specs h2 {
            font-size: 20px;
            font-weight: 700;
            letter-spacing: -0.02em;
            color: var(--text-primary);
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .status-chip {
            font-size: 11px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            padding: 2px 10px;
            border-radius: 20px;
            background: var(--emerald-surface);
            color: var(--emerald);
            border: 1px solid #a7f3d0;
        }

        .specs-grid {
            display: flex;
            flex-wrap: wrap;
            gap: 18px;
            margin-top: 6px;
            font-size: 13px;
            color: var(--text-secondary);
        }

        .specs-grid strong {
            color: var(--text-primary);
        }

        .shift-badge-container {
            display: flex;
            flex-direction: column;
            align-items: flex-end;
            gap: 4px;
        }

        .shift-label {
            font-size: 11px;
            font-weight: 700;
            text-transform: uppercase;
            color: var(--text-muted);
            letter-spacing: 0.05em;
        }

        .shift-state-pill {
            padding: 6px 14px;
            border-radius: 10px;
            font-size: 13px;
            font-weight: 700;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        .state-inactive { background: #f1f5f9; color: var(--text-secondary); }
        .state-active   { background: var(--emerald-surface); color: var(--emerald); border: 1px solid #6ee7b7; }
        .state-break    { background: var(--amber-surface); color: #d97706; border: 1px solid #fcd34d; }
        .state-closed   { background: #f8fafc; color: var(--text-muted); border: 1px solid var(--border-subtle); }

        /* Notification Banners */
        .toast {
            border-radius: 12px;
            padding: 14px 20px;
            font-size: 13px;
            font-weight: 600;
            display: flex;
            align-items: center;
            gap: 12px;
            margin-bottom: 24px;
        }
        .toast-success { background: var(--emerald-surface); border: 1px solid #a7f3d0; color: #065f46; }
        .toast-warning { background: var(--amber-surface); border: 1px solid #fde68a; color: #92400e; }
        .toast-error   { background: var(--rose-surface); border: 1px solid #fecdd3; color: #9f1239; }

        /* Workspace Grid (Shift Punch + Leave Desk) */
        .grid-layout {
            display: grid;
            grid-template-columns: 1.45fr 1fr;
            gap: 24px;
            margin-bottom: 32px;
        }

        .card {
            background: var(--surface-card);
            border: 1px solid var(--border-subtle);
            border-radius: 16px;
            padding: 26px;
            box-shadow: var(--shadow-sm);
        }

        .card-header {
            margin-bottom: 18px;
        }

        .card-header h3 {
            font-size: 16px;
            font-weight: 700;
            letter-spacing: -0.01em;
            color: var(--text-primary);
        }

        .card-header p {
            font-size: 13px;
            color: var(--text-secondary);
            margin-top: 3px;
        }

        /* Action Buttons */
        .button-matrix {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 14px;
            margin-bottom: 14px;
        }

        .btn-action {
            height: 48px;
            border-radius: 10px;
            font-size: 13px;
            font-weight: 700;
            letter-spacing: -0.01em;
            border: none;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
            transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
        }

        .btn-action:hover:not(:disabled) {
            transform: translateY(-1.5px);
            box-shadow: var(--shadow-md);
        }

        .btn-action:active:not(:disabled) {
            transform: translateY(0);
        }

        .btn-action:disabled {
            background: #f1f5f9 !important;
            color: #cbd5e1 !important;
            border: 1px solid var(--border-subtle) !important;
            cursor: not-allowed;
            box-shadow: none !important;
        }

        .btn-punch-in  { background: var(--emerald); color: white; }
        .btn-punch-out { background: var(--brand-primary); color: white; }
        .btn-break-on  { background: var(--amber); color: #451a03; }
        .btn-break-off { background: #ea580c; color: white; }

        /* Leave Form Controls */
        .form-label {
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
            height: 44px;
            border: 1px solid var(--border-subtle);
            border-radius: 10px;
            padding: 0 14px;
            font-size: 13px;
            font-family: inherit;
            color: var(--text-primary);
            background: var(--surface-bg);
            margin-bottom: 16px;
            outline: none;
            transition: all 0.2s ease;
        }

        .form-control:focus {
            background: white;
            border-color: var(--brand-primary);
            box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.15);
        }

        .btn-submit-leave {
            width: 100%;
            height: 46px;
            background: var(--text-primary);
            color: white;
            border-radius: 10px;
            border: none;
            font-size: 13px;
            font-weight: 700;
            cursor: pointer;
            transition: all 0.2s ease;
        }
        .btn-submit-leave:hover { background: #000; }

        /* Data Roster Table */
        .table-responsive {
            overflow-x: auto;
            border: 1px solid var(--border-subtle);
            border-radius: 12px;
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
            letter-spacing: 0.03em;
        }

        .st-PRESENT  { background: var(--emerald-surface); color: var(--emerald); }
        .st-HALF_DAY { background: #eff6ff; color: var(--brand-primary); }
        .st-PENDING  { background: var(--amber-surface); color: #d97706; }
        .st-LEAVE    { background: #f1f5f9; color: var(--text-secondary); }
        .st-ABSENT   { background: var(--rose-surface); color: var(--rose); }

        .lv-APPROVED         { background: var(--emerald-surface); color: var(--emerald); border: 1px solid #a7f3d0; }
        .lv-PENDING_APPROVAL { background: var(--amber-surface); color: #d97706; border: 1px solid #fde68a; }
        .lv-REJECTED         { background: var(--rose-surface); color: var(--rose); border: 1px solid #fecdd3; }

        .remark-card {
            margin-top: 8px;
            background: #fff5f5;
            border-left: 3px solid var(--rose);
            padding: 8px 12px;
            border-radius: 6px;
        }

        .remark-header {
            font-size: 10px;
            font-weight: 800;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: #be123c;
            display: flex;
            align-items: center;
            gap: 4px;
        }

        .remark-text {
            font-size: 12px;
            font-weight: 500;
            color: #881337;
            margin-top: 2px;
        }
    </style>
</head>
<body>

<!-- Enterprise Navbar -->
<nav class="navbar">
    <div class="brand-cluster">
        <div class="brand-symbol">E</div>
        <div class="brand-meta">
            <h1>EMS Enterprise</h1>
            <span>Workforce Management Suite</span>
        </div>
    </div>

    <div class="nav-actions">
        <div class="live-clock-pill">
            <span class="live-dot"></span>
            <span id="liveClock">--:--:--</span>
        </div>
        <% if (loggedIn.isHrDesignation()) { %>
            <a href="<%= request.getContextPath() %>/attendance/dashboard" class="btn-ghost">
                &larr; HR Executive Console
            </a>
        <% } %>
        <a href="<%= request.getContextPath() %>/logout" class="btn-signout">Sign Out</a>
    </div>
</nav>

<main class="workspace">

    <!-- Employee Profile Banner -->
    <section class="identity-banner">
        <div class="user-profile">
            <div class="avatar-box">
                <%= (loggedIn.getName() != null && !loggedIn.getName().isBlank()) ? loggedIn.getName().substring(0, 1).toUpperCase() : "U" %>
            </div>
            <div class="profile-specs">
                <h2>
                    <%= loggedIn.getName() %>
                    <span class="status-chip">&#9679; <%= loggedIn.getStatus() %></span>
                </h2>
                <div class="specs-grid">
                    <span>ID: <strong><%= loggedIn.getEmployeeId() %></strong></span>
                    <span>Role: <strong><%= loggedIn.getRole() %></strong></span>
                    <span>Dept: <strong><%= loggedIn.getDepartment() %></strong></span>
                    <span>Email: <strong><%= (loggedIn.getEmail() != null) ? loggedIn.getEmail() : "--" %></strong></span>
                    <span>Mobile: <strong><%= (loggedIn.getMobile() != null) ? loggedIn.getMobile() : "--" %></strong></span>
                </div>
            </div>
        </div>

        <div class="shift-badge-container">
            <span class="shift-label">Live Shift State</span>
            <% if (isOnApprovedLeave) { %>
                <div class="shift-state-pill st-LEAVE">&#9679; Approved Leave Today</div>
            <% } else if (isCheckedOut) { %>
                <div class="shift-state-pill state-closed">&#9679; Shift Concluded</div>
            <% } else if (isAnyBreakActive) { %>
                <div class="shift-state-pill state-break">&#9679; Active On Break</div>
            <% } else if (isCheckedIn) { %>
                <div class="shift-state-pill state-active">&#9679; Working In-Shift</div>
            <% } else { %>
                <div class="shift-state-pill state-inactive">&#9679; Not Checked In</div>
            <% } %>
        </div>
    </section>

    <!-- Feedback Toasts -->
    <% if (request.getAttribute("message") != null) { %>
        <div class="toast toast-success">&#10004; <%= request.getAttribute("message") %></div>
    <% } %>
    <% if (request.getAttribute("warning") != null) { %>
        <div class="toast toast-warning">&#9888; <%= request.getAttribute("warning") %></div>
    <% } %>
    <% if (request.getAttribute("error") != null) { %>
        <div class="toast toast-error">&#9888; <%= request.getAttribute("error") %></div>
    <% } %>

    <!-- Workspace Controls -->
    <div class="grid-layout">
        
        <!-- Attendance & Break Card -->
        <div class="card">
            <div class="card-header">
                <h3>Attendance & Break Controller</h3>
                <p>Standard policy: Check-in opens at <strong>09:45 AM</strong>. 2 breaks permitted (15m max). Auto check-out triggers at <strong>06:15 PM</strong>.</p>
            </div>

            <form action="<%= request.getContextPath() %>/attendance/action" method="post">
                <div class="button-matrix">
                    <button type="submit" name="action" value="CHECK_IN" class="btn-action btn-punch-in"
                        <%= (isCheckedIn || isCheckedOut || isOnApprovedLeave) ? "disabled" : "" %>>
                        Check In
                    </button>

                    <button type="submit" name="action" value="CHECK_OUT" class="btn-action btn-punch-out"
                        <%= (!isCheckedIn || isCheckedOut || isAnyBreakActive) ? "disabled" : "" %>>
                        Check Out
                    </button>
                </div>

                <div class="button-matrix">
                    <button type="submit" name="action" value="START_BREAK" class="btn-action btn-break-on"
                        <%= (!isCheckedIn || isCheckedOut || isAnyBreakActive || allBreaksUsed) ? "disabled" : "" %>>
                        Start Break
                    </button>

                    <button type="submit" name="action" value="END_BREAK" class="btn-action btn-break-off"
                        <%= (!isAnyBreakActive || isCheckedOut) ? "disabled" : "" %>>
                        End Break
                    </button>
                </div>
            </form>
        </div>

        <!-- Leave Application Desk -->
        <div class="card">
            <div class="card-header">
                <h3>Request Absence / Leave</h3>
                <p>Leave tickets are processed by HR. Shifts on approved leave dates are blocked automatically.</p>
            </div>

            <form action="<%= request.getContextPath() %>/attendance/action" method="post">
                <input type="hidden" name="action" value="APPLY_LEAVE">
                
                <label class="form-label">Effective Date</label>
                <input type="date" name="leaveDate" class="form-control" required>

                <label class="form-label">Reason / Justification</label>
                <input type="text" name="reason" class="form-control" placeholder="e.g. Planned medical appointment" required>

                <button type="submit" class="btn-submit-leave">Submit Leave Application</button>
            </form>
        </div>
    </div>

    <!-- Personal Activity Roster -->
    <div class="card">
        <div class="card-header">
            <h3>Attendance Log & Audit History</h3>
            <p>Full record of logged clock-ins, break intervals, and management approvals.</p>
        </div>

        <div class="table-responsive">
            <table>
                <thead>
                    <tr>
                        <th>Date</th>
                        <th>Clock In</th>
                        <th>Break 1</th>
                        <th>Break 2</th>
                        <th>Clock Out</th>
                        <th>Net Duration</th>
                        <th>Verdict</th>
                        <th>Notes & HR Feedback</th>
                    </tr>
                </thead>
                <tbody>
                    <% if (myHistory != null && !myHistory.isEmpty()) { 
                        for (Attendance att : myHistory) { %>
                            <tr>
                                <td><strong><%= att.getFormattedDate() %></strong></td>
                                <td><%= (att.getFormattedCheckInTime() != null) ? att.getFormattedCheckInTime() : "--" %></td>
                                <td>
                                    <% if (att.getBreak1StartTime() != null) { %>
                                        <%= att.getFormattedBreak1Start() %> - <%= (att.getBreak1EndTime() != null ? att.getFormattedBreak1End() : "In Progress") %>
                                        <% if (att.getBreak1DurationMinutes() > 15) { %>
                                            <span style="color: var(--rose); font-size: 11px; font-weight: 700; display: block;">
                                                Exceeded (+<%= att.getBreak1DurationMinutes() - 15 %>m)
                                            </span>
                                        <% } %>
                                    <% } else { %>
                                        --
                                    <% } %>
                                </td>
                                <td>
                                    <% if (att.getBreak2StartTime() != null) { %>
                                        <%= att.getFormattedBreak2Start() %> - <%= (att.getBreak2EndTime() != null ? att.getFormattedBreak2End() : "In Progress") %>
                                        <% if (att.getBreak2DurationMinutes() > 15) { %>
                                            <span style="color: var(--rose); font-size: 11px; font-weight: 700; display: block;">
                                                Exceeded (+<%= att.getBreak2DurationMinutes() - 15 %>m)
                                            </span>
                                        <% } %>
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
                                <td>
                                    <% if ("LEAVE".equalsIgnoreCase(att.getStatus())) { %>
                                        <span class="badge-status lv-<%= att.getLeaveStatus() != null ? att.getLeaveStatus() : "PENDING_APPROVAL" %>">
                                            <%= att.getLeaveStatus() != null ? att.getLeaveStatus() : "PENDING_APPROVAL" %>
                                        </span>
                                        <% if (att.getReason() != null && !att.getReason().isBlank()) { %>
                                            <div style="font-size: 12px; color: var(--text-secondary); margin-top: 4px;">
                                                <strong>Note:</strong> <%= att.getReason() %>
                                            </div>
                                        <% } %>
                                        <% if ("REJECTED".equalsIgnoreCase(att.getLeaveStatus())) { %>
                                            <div class="remark-card">
                                                <div class="remark-header">&#9432; HR Feedback</div>
                                                <div class="remark-text">
                                                    <%= (att.getRejectionReason() != null && !att.getRejectionReason().isBlank()) 
                                                        ? att.getRejectionReason() 
                                                        : "Request does not meet current leave policy." %>
                                                </div>
                                            </div>
                                        <% } %>
                                    <% } else if (att.getReason() != null && !att.getReason().isBlank()) { %>
                                        <span style="color: var(--text-secondary);"><%= att.getReason() %></span>
                                    <% } else { %>
                                        --
                                    <% } %>
                                </td>
                            </tr>
                    <%  } 
                       } else { %>
                        <tr>
                            <td colspan="8" style="text-align: center; color: var(--text-muted); padding: 36px;">
                                No attendance activity records logged to your profile yet.
                            </td>
                        </tr>
                    <% } %>
                </tbody>
            </table>
        </div>
    </div>
</main>

<script>
    function updateLiveClock() {
        const now = new Date();
        document.getElementById('liveClock').textContent = now.toLocaleTimeString('en-US', {
            hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: true
        });
    }
    setInterval(updateLiveClock, 1000);
    updateLiveClock();
</script>

</body>
</html>