<%@ page contentType="text/html;charset=UTF-8" %>
<%@ page import="com.example.demo.model.Employee,com.example.demo.model.Team,com.example.demo.model.Task,com.example.demo.model.TeamMemberStatus,com.example.demo.model.OvertimeRequest, com.dao.OvertimeDAO" %>
<%@ page import="java.util.List, java.util.Map, java.time.LocalTime, java.sql.Date" %>
<%
    Employee mgr = (Employee) session.getAttribute("loggedInEmployee");
    Map<String, Object> managerAttendance = (Map<String, Object>) request.getAttribute("managerAttendance");
    List<Team> managedTeams = (List<Team>) request.getAttribute("managedTeams");
    Team selectedTeam = (Team) request.getAttribute("selectedTeam");
    List<TeamMemberStatus> teamRoster = (List<TeamMemberStatus>) request.getAttribute("teamRoster");
    List<Task> teamTasks = (List<Task>) request.getAttribute("teamTasks");

    boolean checkedIn = (managerAttendance != null && managerAttendance.get("clockIn") != null);
    String status = (managerAttendance != null && managerAttendance.get("status") != null) ? (String) managerAttendance.get("status") : "NOT_CHECKED_IN";
    boolean onBreak = "ON_BREAK".equalsIgnoreCase(status);
    String shiftStateText = checkedIn ? (onBreak ? "On Break" : "Working In-Shift") : "Shift Not Started";

    String toastMsg = (String) session.getAttribute("toastMsg");
    String toastWarn = (String) session.getAttribute("toastWarn");
    String toastErr = (String) session.getAttribute("toastErr");
    session.removeAttribute("toastMsg");
    session.removeAttribute("toastWarn");
    session.removeAttribute("toastErr");

    int activeTeamId = (selectedTeam != null) ? selectedTeam.getId() : 0;

    int totalTasks = (teamTasks != null) ? teamTasks.size() : 0;
    int completedTasks = 0;
    int pendingReviews = 0;
    if (teamTasks != null) {
        for (Task t : teamTasks) {
            if ("COMPLETED".equalsIgnoreCase(t.getStatus())) completedTasks++;
            if ("SUBMITTED_FOR_REVIEW".equalsIgnoreCase(t.getStatus())) pendingReviews++;
        }
    }

 // Load Dynamic Company Logo & Name (from application scope, branding.properties, or DB)
    String companyLogoUrl = (String) application.getAttribute("COMPANY_LOGO_URL");
    String companyBrandName = (String) application.getAttribute("COMPANY_NAME");

    try {
        String propsPath = application.getRealPath("/WEB-INF/branding.properties");
        java.io.File propFile = new java.io.File(propsPath);
        if (propFile.exists()) {
            java.util.Properties props = new java.util.Properties();
            try (java.io.FileInputStream fis = new java.io.FileInputStream(propFile)) {
                props.load(fis);
            }
            if (companyLogoUrl == null || companyLogoUrl.isBlank()) {
                companyLogoUrl = props.getProperty("COMPANY_LOGO_URL", "");
            }
            if (companyBrandName == null || companyBrandName.isBlank()) {
                companyBrandName = props.getProperty("COMPANY_NAME", "");
            }
        }
    } catch (Exception ignored) {}

    if (companyBrandName == null || companyBrandName.isBlank()) {
        try (java.sql.Connection conn = com.Util.DBConnection.getConnection();
             java.sql.PreparedStatement ps = conn.prepareStatement(
                 "SELECT setting_value FROM system_settings WHERE setting_key = 'COMPANY_NAME' LIMIT 1");
             java.sql.ResultSet rs = ps.executeQuery()) {
            if (rs.next()) {
                String v = rs.getString("setting_value");
                if (v != null && !v.isBlank()) {
                    companyBrandName = v.trim();
                    application.setAttribute("COMPANY_NAME", companyBrandName);
                }
            }
        } catch (Exception ignored) {}
    }

    if (companyLogoUrl == null) companyLogoUrl = "";
    if (companyBrandName == null || companyBrandName.isBlank()) companyBrandName = "EMS Enterprise";
    // Overtime Integration
    OvertimeDAO otDao = new OvertimeDAO();
    List<OvertimeRequest> pendingTeamOt = otDao.getEmployeeRequestsForManager();
    int pendingOtCount = (pendingTeamOt != null) ? pendingTeamOt.size() : 0;

    List<OvertimeRequest> myManagerOtHistory = new java.util.ArrayList<>();
    if (mgr != null) {
        try (java.sql.Connection conn = com.Util.DBConnection.getConnection();
             java.sql.PreparedStatement ps = conn.prepareStatement(
                "SELECT * FROM overtime_requests WHERE LOWER(TRIM(employee_id)) = LOWER(TRIM(?)) ORDER BY request_date DESC LIMIT 5")) {
            ps.setString(1, mgr.getEmployeeId());
            try (java.sql.ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    OvertimeRequest r = new OvertimeRequest();
                    r.setId(rs.getInt("id"));
                    r.setEmployeeId(rs.getString("employee_id"));
                    r.setRequestDate(rs.getDate("request_date"));
                    r.setRequestedHours(rs.getDouble("requested_hours"));
                    r.setReason(rs.getString("reason"));
                    r.setStatus(rs.getString("status"));
                    r.setApprovedBy(rs.getString("approved_by"));
                    myManagerOtHistory.add(r);
                }
            }
        } catch (Exception ignored) {}
    }
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>Manager Workspace | EMS Enterprise</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@500;600&display=swap" rel="stylesheet">
    <style>
        :root {
            --brand-primary: #2563eb;
            --brand-hover: #1d4ed8;
            --sidebar-bg: #0f172a;
            --border-subtle: #e2e8f0;
            --text-main: #0f172a;
            --text-muted: #64748b;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: 'Plus Jakarta Sans', sans-serif; background: #f8fafc; color: var(--text-main); display: flex; height: 100vh; overflow: hidden; }

        /* SIDEBAR & MOBILE DRAWER */
        .sidebar {
            width: 260px;
            background: var(--sidebar-bg);
            color: #fff;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
            padding: 24px 16px;
            flex-shrink: 0;
            overflow-y: auto;
            transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            z-index: 100;
        }
        .sidebar::-webkit-scrollbar { width: 4px; }
        .sidebar::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.2); border-radius: 4px; }

        .sidebar-overlay {
            display: none;
            position: fixed;
            inset: 0;
            background: rgba(15, 23, 42, 0.6);
            backdrop-filter: blur(4px);
            z-index: 99;
        }

        .logo-area { font-size: 16px; font-weight: 800; letter-spacing: -0.3px; padding-left: 8px; margin-bottom: 24px; display: flex; justify-content: space-between; align-items: center; }
        .close-sidebar-btn { display: none; background: transparent; border: none; color: #fff; font-size: 22px; cursor: pointer; }
        .nav-list { display: flex; flex-direction: column; gap: 6px; list-style: none; }
        .nav-item { display: flex; align-items: center; gap: 12px; padding: 11px 14px; border-radius: 10px; color: #94a3b8; font-size: 13px; font-weight: 700; cursor: pointer; transition: all 0.2s ease; user-select: none; }
        .nav-item:hover { color: #fff; background: rgba(255,255,255,0.06); }
        .nav-item.active { background: var(--brand-primary); color: #fff; box-shadow: 0 4px 12px rgba(37,99,235,0.3); }
        .badge-count { margin-left: auto; background: #ef4444; color: white; padding: 2px 7px; border-radius: 12px; font-size: 10.5px; font-weight: 800; }

        .main-wrapper { flex: 1; min-width: 0; display: flex; flex-direction: column; overflow-y: auto; overflow-x: hidden; }
        .topbar { background: #fff; border-bottom: 1px solid var(--border-subtle); padding: 14px 28px; display: flex; justify-content: space-between; align-items: center; flex-shrink: 0; flex-wrap: wrap; gap: 12px; }
        .mobile-hamburger-btn { display: none; background: #f1f5f9; border: 1px solid var(--border-subtle); padding: 8px 12px; border-radius: 8px; font-size: 18px; cursor: pointer; }

        .content-area { padding: 28px; display: flex; flex-direction: column; gap: 22px; max-width: 1300px; margin: 0 auto; width: 100%; }

        .card { background: #fff; border: 1px solid var(--border-subtle); border-radius: 16px; padding: 24px; box-shadow: 0 2px 4px rgba(0,0,0,0.02); }
        .grid-2 { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 20px; }
        .grid-3 { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 18px; }
        .grid-4 { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 18px; }
        .punch-grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 12px; }
        .ot-form-grid { background: #f8fafc; border: 1px solid var(--border-subtle); padding: 18px; border-radius: 12px; display: grid; grid-template-columns: 1fr 1fr 2fr auto; gap: 14px; align-items: flex-end; }
        .task-meta-grid { display: grid; grid-template-columns: 1fr 1fr 1fr 1.5fr; gap: 14px; }
        
        .stat-card { background: #fff; border: 1px solid var(--border-subtle); border-radius: 14px; padding: 20px; }
        .stat-val { font-size: 26px; font-weight: 800; margin-top: 4px; }
        .stat-lbl { font-size: 11px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; }

        .badge-pill { padding: 4px 12px; border-radius: 20px; font-size: 11px; font-weight: 700; display: inline-flex; align-items: center; white-space: nowrap; }
        .badge-green { background: #ecfdf5; color: #059669; }
        .badge-amber { background: #fef3c7; color: #b45309; }
        .badge-red { background: #fef2f2; color: #dc2626; }
        .badge-gray { background: #f1f5f9; color: #475569; }
        .badge-blue { background: #eff6ff; color: #2563eb; }
        .badge-purple { background: #f5f3ff; color: #7c3aed; }

        .mono { font-family: 'JetBrains Mono', monospace; font-size: 12.5px; }

        .btn { padding: 10px 16px; border-radius: 8px; font-size: 13px; font-weight: 700; cursor: pointer; border: none; text-decoration: none; display: inline-flex; align-items: center; justify-content: center; gap: 6px; transition: all 0.15s ease; }
        .btn-blue { background: #2563eb; color: #fff; }
        .btn-blue:hover { background: #1d4ed8; }
        .btn-amber { background: #f59e0b; color: #fff; }
        .btn-amber:hover { background: #d97706; }
        .btn-green { background: #10b981; color: #fff; }
        .btn-green:hover { background: #059669; }
        .btn-purple { background: #7c3aed; color: #fff; }
        .btn-purple:hover { background: #6d28d9; }
        .btn-dark { background: #0f172a; color: #fff; }
        .btn-del { background: #fee2e2; color: #dc2626; }
        .btn-del:hover { background: #fecaca; }
        .btn:disabled { background: #e2e8f0 !important; color: #94a3b8 !important; cursor: not-allowed; }

        .form-input { width: 100%; height: 38px; border: 1px solid var(--border-subtle); border-radius: 8px; padding: 0 12px; font-size: 13px; outline: none; background: #fff; }
        .form-input:focus { border-color: var(--brand-primary); }

        .table-responsive { width: 100%; overflow-x: auto; -webkit-overflow-scrolling: touch; margin-top: 14px; border-radius: 10px; border: 1px solid var(--border-subtle); }
        table { width: 100%; border-collapse: collapse; font-size: 13px; min-width: 640px; }
        th { text-align: left; padding: 11px 12px; background: #f8fafc; color: var(--text-muted); font-weight: 700; font-size: 11px; text-transform: uppercase; border-bottom: 1px solid var(--border-subtle); white-space: nowrap; }
        td { padding: 12px; border-bottom: 1px solid var(--border-subtle); vertical-align: middle; }
        tr:last-child td { border-bottom: none; }

        .alert { padding: 12px 18px; border-radius: 8px; font-size: 13px; font-weight: 600; }
        .alert-success { background: #ecfdf5; color: #065f46; border: 1px solid #a7f3d0; }
        .alert-warning { background: #fffbeb; color: #92400e; border: 1px solid #fde68a; }
        .alert-error { background: #fef2f2; color: #991b1b; border: 1px solid #fecaca; }

        .tab-pane { display: none; }
        .tab-pane.active { display: flex; flex-direction: column; gap: 22px; animation: fadeIn 0.2s ease; }
        @keyframes fadeIn { from { opacity: 0; transform: translateY(4px); } to { opacity: 1; transform: translateY(0); } }

        @media (max-width: 960px) {
            .grid-4 { grid-template-columns: repeat(2, minmax(0, 1fr)); }
            .ot-form-grid { grid-template-columns: 1fr 1fr; }
            .task-meta-grid { grid-template-columns: 1fr 1fr; }
        }

        @media (max-width: 820px) {
            .mobile-hamburger-btn { display: inline-flex; align-items: center; justify-content: center; }
            .close-sidebar-btn { display: inline-block; }

            .sidebar {
                position: fixed;
                top: 0; bottom: 0; left: 0;
                transform: translateX(-100%);
                box-shadow: 10px 0 30px rgba(0, 0, 0, 0.5);
            }
            .sidebar.mobile-open { transform: translateX(0); }
            .sidebar-overlay.active { display: block; }

            .topbar { padding: 12px 16px; }
            .content-area { padding: 16px 14px; gap: 16px; }
            .card { padding: 18px 16px; border-radius: 12px; }

            .grid-2, .grid-3, .grid-4, .punch-grid, .ot-form-grid, .task-meta-grid {
                grid-template-columns: 1fr;
            }
            .stat-val { font-size: 22px; }
            .team-label-hide { display: none; }
        }
    </style>
</head>
<body>

    <!-- Mobile Backdrop Overlay -->
    <div id="sidebarOverlay" class="sidebar-overlay" onclick="toggleMobileSidebar()"></div>

    <aside class="sidebar" id="managerSidebar">
        <div>
            <div class="logo-area">
                <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                    <% if (!companyLogoUrl.isEmpty()) { %>
                        <img src="<%= companyLogoUrl %>" alt="Logo" style="width: 30px; height: 30px; border-radius: 6px; object-fit: contain; background: #fff; padding: 2px; flex-shrink: 0;">
                    <% } %>
                    <span style="color: #fff; font-weight: 800; font-size: 14px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;" title="<%= companyBrandName %>">
                        <%= companyBrandName %>
                    </span>
                </div>
                <button type="button" class="close-sidebar-btn" onclick="toggleMobileSidebar()">×</button>
            </div>
            <ul class="nav-list">
                <li class="nav-item active" onclick="switchTab('tab-overview', this)">📊 Overview</li>
                <li class="nav-item" onclick="switchTab('tab-attendance', this)">⏰ Shift & Attendance</li>
                <li class="nav-item" onclick="switchTab('tab-otapprovals', this)">
                    ⏱ OT Approvals
                    <% if (pendingOtCount > 0) { %>
                        <span class="badge-count"><%= pendingOtCount %></span>
                    <% } %>
                </li>
                <li class="nav-item" onclick="switchTab('tab-leave', this)">📅 Request Leave</li>
                <li class="nav-item" onclick="window.location.href='<%= request.getContextPath() %>/drill-reports.jsp'">🔍 Team Reports & Audits</li>
                <li class="nav-item" onclick="switchTab('tab-assigntask', this)">✍ Assign Task</li>
                <li class="nav-item" onclick="switchTab('tab-taskreview', this)">
                    📋 Task Reviews (<%= pendingReviews %>)
                </li>
                <li class="nav-item" onclick="switchTab('tab-teamroster', this)">👥 Team Members</li>
            </ul>
        </div>
        <div style="padding: 12px; background: rgba(255,255,255,0.05); border-radius: 10px; font-size: 12px; margin-top: 16px;">
            <div style="font-weight: 700;"><%= (mgr != null) ? mgr.getName() : "Manager" %></div>
            <div style="color: #94a3b8; font-size: 11px; margin-top: 2px;"><%= (mgr != null) ? mgr.getEmployeeId() : "" %> • Manager</div>
        </div>
    </aside>

    <div class="main-wrapper">
        <header class="topbar">
            <div style="display: flex; align-items: center; gap: 10px;">
                <button type="button" class="mobile-hamburger-btn" onclick="toggleMobileSidebar()">☰</button>
                <h2 id="pageTitle" style="font-size: 18px; font-weight: 800;">Overview</h2>
                <span class="badge-pill <%= checkedIn ? "badge-green" : "badge-gray" %>">• <%= shiftStateText %></span>
            </div>
            
            <div style="display: flex; align-items: center; gap: 12px;">
                <% if (managedTeams != null && !managedTeams.isEmpty()) { %>
                    <form action="<%= request.getContextPath() %>/manager/dashboard" method="get" style="display: flex; align-items: center; gap: 8px;">
                        <label class="team-label-hide" style="font-size: 12px; font-weight: 700; color: var(--text-muted);">Current Team:</label>
                        <select name="teamId" onchange="this.form.submit()" class="form-input" style="width: auto; height: 36px; font-weight: 700;">
                            <% for (Team t : managedTeams) { %>
                                <option value="<%= t.getId() %>" <%= (t.getId() == activeTeamId) ? "selected" : "" %>><%= t.getTeamName() %></option>
                            <% } %>
                        </select>
                    </form>
                <% } %>
                <a href="<%= request.getContextPath() %>/logout" style="color: #ef4444; font-weight: 700; text-decoration: none; font-size: 13px; padding: 6px 10px; border-radius: 6px; background: #fef2f2;">Sign Out</a>
            </div>
        </header>

        <div class="content-area">
            <% if (toastMsg != null) { %><div class="alert alert-success"><%= toastMsg %></div><% } %>
            <% if (toastWarn != null) { %><div class="alert alert-warning"><%= toastWarn %></div><% } %>
            <% if (toastErr != null) { %><div class="alert alert-error"><%= toastErr %></div><% } %>

            <!-- TAB 1: OVERVIEW -->
            <div id="tab-overview" class="tab-pane active">
                <div class="grid-4">
                    <div class="stat-card">
                        <div class="stat-lbl">Assigned Team Tasks</div>
                        <div class="stat-val"><%= totalTasks %></div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-lbl">Pending Review & Grading</div>
                        <div class="stat-val" style="color: #d97706;"><%= pendingReviews %></div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-lbl">Pending Team Overtime</div>
                        <div class="stat-val" style="color: #7c3aed;"><%= pendingOtCount %></div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-lbl">Completed Deliverables</div>
                        <div class="stat-val" style="color: #059669;"><%= completedTasks %></div>
                    </div>
                </div>

                <div class="card">
                    <h3 style="font-size: 16px; font-weight: 800; margin-bottom: 4px;">Operational Quick Actions</h3>
                    <p style="font-size: 12px; color: var(--text-muted); margin-bottom: 16px;">Direct actions for daily team administration and shift controls.</p>
                    <div style="display: flex; gap: 12px; flex-wrap: wrap;">
                        <button onclick="document.querySelectorAll('.nav-item')[2].click()" class="btn btn-purple">⏱ Review OT Approvals (<%= pendingOtCount %>)</button>
                        <button onclick="document.querySelectorAll('.nav-item')[5].click()" class="btn btn-blue">+ Assign New Task</button>
                        <button onclick="document.querySelectorAll('.nav-item')[6].click()" class="btn btn-dark">📋 Review Submissions (<%= pendingReviews %>)</button>
                        <button onclick="document.querySelectorAll('.nav-item')[1].click()" class="btn btn-amber">⏰ Shift Punch Controls</button>
                    </div>
                </div>
            </div>

            <!-- TAB 2: OVERTIME APPROVALS (MANAGER CONSOLE) -->
            <div id="tab-otapprovals" class="tab-pane">
                <div class="card">
                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; flex-wrap: wrap; gap: 10px;">
                        <div>
                            <h3 style="font-size: 16px; font-weight: 800;">Pending Employee Overtime Approvals</h3>
                            <p style="font-size: 12px; color: var(--text-muted); margin-top: 2px;">
                                Approving an employee's OT automatically shifts their auto-checkout past <strong>18:15:00</strong> and credits 1.5x OT pay to monthly payroll.
                            </p>
                        </div>
                        <span class="badge-pill badge-purple"><%= pendingOtCount %> Actionable</span>
                    </div>

                    <div class="table-responsive">
                        <table style="margin-top: 0;">
                            <thead>
                                <tr>
                                    <th>Emp ID</th>
                                    <th>OT Date</th>
                                    <th>Requested Hours</th>
                                    <th>Reason / Deliverable</th>
                                    <th>Adjusted Checkout</th>
                                    <th style="text-align: center;">Decision Action</th>
                                </tr>
                            </thead>
                            <tbody>
                                <% if (pendingTeamOt != null && !pendingTeamOt.isEmpty()) { 
                                    for (OvertimeRequest otReq : pendingTeamOt) { 
                                        long extraMins = Math.round(otReq.getRequestedHours() * 60);
                                        LocalTime extendedOut = LocalTime.of(18, 15).plusMinutes(extraMins);
                                %>
                                    <tr>
                                        <td><strong><%= otReq.getEmployeeId() %></strong></td>
                                        <td><%= otReq.getRequestDate() %></td>
                                        <td><span class="badge-pill badge-blue">+<%= otReq.getRequestedHours() %> hrs</span></td>
                                        <td><%= otReq.getReason() %></td>
                                        <td><span class="badge-pill badge-green"><%= extendedOut.toString() %></span></td>
                                        <td style="text-align: center;">
                                            <form action="<%= request.getContextPath() %>/overtime/approve" method="POST" style="display: inline-block;">
                                                <input type="hidden" name="requestId" value="<%= otReq.getId() %>">
                                                <input type="hidden" name="employeeId" value="<%= otReq.getEmployeeId() %>">
                                                <input type="hidden" name="requestDate" value="<%= otReq.getRequestDate() %>">
                                                <input type="hidden" name="requestedHours" value="<%= otReq.getRequestedHours() %>">
                                                <button type="submit" class="btn btn-green" style="padding: 6px 14px; font-size: 12px;">
                                                    ✓ Approve OT
                                                </button>
                                            </form>
                                        </td>
                                    </tr>
                                <%  } 
                                   } else { %>
                                    <tr>
                                        <td colspan="6" style="text-align: center; color: var(--text-muted); padding: 32px;">
                                            No pending overtime requests submitted by your team members.
                                        </td>
                                    </tr>
                                <% } %>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>

            <!-- TAB 3: SHIFT & ATTENDANCE + MANAGER OT APPLICATION -->
            <div id="tab-attendance" class="tab-pane">
                <div class="card">
                    <h3 style="font-size: 16px; font-weight: 800; margin-bottom: 2px;">Your Shift Punch Controller</h3>
                    <p style="font-size: 12px; color: var(--text-muted); margin-bottom: 18px;">
                        Clock in, record intermission breaks, and check out for your daily manager shift. Auto-checkout triggers at 18:15:00 (extended on approved OT).
                    </p>

                    <form action="<%= request.getContextPath() %>/attendance/action" method="post" class="punch-grid">
                        <input type="hidden" name="redirect" value="manager">
                        <button type="submit" name="action" value="CHECK_IN" class="btn btn-blue" <%= checkedIn ? "disabled" : "" %>>Clock In</button>
                        <button type="submit" name="action" value="START_BREAK" class="btn btn-amber" <%= (!checkedIn || onBreak) ? "disabled" : "" %>>Start Break</button>
                        <button type="submit" name="action" value="END_BREAK" class="btn btn-green" <%= !onBreak ? "disabled" : "" %>>End Break</button>
                        <button type="submit" name="action" value="CHECK_OUT" class="btn btn-dark" <%= !checkedIn ? "disabled" : "" %>>Clock Out</button>
                    </form>
                </div>

                <!-- Manager Overtime Application (Routes to Admin) -->
                <div class="card">
                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px; flex-wrap: wrap; gap: 8px;">
                        <div>
                            <h3 style="font-size: 16px; font-weight: 800; display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
                                Manager Overtime (OT) Request
                                <span class="badge-pill badge-purple">Admin Approval Required</span>
                            </h3>
                            <p style="font-size: 12px; color: var(--text-muted); margin-top: 2px;">
                                Manager overtime tickets route strictly to Executive Administration for clearance.
                            </p>
                        </div>
                    </div>

                    <form action="<%= request.getContextPath() %>/overtime/apply" method="POST" class="ot-form-grid">
                        <div>
                            <label style="display: block; font-size: 11px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; margin-bottom: 4px;">Effective Date *</label>
                            <input type="date" name="requestDate" class="form-input" required value="<%= new Date(System.currentTimeMillis()) %>">
                        </div>
                        <div>
                            <label style="display: block; font-size: 11px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; margin-bottom: 4px;">OT Duration *</label>
                            <select name="requestedHours" class="form-input" required>
                                <option value="1.0">1.0 Hour (19:15 Checkout)</option>
                                <option value="1.5">1.5 Hours (19:45 Checkout)</option>
                                <option value="2.0" selected>2.0 Hours (20:15 Checkout)</option>
                                <option value="2.5">2.5 Hours (20:45 Checkout)</option>
                                <option value="3.0">3.0 Hours (21:15 Checkout)</option>
                            </select>
                        </div>
                        <div>
                            <label style="display: block; font-size: 11px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; margin-bottom: 4px;">Deliverable / Justification *</label>
                            <input type="text" name="reason" class="form-input" placeholder="e.g. Critical production release, architecture review..." required>
                        </div>
                        <div>
                            <button type="submit" class="btn btn-purple" style="height: 38px; width: 100%;">Apply to Admin</button>
                        </div>
                    </form>

                    <% if (!myManagerOtHistory.isEmpty()) { %>
                        <div style="margin-top: 18px;">
                            <h4 style="font-size: 12px; font-weight: 800; color: var(--text-muted); text-transform: uppercase; margin-bottom: 8px;">My Recent Overtime Tickets</h4>
                            <div class="table-responsive" style="margin-top: 0;">
                                <table style="margin-top: 0;">
                                    <thead>
                                        <tr>
                                            <th>Date</th>
                                            <th>Requested Duration</th>
                                            <th>Reason</th>
                                            <th>Status</th>
                                            <th>Sign-off Authority</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        <% for (OvertimeRequest myOt : myManagerOtHistory) { 
                                            String badgeCls = "badge-amber";
                                            if ("APPROVED".equalsIgnoreCase(myOt.getStatus())) badgeCls = "badge-green";
                                            else if ("REJECTED".equalsIgnoreCase(myOt.getStatus())) badgeCls = "badge-red";
                                        %>
                                            <tr>
                                                <td><strong><%= myOt.getRequestDate() %></strong></td>
                                                <td><span class="mono"><%= myOt.getRequestedHours() %> hrs</span></td>
                                                <td><%= myOt.getReason() %></td>
                                                <td><span class="badge-pill <%= badgeCls %>">• <%= myOt.getStatus() %></span></td>
                                                <td><%= (myOt.getApprovedBy() != null ? myOt.getApprovedBy() : "Pending Admin") %></td>
                                            </tr>
                                        <% } %>
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    <% } %>
                </div>

                <div class="card">
                    <h3 style="font-size: 16px; font-weight: 800; margin-bottom: 4px;">Today's Team Attendance Roster</h3>
                    <p style="font-size: 12px; color: var(--text-muted); margin-bottom: 14px;">Live shift status for members of <%= (selectedTeam != null) ? selectedTeam.getTeamName() : "Team" %>.</p>
                    <div class="table-responsive" style="margin-top: 0;">
                        <table style="margin-top: 0;">
                            <thead>
                                <tr>
                                    <th>Employee ID</th>
                                    <th>Name</th>
                                    <th>Designation</th>
                                    <th>Clock In</th>
                                    <th>Break Status</th>
                                    <th>Shift Status</th>
                                </tr>
                            </thead>
                            <tbody>
                                <% if (teamRoster != null && !teamRoster.isEmpty()) { 
                                    for (TeamMemberStatus m : teamRoster) { 
                                        String checkInVal = m.getCheckInTime();
                                        boolean isCheckedIn = checkInVal != null && !checkInVal.isBlank() && !"--".equals(checkInVal);
                                        boolean onBreakStatus = "ON_BREAK".equalsIgnoreCase(m.getTodayStatus());
                                        String bStatus = isCheckedIn ? (onBreakStatus ? "On Break" : "Working Active") : "--";

                                        String pillClass = "badge-gray";
                                        if ("PRESENT".equalsIgnoreCase(m.getTodayStatus())) pillClass = "badge-green";
                                        else if ("ON_BREAK".equalsIgnoreCase(m.getTodayStatus())) pillClass = "badge-amber";
                                        else if ("LEAVE".equalsIgnoreCase(m.getTodayStatus())) pillClass = "badge-purple";
                                %>
                                        <tr>
                                            <td><strong><%= m.getEmployeeId() %></strong></td>
                                            <td><%= m.getName() %></td>
                                            <td><%= m.getRole() %></td>
                                            <td><%= checkInVal %></td>
                                            <td><%= bStatus %></td>
                                            <td><span class="badge-pill <%= pillClass %>">• <%= m.getTodayStatus() %></span></td>
                                        </tr>
                                <%  } 
                                   } else { %>
                                        <tr><td colspan="6" style="text-align: center; color: var(--text-muted); padding: 20px;">No members assigned.</td></tr>
                                <% } %>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>

            <!-- TAB 4: MANAGER LEAVE APPLICATION -->
            <div id="tab-leave" class="tab-pane">
                <div class="grid-2">
                    <div class="card">
                        <h3 style="font-size: 16px; font-weight: 800; margin-bottom: 4px;">Request Absence / Leave</h3>
                        <p style="font-size: 12px; color: var(--text-muted); margin-bottom: 18px;">
                            Formal leave ticket submitted to HR/Admin. Scheduled shifts on approved leave dates will be locked automatically.
                        </p>

                        <form action="<%= request.getContextPath() %>/attendance/action" method="post" style="display: flex; flex-direction: column; gap: 14px;">
                            <input type="hidden" name="action" value="APPLY_LEAVE">
                            <input type="hidden" name="redirect" value="manager">

                            <div>
                                <label style="display: block; font-size: 11px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; margin-bottom: 4px;">Effective Leave Date *</label>
                                <input type="date" name="effectiveDate" class="form-input" min="<%= java.time.LocalDate.now() %>" required>
                            </div>

                            <div>
                                <label style="display: block; font-size: 11px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; margin-bottom: 4px;">Leave Type *</label>
                                <select name="leaveType" class="form-input">
                                    <option value="CASUAL">Casual Leave (CL)</option>
                                    <option value="SICK">Sick / Medical Leave (SL)</option>
                                    <option value="EARNED">Earned / Privilege Leave (PL)</option>
                                    <option value="EMERGENCY">Emergency Leave</option>
                                </select>
                            </div>

                            <div>
                                <label style="display: block; font-size: 11px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; margin-bottom: 4px;">Reason / Justification *</label>
                                <textarea name="reason" class="form-input" style="height: 70px; padding: 8px 12px;" placeholder="Specify handover notes or reason for leave..." required></textarea>
                            </div>

                            <div>
                                <button type="submit" class="btn btn-dark" style="padding: 10px 20px; width: 100%;">Submit Leave Ticket</button>
                            </div>
                        </form>
                    </div>

                    <div class="card">
                        <h3 style="font-size: 16px; font-weight: 800; margin-bottom: 6px;">Managerial Leave Guidelines</h3>
                        <p style="font-size: 12px; color: var(--text-muted); margin-bottom: 14px;">
                            Standards for managerial planned absences and team operational continuity:
                        </p>

                        <div style="display: flex; flex-direction: column; gap: 10px; font-size: 12px;">
                            <div style="background: #f8fafc; border: 1px solid var(--border-subtle); border-radius: 8px; padding: 12px;">
                                <strong>Delegation:</strong> Ensure all high-priority deliverables and team briefings are reassigned before leave starts.
                            </div>
                            <div style="background: #f8fafc; border: 1px solid var(--border-subtle); border-radius: 8px; padding: 12px;">
                                <strong>Notice Window:</strong> Planned leaves must be logged at least 24 hours in advance for schedule adjustment.
                            </div>
                            <div style="background: #f8fafc; border: 1px solid var(--border-subtle); border-radius: 8px; padding: 12px;">
                                <strong>Approval Flow:</strong> Requests route directly to Executive Administration for status sign-off.
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- TAB 5: ASSIGN TASK -->
            <div id="tab-assigntask" class="tab-pane">
                <div class="card">
                    <h3 style="font-size: 16px; font-weight: 800; margin-bottom: 2px;">Assign Task</h3>
                    <p style="font-size: 12px; color: var(--text-muted); margin-bottom: 16px;">
                        Assign deliverables individually, check multiple team members, or broadcast to the entire team with briefing files (≤ 10MB each).
                    </p>

                    <form action="<%= request.getContextPath() %>/manager/tasks/assign" method="post" enctype="multipart/form-data" onsubmit="return validateTaskForm()" style="display: flex; flex-direction: column; gap: 14px;">
                        <input type="hidden" name="action" value="ASSIGN_TASK">
                        <input type="hidden" name="teamId" value="<%= activeTeamId %>">

                        <div class="grid-2">
                            <div>
                                <label style="display: block; font-size: 11px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; margin-bottom: 4px;">Task Title *</label>
                                <input type="text" name="title" class="form-input" placeholder="e.g. Implement Payment Gateway" required>
                            </div>
                            <div>
                                <label style="display: block; font-size: 11px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; margin-bottom: 4px;">Assignment Scope *</label>
                                <select name="assignmentType" id="assignmentTypeSelect" class="form-input" onchange="toggleScope(this.value)" required>
                                    <option value="INDIVIDUAL">Single Employee</option>
                                    <option value="MULTIPLE">Select Multiple Employees</option>
                                    <option value="TEAM">Entire Team (<%= (selectedTeam != null) ? selectedTeam.getTeamName() : "Team" %>)</option>
                                </select>
                            </div>
                        </div>

                        <div id="singleEmpWrapper">
                            <label style="display: block; font-size: 11px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; margin-bottom: 4px;">Assignee *</label>
                            <select name="employeeId" id="singleEmpSelect" class="form-input" required>
                                <option value="">-- Choose Member --</option>
                                <% if (teamRoster != null) {
                                    for (TeamMemberStatus m : teamRoster) { %>
                                        <option value="<%= m.getEmployeeId() %>"><%= m.getName() %> (<%= m.getEmployeeId() %>)</option>
                                <%  } 
                                   } %>
                            </select>
                        </div>

                        <div id="multiEmpWrapper" style="display: none; background: #f8fafc; border: 1px solid var(--border-subtle); border-radius: 8px; padding: 14px;">
                            <label style="display: block; font-size: 11px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; margin-bottom: 8px;">Check Employees To Assign *</label>
                            <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 10px;">
                                <% if (teamRoster != null && !teamRoster.isEmpty()) {
                                    for (TeamMemberStatus m : teamRoster) { %>
                                        <label style="display: flex; align-items: center; gap: 8px; font-size: 12px; cursor: pointer; background: #fff; padding: 8px 12px; border-radius: 6px; border: 1px solid var(--border-subtle);">
                                            <input type="checkbox" name="selectedEmployees" value="<%= m.getEmployeeId() %>">
                                            <span><%= m.getName() %> (<strong><%= m.getEmployeeId() %></strong>)</span>
                                        </label>
                                <%  } 
                                   } else { %>
                                    <div style="font-size: 12px; color: var(--text-muted);">No members available in this team.</div>
                                <% } %>
                            </div>
                        </div>

                        <div>
                            <label style="display: block; font-size: 11px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; margin-bottom: 4px;">Task Description</label>
                            <textarea name="description" class="form-input" style="height: 60px; padding: 8px 12px;" placeholder="Provide deliverables and expectations..."></textarea>
                        </div>

                        <div class="task-meta-grid">
                            <div>
                                <label style="display: block; font-size: 11px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; margin-bottom: 4px;">Priority</label>
                                <select name="priority" class="form-input">
                                    <option value="LOW">LOW</option>
                                    <option value="MEDIUM" selected>MEDIUM</option>
                                    <option value="HIGH">HIGH</option>
                                </select>
                            </div>
                            <div>
                                <label style="display: block; font-size: 11px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; margin-bottom: 4px;">Start Date</label>
                                <input type="date" name="startDate" id="startDateInput" class="form-input">
                            </div>
                            <div>
                                <label style="display: block; font-size: 11px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; margin-bottom: 4px;">Due Date *</label>
                                <input type="date" name="dueDate" id="dueDateInput" class="form-input" required>
                            </div>
                            <div>
                                <label style="display: block; font-size: 11px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; margin-bottom: 4px;">Briefing Attachments (Multiple PDFs)</label>
                                <input type="file" name="taskFiles" class="form-input" style="padding: 4px;" accept=".pdf,.doc,.docx,.zip,.png,.jpg,.jpeg" multiple>
                            </div>
                        </div>

                        <div>
                            <button type="submit" class="btn btn-blue" style="height: 40px; padding: 0 24px;">+ Assign Task</button>
                        </div>
                    </form>
                </div>
            </div>

            <!-- TAB 6: TASK REVIEWS & SUBMISSIONS -->
            <div id="tab-taskreview" class="tab-pane">
                <div class="card">
                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; flex-wrap: wrap; gap: 12px;">
                        <div>
                            <h3 style="font-size: 16px; font-weight: 800;">Deliverables & Reviews</h3>
                            <p style="font-size: 12px; color: var(--text-muted);">Evaluate submitted documents, record ratings (1–5 stars), and approve or request revisions.</p>
                        </div>

                        <div style="display: flex; gap: 8px; flex-wrap: wrap; width: 100%; max-width: 500px;">
                            <input type="text" id="managerTaskSearch" onkeyup="applyManagerFilters()" class="form-input" placeholder="Search task, employee..." style="flex: 1; min-width: 140px;">

                            <select id="managerStatusFilter" onchange="applyManagerFilters()" class="form-input" style="width: 135px;">
                                <option value="ALL">All Statuses</option>
                                <option value="ASSIGNED">ASSIGNED</option>
                                <option value="IN_PROGRESS">IN_PROGRESS</option>
                                <option value="SUBMITTED_FOR_REVIEW">SUBMITTED</option>
                                <option value="REVISION_NEEDED">REVISION</option>
                                <option value="COMPLETED">COMPLETED</option>
                            </select>

                            <select id="managerWeeklyFilter" onchange="applyManagerFilters()" class="form-input" style="width: 145px; font-weight: 700; color: var(--brand-primary);">
                                <option value="ALL">All Timeline</option>
                                <option value="THIS_WEEK">📅 Due This Week</option>
                                <option value="NEXT_WEEK">📅 Due Next Week</option>
                                <option value="OVERDUE">⚠️ Overdue Tasks</option>
                            </select>
                        </div>
                    </div>

                    <div class="table-responsive" style="margin-top: 0;">
                        <table style="margin-top: 0; min-width: 820px;">
                            <thead>
                                <tr>
                                    <th style="width: 20%;">Task & Briefing</th>
                                    <th style="width: 10%;">Assignee</th>
                                    <th style="width: 12%;">Timeline</th>
                                    <th style="width: 18%;">Submission & Proof</th>
                                    <th style="width: 26%;">Review & Rating</th>
                                    <th style="width: 14%;">Actions</th>
                                </tr>
                            </thead>
                            <tbody id="managerTasksTableBody">
                                <% if (teamTasks != null && !teamTasks.isEmpty()) { 
                                    for (Task t : teamTasks) { 
                                        String pClass = "HIGH".equalsIgnoreCase(t.getPriority()) ? "badge-amber" : "badge-blue";
                                        String sClass = "badge-gray";
                                        if ("COMPLETED".equalsIgnoreCase(t.getStatus())) sClass = "badge-green";
                                        else if ("IN_PROGRESS".equalsIgnoreCase(t.getStatus())) sClass = "badge-blue";
                                        else if ("SUBMITTED_FOR_REVIEW".equalsIgnoreCase(t.getStatus())) sClass = "badge-purple";
                                        else if ("REVISION_NEEDED".equalsIgnoreCase(t.getStatus())) sClass = "badge-amber";

                                        String titleDisplay = (t.getTaskTitle() != null) ? t.getTaskTitle() : "";
                                        String assigneeDisplay = (t.getAssignedToName() != null && !t.getAssignedToName().isBlank()) 
                                                                  ? t.getAssignedToName() 
                                                                  : String.valueOf(t.getAssignedTo());
                                        String descEscaped = (t.getDescription() != null) ? t.getDescription().replace("'", "\\'").replace("\"", "\u0026quot;").replace("\n", " ").replace("\r", "") : "";
                                        String titleEscaped = titleDisplay.replace("'", "\\'").replace("\"", "\u0026quot;");
                                        String dueDateVal = (t.getDueDate() != null ? t.getDueDate().toString() : "");
                                %>
                                        <tr class="manager-task-row" 
                                            data-status="<%= (t.getStatus() != null ? t.getStatus().toUpperCase() : "") %>" 
                                            data-duedate="<%= dueDateVal %>">
                                            <td>
                                                <strong><%= titleDisplay %></strong>
                                                <% if (t.getDescription() != null && !t.getDescription().isBlank()) { %>
                                                    <div style="font-size: 11px; color: var(--text-muted); margin-top: 2px;"><%= t.getDescription() %></div>
                                                <% } %>
                                                
                                                <% if (t.getTaskFilePath() != null && !t.getTaskFilePath().isBlank()) { %>
                                                    <div style="margin-top: 6px; display: flex; flex-direction: column; gap: 3px;">
                                                        <% for (String fileName : t.getTaskFilePath().split(",")) { 
                                                            String trimmed = fileName.trim();
                                                            if (!trimmed.isEmpty()) {
                                                                String displayName = trimmed.contains("_") ? trimmed.substring(trimmed.indexOf('_') + 1) : trimmed;
                                                        %>
                                                            <a href="<%= request.getContextPath() %>/uploads/tasks/<%= trimmed %>" target="_blank" style="color: var(--brand-primary); font-weight: 700; text-decoration: none; font-size: 11px;">
                                                                📎 <%= displayName %>
                                                            </a>
                                                        <%  } 
                                                           } %>
                                                    </div>
                                                <% } %>
                                                <div style="margin-top: 6px;"><span class="badge-pill <%= pClass %>"><%= t.getPriority() %></span></div>
                                            </td>
                                            <td><strong><%= assigneeDisplay %></strong></td>
                                            <td>
                                                <div style="font-size: 11px;"><strong>Start:</strong> <%= (t.getStartDate() != null ? t.getStartDate().toString() : "--") %></div>
                                                <div style="font-size: 11px; color: var(--text-muted);"><strong>Due:</strong> <%= (!dueDateVal.isBlank() ? dueDateVal : "--") %></div>
                                            </td>
                                            <td>
                                                <div><span class="badge-pill <%= sClass %>">• <%= t.getStatus() %></span></div>
                                                <% if (t.getEmployeeComment() != null && !t.getEmployeeComment().isBlank()) { %>
                                                    <div style="font-size: 11px; background: #eff6ff; color: #1e40af; padding: 4px 6px; border-radius: 4px; margin-top: 4px;">
                                                        Note: "<%= t.getEmployeeComment() %>"
                                                    </div>
                                                <% } %>
                                                <% if (t.getSubmissionFilePath() != null && !t.getSubmissionFilePath().isBlank()) { %>
                                                    <div style="margin-top: 6px;">
                                                        <a href="<%= request.getContextPath() %>/uploads/submissions/<%= t.getSubmissionFilePath() %>" target="_blank" style="color: #059669; font-weight: 700; text-decoration: none; font-size: 11px;">
                                                            📄 Download Proof Document
                                                        </a>
                                                    </div>
                                                <% } else { %>
                                                    <div style="font-size: 11px; color: var(--text-muted); margin-top: 4px;">No document uploaded</div>
                                                <% } %>
                                            </td>
                                            <td>
                                                <form action="<%= request.getContextPath() %>/manager/tasks" method="post" style="display: flex; flex-direction: column; gap: 6px;">
                                                    <input type="hidden" name="action" value="UPDATE_STATUS">
                                                    <input type="hidden" name="taskId" value="<%= t.getId() %>">
                                                    <input type="hidden" name="teamId" value="<%= activeTeamId %>">

                                                    <div style="display: flex; gap: 6px;">
                                                        <select name="newStatus" class="form-input" style="height: 30px; font-size: 11px; padding: 0 4px; flex: 1;">
                                                            <option value="COMPLETED" <%= "COMPLETED".equalsIgnoreCase(t.getStatus()) ? "selected" : "" %>>COMPLETED</option>
                                                            <option value="REVISION_NEEDED" <%= "REVISION_NEEDED".equalsIgnoreCase(t.getStatus()) ? "selected" : "" %>>REVISION_NEEDED</option>
                                                            <option value="IN_PROGRESS" <%= "IN_PROGRESS".equalsIgnoreCase(t.getStatus()) ? "selected" : "" %>>IN_PROGRESS</option>
                                                            <option value="ON_HOLD" <%= "ON_HOLD".equalsIgnoreCase(t.getStatus()) ? "selected" : "" %>>ON_HOLD</option>
                                                        </select>
                                                        <select name="rating" class="form-input" style="height: 30px; font-size: 11px; padding: 0 4px; flex: 1;">
                                                            <option value="0">No Rating</option>
                                                            <option value="5" <%= (t.getRating() != null && t.getRating() == 5) ? "selected" : "" %>>★★★★★ (5)</option>
                                                            <option value="4" <%= (t.getRating() != null && t.getRating() == 4) ? "selected" : "" %>>★★★★☆ (4)</option>
                                                            <option value="3" <%= (t.getRating() != null && t.getRating() == 3) ? "selected" : "" %>>★★★☆☆ (3)</option>
                                                            <option value="2" <%= (t.getRating() != null && t.getRating() == 2) ? "selected" : "" %>>★★☆☆☆ (2)</option>
                                                            <option value="1" <%= (t.getRating() != null && t.getRating() == 1) ? "selected" : "" %>>★☆☆☆☆ (1)</option>
                                                        </select>
                                                    </div>

                                                    <input type="text" name="managerFeedback" class="form-input" style="height: 30px; font-size: 11px;" placeholder="Feedback notes..." value="<%= (t.getManagerFeedback() != null) ? t.getManagerFeedback() : "" %>">
                                                    <button type="submit" class="btn btn-dark" style="height: 28px; font-size: 11px; align-self: flex-start; padding: 0 10px;">Save Review</button>
                                                </form>
                                            </td>
                                            <td>
                                                <div style="display: flex; flex-direction: column; gap: 6px;">
                                                    <button type="button" class="btn btn-amber" style="padding: 4px 8px; font-size: 11px;"
                                                        onclick="openEditTaskModal('<%= t.getId() %>', '<%= titleEscaped %>', '<%= descEscaped %>', '<%= t.getPriority() %>', '<%= dueDateVal %>')">
                                                        Edit
                                                    </button>

                                                    <form action="<%= request.getContextPath() %>/manager/tasks" method="post" onsubmit="return confirm('Delete this task?');">
                                                        <input type="hidden" name="action" value="DELETE_TASK">
                                                        <input type="hidden" name="taskId" value="<%= t.getId() %>">
                                                        <input type="hidden" name="teamId" value="<%= activeTeamId %>">
                                                        <button type="submit" class="btn btn-del" style="padding: 4px 8px; font-size: 11px; width: 100%;">Delete</button>
                                                    </form>
                                                </div>
                                            </td>
                                        </tr>
                                <%  } 
                                   } else { %>
                                        <tr><td colspan="6" style="text-align: center; color: var(--text-muted); padding: 24px;">No tasks created for this team.</td></tr>
                                <% } %>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>

            <!-- TAB 7: TEAM ROSTER -->
            <div id="tab-teamroster" class="tab-pane">
                <div class="card">
                    <h3 style="font-size: 16px; font-weight: 800; margin-bottom: 4px;">Supervised Members</h3>
                    <p style="font-size: 12px; color: var(--text-muted); margin-bottom: 14px;">Members roster for <%= (selectedTeam != null) ? selectedTeam.getTeamName() : "Selected Team" %>.</p>
                    <div class="table-responsive" style="margin-top: 0;">
                        <table style="margin-top: 0;">
                            <thead>
                                <tr>
                                    <th>Employee ID</th>
                                    <th>Name</th>
                                    <th>Designation</th>
                                    <th>Department</th>
                                </tr>
                            </thead>
                            <tbody>
                                <% if (teamRoster != null && !teamRoster.isEmpty()) { 
                                    for (TeamMemberStatus m : teamRoster) { %>
                                        <tr>
                                            <td><strong><%= m.getEmployeeId() %></strong></td>
                                            <td><%= m.getName() %></td>
                                            <td><%= m.getRole() %></td>
                                            <td><%= (m.getDepartment() != null) ? m.getDepartment() : "Engineering" %></td>
                                        </tr>
                                <%  } 
                                   } else { %>
                                        <tr><td colspan="4" style="text-align: center; color: var(--text-muted); padding: 20px;">No members listed.</td></tr>
                                <% } %>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>

        </div>
    </div>

    <!-- Edit Task Modal -->
    <div id="editTaskModal" style="display: none; position: fixed; inset: 0; background: rgba(0,0,0,0.5); z-index: 1000; align-items: center; justify-content: center; padding: 16px;">
        <div style="background: #fff; border-radius: 14px; width: 500px; max-width: 100%; padding: 24px; box-shadow: 0 10px 25px rgba(0,0,0,0.2); max-height: 90vh; overflow-y: auto;">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;">
                <h3 style="font-size: 16px; font-weight: 800;">Edit Task Details & Files</h3>
                <span onclick="closeEditTaskModal()" style="cursor: pointer; font-size: 20px; font-weight: 700; color: #64748b;">×</span>
            </div>

            <form action="<%= request.getContextPath() %>/manager/tasks" method="post" enctype="multipart/form-data" style="display: flex; flex-direction: column; gap: 12px;">
                <input type="hidden" name="action" value="UPDATE_TASK_DETAILS">
                <input type="hidden" name="teamId" value="<%= activeTeamId %>">
                <input type="hidden" name="taskId" id="modalTaskId">

                <div>
                    <label style="display: block; font-size: 11px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; margin-bottom: 4px;">Task Title *</label>
                    <input type="text" name="title" id="modalTaskTitle" class="form-input" required>
                </div>

                <div>
                    <label style="display: block; font-size: 11px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; margin-bottom: 4px;">Description</label>
                    <textarea name="description" id="modalTaskDesc" class="form-input" style="height: 60px; padding: 8px 12px;"></textarea>
                </div>

                <div class="grid-2">
                    <div>
                        <label style="display: block; font-size: 11px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; margin-bottom: 4px;">Priority</label>
                        <select name="priority" id="modalTaskPriority" class="form-input">
                            <option value="LOW">LOW</option>
                            <option value="MEDIUM">MEDIUM</option>
                            <option value="HIGH">HIGH</option>
                        </select>
                    </div>
                    <div>
                        <label style="display: block; font-size: 11px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; margin-bottom: 4px;">Due Date *</label>
                        <input type="date" name="dueDate" id="modalTaskDueDate" class="form-input" required>
                    </div>
                </div>

                <div style="background: #f8fafc; border: 1px dashed var(--border-subtle); border-radius: 8px; padding: 10px;">
                    <label style="display: block; font-size: 11px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; margin-bottom: 4px;">
                        Replace Attached PDFs (Optional)
                    </label>
                    <input type="file" name="taskFiles" class="form-input" style="padding: 4px; background: #fff;" accept=".pdf,.doc,.docx,.zip,.png,.jpg,.jpeg" multiple>
                    <span style="font-size: 10px; color: var(--text-muted); margin-top: 4px; display: block;">
                        Leave empty to retain existing files. Uploading new documents replaces current attachments.
                    </span>
                </div>

                <div style="display: flex; justify-content: flex-end; gap: 8px; margin-top: 10px;">
                    <button type="button" class="btn" style="background: #e2e8f0; color: #475569;" onclick="closeEditTaskModal()">Cancel</button>
                    <button type="submit" class="btn btn-blue">Save & Update</button>
                </div>
            </form>
        </div>
    </div>

    <script>
    function toggleMobileSidebar() {
        var sidebar = document.getElementById('managerSidebar');
        var overlay = document.getElementById('sidebarOverlay');
        sidebar.classList.toggle('mobile-open');
        overlay.classList.toggle('active');
    }

    function switchTab(tabId, element) {
        document.querySelectorAll('.tab-pane').forEach(function(pane) {
            pane.classList.remove('active');
        });
        document.querySelectorAll('.nav-item').forEach(function(item) {
            item.classList.remove('active');
        });

        var targetPane = document.getElementById(tabId);
        if (targetPane) {
            targetPane.classList.add('active');
        }
        element.classList.add('active');

        document.getElementById('pageTitle').innerText = element.innerText.replace(/[^\w\s&]/gi, '').trim();

        if (window.innerWidth <= 820) {
            var sidebar = document.getElementById('managerSidebar');
            var overlay = document.getElementById('sidebarOverlay');
            if (sidebar.classList.contains('mobile-open')) {
                sidebar.classList.remove('mobile-open');
                overlay.classList.remove('active');
            }
        }
    }

    function toggleScope(scope) {
        var singleWrap = document.getElementById('singleEmpWrapper');
        var multiWrap = document.getElementById('multiEmpWrapper');
        var singleSelect = document.getElementById('singleEmpSelect');

        if (scope === 'INDIVIDUAL') {
            singleWrap.style.display = 'block';
            multiWrap.style.display = 'none';
            singleSelect.required = true;
        } else if (scope === 'MULTIPLE') {
            singleWrap.style.display = 'none';
            multiWrap.style.display = 'block';
            singleSelect.required = false;
            singleSelect.value = '';
        } else {
            singleWrap.style.display = 'none';
            multiWrap.style.display = 'none';
            singleSelect.required = false;
            singleSelect.value = '';
        }
    }

    function validateTaskForm() {
        var startVal = document.getElementById('startDateInput').value;
        var dueVal = document.getElementById('dueDateInput').value;
        if (startVal && dueVal) {
            if (new Date(dueVal) < new Date(startVal)) {
                alert('Due date cannot be before start date.');
                return false;
            }
        }

        var scope = document.getElementById('assignmentTypeSelect').value;
        if (scope === 'MULTIPLE') {
            var checked = document.querySelectorAll('input[name="selectedEmployees"]:checked');
            if (checked.length === 0) {
                alert('Please select at least one employee from the list.');
                return false;
            }
        }
        return true;
    }

    function openEditTaskModal(id, title, desc, priority, dueDate) {
        document.getElementById('modalTaskId').value = id;
        document.getElementById('modalTaskTitle').value = title;
        document.getElementById('modalTaskDesc').value = desc;
        document.getElementById('modalTaskPriority').value = priority ? priority : 'MEDIUM';
        document.getElementById('modalTaskDueDate').value = dueDate;

        var modal = document.getElementById('editTaskModal');
        modal.style.display = 'flex';
    }

    function closeEditTaskModal() {
        document.getElementById('editTaskModal').style.display = 'none';
    }

    function applyManagerFilters() {
        var query = document.getElementById('managerTaskSearch').value.toLowerCase();
        var statusVal = document.getElementById('managerStatusFilter').value.toUpperCase();
        var weeklyVal = document.getElementById('managerWeeklyFilter').value;
        var rows = document.querySelectorAll('.manager-task-row');

        var today = new Date();
        today.setHours(0,0,0,0);

        var currMonday = new Date(today);
        var day = currMonday.getDay();
        var diffToMonday = currMonday.getDate() - day + (day === 0 ? -6 : 1);
        currMonday.setDate(diffToMonday);
        currMonday.setHours(0,0,0,0);

        var currSunday = new Date(currMonday);
        currSunday.setDate(currMonday.getDate() + 6);
        currSunday.setHours(23,59,59,999);

        var nextMonday = new Date(currSunday);
        nextMonday.setDate(currSunday.getDate() + 1);
        nextMonday.setHours(0,0,0,0);

        var nextSunday = new Date(nextMonday);
        nextSunday.setDate(nextMonday.getDate() + 6);
        nextSunday.setHours(23,59,59,999);

        rows.forEach(function(row) {
            var text = row.innerText.toLowerCase();
            var rowSt = row.getAttribute('data-status');
            var dueDateStr = row.getAttribute('data-duedate');

            var matchesSearch = text.includes(query);
            var matchesStatus = (statusVal === 'ALL') || (rowSt === statusVal);

            var matchesWeekly = true;
            if (weeklyVal !== 'ALL') {
                if (!dueDateStr) {
                    matchesWeekly = false;
                } else {
                    var dueD = new Date(dueDateStr + "T00:00:00");
                    if (weeklyVal === 'THIS_WEEK') {
                        matchesWeekly = (dueD >= currMonday && dueD <= currSunday);
                    } else if (weeklyVal === 'NEXT_WEEK') {
                        matchesWeekly = (dueD >= nextMonday && dueD <= nextSunday);
                    } else if (weeklyVal === 'OVERDUE') {
                        matchesWeekly = (dueD < today && rowSt !== 'COMPLETED');
                    }
                }
            }

            if (matchesSearch && matchesStatus && matchesWeekly) {
                row.style.display = '';
            } else {
                row.style.display = 'none';
            }
        });
    }
    </script>
</body>
</html>