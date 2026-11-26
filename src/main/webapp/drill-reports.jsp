<%@ page contentType="text/html;charset=UTF-8" %>
<%@ page import="com.example.demo.model.Employee,com.example.demo.model.ReportItem, com.dao.ReportDAO" %>
<%@ page import="java.util.List, java.util.Map" %>
<%
    Employee loggedIn = (Employee) session.getAttribute("loggedInEmployee");
    if (loggedIn == null) {
        response.sendRedirect(request.getContextPath() + "/login.jsp");
        return;
    }

    String role = loggedIn.getRole() != null ? loggedIn.getRole().trim().toUpperCase() : "";
    boolean isAdmin = "ADMIN".equals(role);
    boolean isManager = "MANAGER".equals(role);
    boolean isHr = "HR".equals(role) || loggedIn.isHrDesignation();

    if (!isAdmin && !isManager && !isHr) {
        response.sendRedirect(request.getContextPath() + "/dashboard.jsp");
        return;
    }

    ReportDAO reportDao = new ReportDAO();

    String managerId = request.getParameter("managerId");
    String teamIdStr = request.getParameter("teamId");
    String empId = request.getParameter("empId");
    String reportType = request.getParameter("reportType");
    String fromDate = request.getParameter("fromDate");
    String toDate = request.getParameter("toDate");

    if (reportType == null || reportType.isBlank()) {
        reportType = "ATTENDANCE";
    }

    // RULE 1: HR cannot see TASK reports
    if (isHr && !isAdmin && "TASKS".equalsIgnoreCase(reportType)) {
        response.sendRedirect(request.getContextPath() + "/drill-reports.jsp?empId=" + (empId != null ? empId : "") + "&reportType=ATTENDANCE&error=Access%20Denied:%20HR%20cannot%20view%20Task%20Reports");
        return;
    }

    // Force Manager scope to their own logged-in employee ID
    if (isManager && !isAdmin) {
        managerId = loggedIn.getEmployeeId();
    }

    Integer teamId = null;
    if (teamIdStr != null && !teamIdStr.isBlank()) {
        try { teamId = Integer.parseInt(teamIdStr); } catch (Exception ignored) {}
    }

    // Safe lookup: automatically resolve managerId if teamId is passed
    if (teamId != null && (managerId == null || managerId.isBlank())) {
        try {
            java.lang.reflect.Method m = reportDao.getClass().getMethod("getManagerIdByTeam", int.class);
            Object res = m.invoke(reportDao, teamId.intValue());
            if (res != null) managerId = res.toString();
        } catch (Exception ignored) {}
    }

    // RULE 2: Validate Manager scope if inspecting an individual employee
    boolean isAccessAllowed = true;
    if (empId != null && !empId.isBlank()) {
        String cleanTargetEmp = empId.replaceAll("\\s+", "").toUpperCase();
        String cleanCurrentMgr = loggedIn.getEmployeeId().replaceAll("\\s+", "").toUpperCase();

        if (isAdmin || isHr) {
            isAccessAllowed = true;
        } else if (isManager) {
            // Manager can inspect: 1) Their own record, OR 2) An employee enrolled in their teams
            if (cleanTargetEmp.equals(cleanCurrentMgr)) {
                isAccessAllowed = true;
            } else {
                isAccessAllowed = reportDao.isEmployeeInManagerTeams(loggedIn.getEmployeeId(), empId);
            }
        }
    }

    String errorParam = request.getParameter("error");
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Enterprise Performance & Team Audits | EMS</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@500;600&display=swap" rel="stylesheet">
    <style>
        :root {
            --brand-primary: #1e40af;
            --brand-accent: #3b82f6;
            --brand-soft: #eff6ff;
            --slate-50: #f8fafc;
            --slate-100: #f1f5f9;
            --slate-200: #e2e8f0;
            --slate-300: #cbd5e1;
            --slate-400: #94a3b8;
            --slate-500: #64748b;
            --slate-600: #475569;
            --slate-700: #334155;
            --slate-800: #1e293b;
            --slate-900: #0f172a;
            --success-border: #bbf7d0;
            --success-bg: #f0fdf4;
            --success-text: #15803d;
            --danger-border: #fecaca;
            --danger-bg: #fef2f2;
            --danger-text: #b91c1c;
            --warning-border: #fef08a;
            --warning-bg: #fefce8;
            --warning-text: #a16207;
            --shadow-subtle: 0 1px 3px rgba(15, 23, 42, 0.04), 0 1px 2px -1px rgba(15, 23, 42, 0.04);
            --shadow-card: 0 4px 6px -1px rgba(15, 23, 42, 0.04), 0 2px 4px -2px rgba(15, 23, 42, 0.03);
            --radius-md: 10px;
            --radius-lg: 14px;
        }

        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: 'Plus Jakarta Sans', sans-serif; background: var(--slate-50); color: var(--slate-900); padding: 32px 24px; -webkit-font-smoothing: antialiased; line-height: 1.5; }
        .container { max-width: 1320px; margin: 0 auto; display: flex; flex-direction: column; gap: 20px; }

        .page-header { display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 14px; }
        .back-link { text-decoration: none; color: var(--slate-700); font-weight: 700; font-size: 13px; display: inline-flex; align-items: center; gap: 6px; padding: 8px 14px; background: #fff; border: 1px solid var(--slate-200); border-radius: 8px; transition: all 0.15s ease; box-shadow: var(--shadow-subtle); }
        .back-link:hover { background: var(--slate-100); color: var(--slate-900); }

        .top-action-bar { display: flex; justify-content: space-between; align-items: center; gap: 14px; flex-wrap: wrap; background: #ffffff; border: 1px solid var(--slate-200); padding: 12px 18px; border-radius: 12px; box-shadow: var(--shadow-subtle); }
        .breadcrumb-bar { display: flex; align-items: center; gap: 8px; font-size: 13px; font-weight: 700; flex-wrap: wrap; }
        .breadcrumb-bar a { color: var(--brand-accent); text-decoration: none; display: inline-flex; align-items: center; gap: 5px; }
        .breadcrumb-bar a:hover { text-decoration: underline; }
        .breadcrumb-sep { color: var(--slate-300); font-weight: 400; }
        .breadcrumb-curr { color: var(--slate-500); }

        .direct-search-box { display: flex; align-items: center; gap: 8px; }
        .direct-search-input { height: 36px; border: 1px solid var(--slate-300); border-radius: 8px; padding: 0 12px; font-size: 12.5px; outline: none; width: 230px; font-family: inherit; }
        .direct-search-input:focus { border-color: var(--brand-accent); box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.12); }

        .card { background: #ffffff; border: 1px solid var(--slate-200); border-radius: var(--radius-lg); padding: 24px 28px; box-shadow: var(--shadow-card); }
        
        .section-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; flex-wrap: wrap; gap: 12px; }
        .section-title { font-size: 18px; font-weight: 800; color: var(--slate-900); letter-spacing: -0.01em; }
        .section-subtitle { font-size: 12.5px; color: var(--slate-500); margin-top: 2px; }

        .grid-cards { display: grid; grid-template-columns: repeat(auto-fill, minmax(330px, 1fr)); gap: 16px; }
        .exec-card { background: #ffffff; border: 1px solid var(--slate-200); border-radius: 12px; padding: 18px 20px; text-decoration: none; color: inherit; display: flex; flex-direction: column; justify-content: space-between; transition: all 0.2s ease; position: relative; overflow: hidden; }
        .exec-card:hover { border-color: var(--brand-accent); transform: translateY(-2px); box-shadow: var(--shadow-card); }
        .exec-card::before { content: ""; position: absolute; top: 0; left: 0; width: 4px; height: 100%; background: transparent; transition: background 0.2s ease; }
        .exec-card:hover::before { background: var(--brand-primary); }

        .card-top { display: flex; align-items: center; gap: 14px; }
        .avatar-circle { width: 44px; height: 44px; border-radius: 10px; background: var(--brand-soft); color: var(--brand-primary); display: flex; align-items: center; justify-content: center; font-weight: 800; font-size: 15px; flex-shrink: 0; }
        .card-title { font-size: 15px; font-weight: 800; color: var(--slate-900); }
        .card-sub { font-size: 12px; color: var(--slate-500); margin-top: 2px; }

        .card-footer { display: flex; align-items: center; justify-content: space-between; margin-top: 16px; padding-top: 14px; border-top: 1px solid var(--slate-100); }

        .badge { font-size: 11px; font-weight: 700; padding: 4px 10px; border-radius: 6px; display: inline-flex; align-items: center; gap: 4px; letter-spacing: 0.02em; }
        .badge-blue { background: var(--brand-soft); color: var(--brand-primary); border: 1px solid #bfdbfe; }
        .badge-amber { background: var(--warning-bg); color: var(--warning-text); border: 1px solid var(--warning-border); }
        .badge-green { background: var(--success-bg); color: var(--success-text); border: 1px solid var(--success-border); }
        .badge-gray { background: var(--slate-100); color: var(--slate-600); border: 1px solid var(--slate-200); }
        .badge-purple { background: #f5f3ff; color: #6d28d9; border: 1px solid #ddd6fe; }

        .rating-stars { color: #f59e0b; font-weight: 800; font-size: 12px; }
        .feedback-pill { font-size: 11px; background: var(--warning-bg); color: var(--warning-text); border: 1px solid var(--warning-border); padding: 3px 6px; border-radius: 4px; margin-top: 3px; display: inline-block; font-weight: 600; }

        .grid-2 { display: grid; grid-template-columns: 420px 1fr; gap: 20px; }
        .table-wrap { border: 1px solid var(--slate-200); border-radius: var(--radius-md); overflow: hidden; background: #ffffff; margin-top: 12px; }
        table { width: 100%; border-collapse: collapse; font-size: 13px; text-align: left; }
        th { padding: 12px 16px; background: #f8fafc; color: var(--slate-600); font-size: 11px; text-transform: uppercase; font-weight: 700; border-bottom: 1px solid var(--slate-200); letter-spacing: 0.04em; }
        td { padding: 13px 16px; border-bottom: 1px solid var(--slate-200); vertical-align: top; color: var(--slate-700); }
        tr:last-child td { border-bottom: none; }
        tr:hover td { background: #fafbfc; }

        .search-field { height: 38px; border: 1px solid var(--slate-300); border-radius: 8px; padding: 0 12px; font-size: 13px; outline: none; background: #fff; width: 240px; }
        .search-field:focus { border-color: var(--brand-accent); box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.12); }

        .filter-form { display: flex; gap: 10px; align-items: center; flex-wrap: wrap; margin-top: 16px; padding: 14px 18px; background: var(--slate-50); border-radius: var(--radius-md); border: 1px solid var(--slate-200); }
        .form-input { height: 38px; border: 1px solid var(--slate-300); border-radius: 8px; padding: 0 12px; font-size: 13px; outline: none; background: #fff; }
        .form-input:focus { border-color: var(--brand-accent); }
        
        .btn { height: 38px; padding: 0 16px; border-radius: 8px; font-size: 12.5px; font-weight: 700; cursor: pointer; display: inline-flex; align-items: center; gap: 6px; text-decoration: none; border: 1px solid transparent; transition: all 0.15s ease; box-shadow: var(--shadow-subtle); }
        .btn-primary { background: var(--brand-primary); color: #fff; }
        .btn-primary:hover { background: #172554; }
        .btn-outline { background: #fff; border: 1px solid var(--slate-300); color: var(--slate-700); }
        .btn-outline:hover { background: var(--slate-100); }
        .btn-csv { background: var(--success-bg); color: var(--success-text); border: 1px solid var(--success-border); }
        .btn-csv:hover { background: #dcfce7; }
        .btn-pdf { background: #ffffff; color: var(--slate-700); border: 1px solid var(--slate-300); }
        .btn-pdf:hover { background: var(--slate-100); }
        
        .tab-btn { padding: 8px 16px; border-radius: 8px; font-size: 12.5px; font-weight: 700; text-decoration: none; border: 1px solid var(--slate-200); background: #fff; color: var(--slate-700); transition: all 0.15s ease; }
        .tab-btn.active { background: var(--brand-primary); color: #fff; border-color: var(--brand-primary); }

        .alert-error { background: var(--danger-bg); border: 1px solid var(--danger-border); color: var(--danger-text); padding: 12px 18px; border-radius: 10px; font-size: 13px; font-weight: 700; }

        @media print {
            body { background: #fff !important; padding: 0 !important; color: #000 !important; }
            .breadcrumb-bar, .top-action-bar, .filter-form, .tab-btn, .no-print, .page-header { display: none !important; }
            .card { border: none !important; box-shadow: none !important; padding: 0 !important; }
            table { width: 100% !important; border: 1px solid #ddd !important; font-size: 11pt !important; }
            th, td { border: 1px solid #ddd !important; padding: 8px !important; color: #000 !important; }
            th { background: #f2f2f2 !important; }
            .print-header { display: block !important; margin-bottom: 20px; }
        }
        .print-header { display: none; }
    </style>
</head>
<body>

<div class="container">

    <div class="page-header no-print">
        <div>
            <h2 style="font-size: 22px; font-weight: 800; letter-spacing: -0.3px;">Enterprise Performance & Team Audits</h2>
            <p style="font-size: 12.5px; color: var(--slate-500); margin-top: 2px;">
                <%= isAdmin ? "Global Audit Authority: All employees, teams, and departments." : 
                    (isHr ? "HR Registry Audit: Employee attendance and leave compliance." : 
                    "Managerial Console: Direct team allocations and performance ratings.") %>
            </p>
        </div>
        <div style="display: flex; gap: 10px; align-items: center;">
            <% if (isManager) { %>
                <!-- Manager Self Report Direct Link -->
                <a href="<%= request.getContextPath() %>/drill-reports.jsp?empId=<%= loggedIn.getEmployeeId() %>&reportType=ATTENDANCE" class="btn btn-outline" style="font-size: 12px; height: 36px;">
                    &#128100; View My Personal Report
                </a>
            <% } %>
            <a href="<%= isAdmin ? request.getContextPath() + "/dashboard.jsp" : 
                        (isHr ? request.getContextPath() + "/dashboard.jsp" : request.getContextPath() + "/managerDashboard.jsp") %>" class="back-link">
                &#8592; Back to Dashboard
            </a>
        </div>
    </div>

    <% if (errorParam != null && !errorParam.isBlank()) { %>
        <div class="alert-error no-print">&#9888; <%= errorParam %></div>
    <% } %>

    <!-- Navigation Bar with Role-Filtered Search -->
    <div class="top-action-bar no-print">
        <div class="breadcrumb-bar">
            <% if (isAdmin || isHr) { %>
                <a href="<%= request.getContextPath() %>/drill-reports.jsp">&#128101; <%= isAdmin ? "All Managers" : "Company Teams" %></a>
                <% if (managerId != null && !managerId.isBlank()) { %>
                    <span class="breadcrumb-sep">&#8250;</span>
                    <a href="<%= request.getContextPath() %>/drill-reports.jsp?managerId=<%= managerId %>">Manager: <%= managerId %></a>
                <% } %>
            <% } else { %>
                <a href="<%= request.getContextPath() %>/drill-reports.jsp">&#128101; Supervised Teams</a>
            <% } %>

            <% if (teamId != null) { %>
                <span class="breadcrumb-sep">&#8250;</span>
                <a href="<%= request.getContextPath() %>/drill-reports.jsp?<%= (managerId != null ? "managerId=" + managerId + "&" : "") %>teamId=<%= teamId %>">Team #<%= teamId %></a>
            <% } %>

            <% if (empId != null && isAccessAllowed) { %>
                <span class="breadcrumb-sep">&#8250;</span>
                <span class="breadcrumb-curr">Employee: <strong><%= empId %></strong></span>
            <% } %>
        </div>

        <!-- Direct Search Box (Scoped by Role) -->
        <form action="<%= request.getContextPath() %>/drill-reports.jsp" method="get" class="direct-search-box">
            <input type="text" name="empId" class="direct-search-input" 
                   placeholder="<%= isManager && !isAdmin ? "Search team member ID..." : "Search Employee ID..." %>" 
                   required value="<%= (empId != null && isAccessAllowed) ? empId : "" %>">
            <input type="hidden" name="reportType" value="ATTENDANCE">
            <button type="submit" class="btn btn-primary" style="height: 36px; padding: 0 12px; font-size: 12px;">Audit Employee</button>
        </form>
    </div>

    <!-- LEVEL 1: ALL MANAGERS DIRECTORY (ADMIN ONLY) -->
    <% if (isAdmin && managerId == null && teamId == null && empId == null) { 
        List<Map<String, Object>> managers = reportDao.getAllManagers();
    %>
        <div class="card">
            <div class="section-header">
                <div>
                    <div class="section-title">Department Management Directory</div>
                    <div class="section-subtitle">Select any department manager to inspect their assigned teams and personnel performance.</div>
                </div>
                <input type="text" id="mgrSearchInput" onkeyup="filterDirectory('mgr-item', 'mgrSearchInput')" class="search-field" placeholder="Search manager or department...">
            </div>
            
            <div class="grid-cards">
                <% if (managers != null && !managers.isEmpty()) { 
                    for (Map<String, Object> m : managers) { 
                        String mName = (String) m.get("name");
                        String initials = (mName != null && mName.length() >= 2) ? mName.substring(0, 2).toUpperCase() : "MG";
                %>
                        <a href="<%= request.getContextPath() %>/drill-reports.jsp?managerId=<%= m.get("employee_id") %>" class="exec-card mgr-item">
                            <div class="card-top">
                                <div class="avatar-circle"><%= initials %></div>
                                <div>
                                    <div class="card-title"><%= mName %></div>
                                    <div class="card-sub"><%= m.get("employee_id") %> &bull; <%= m.get("department") %></div>
                                </div>
                            </div>
                            <div class="card-footer">
                                <span class="badge badge-blue"><%= m.get("team_count") %> Supervised Teams</span>
                                <span style="font-size: 12px; font-weight: 700; color: var(--brand-accent);">View Teams &rarr;</span>
                            </div>
                        </a>
                <%  } 
                   } else { %>
                    <p style="color: var(--slate-500); padding: 24px;">No department managers registered in the system.</p>
                <% } %>
            </div>
        </div>
    <% } %>

    <!-- LEVEL 2: TEAMS SUPERVISED BY SPECIFIC MANAGER -->
    <% if (managerId != null && teamId == null && empId == null) { 
        List<Map<String, Object>> teams = reportDao.getTeamsByManager(managerId);
    %>
        <div class="card">
            <div class="section-header">
                <div>
                    <div class="section-title">
                        <%= isAdmin ? "Supervised Operations & Teams (" + managerId + ")" : "Operational Teams in Your Portfolio" %>
                    </div>
                    <div class="section-subtitle">Select a team below to review personnel attendance, active deliverables, and average rating scores.</div>
                </div>
                <input type="text" id="teamSearchInput" onkeyup="filterDirectory('team-item', 'teamSearchInput')" class="search-field" placeholder="Search team...">
            </div>

            <div class="grid-cards">
                <% if (teams != null && !teams.isEmpty()) { 
                    for (Map<String, Object> t : teams) { 
                        String tName = (String) t.get("team_name");
                        String initials = (tName != null && tName.length() >= 2) ? tName.substring(0, 2).toUpperCase() : "TM";
                %>
                        <a href="<%= request.getContextPath() %>/drill-reports.jsp?<%= (isAdmin ? "managerId=" + managerId + "&" : "") %>teamId=<%= t.get("id") %>" class="exec-card team-item">
                            <div class="card-top">
                                <div class="avatar-circle" style="background: var(--slate-100); color: var(--slate-700);"><%= initials %></div>
                                <div>
                                    <div class="card-title"><%= tName %></div>
                                    <div class="card-sub">Internal Unit ID: #<%= t.get("id") %></div>
                                </div>
                            </div>
                            <div class="card-footer">
                                <div style="display: flex; gap: 6px;">
                                    <span class="badge badge-blue"><%= t.get("member_count") %> Members</span>
                                    <% if (!isHr || isAdmin) { %>
                                        <span class="badge badge-amber"><%= t.get("task_count") %> Tasks</span>
                                    <% } %>
                                </div>
                                <span style="font-size: 12px; font-weight: 700; color: var(--brand-accent);">Inspect Unit &rarr;</span>
                            </div>
                        </a>
                <%  } 
                   } else { %>
                    <p style="color: var(--slate-500); padding: 24px;">No operational teams currently assigned to this manager.</p>
                <% } %>
            </div>
        </div>
    <% } %>

    <!-- LEVEL 3: TEAM MEMBERS & TEAM TASKS -->
    <% if (teamId != null && empId == null) { 
        List<Map<String, Object>> members = reportDao.getTeamMembers(teamId);
        List<Map<String, Object>> tasks = reportDao.getTeamTasks(teamId);

        int ratedTeamTasks = 0;
        double teamRatingSum = 0;
        if (tasks != null) {
            for (Map<String, Object> tk : tasks) {
                Object rObj = tk.get("rating");
                if (rObj != null) {
                    try {
                        int rVal = Integer.parseInt(rObj.toString());
                        if (rVal > 0) {
                            ratedTeamTasks++;
                            teamRatingSum += rVal;
                        }
                    } catch (Exception ignored) {}
                }
            }
        }
        double teamAvgRating = (ratedTeamTasks > 0) ? (teamRatingSum / ratedTeamTasks) : 0.0;
    %>
        <div class="<%= (!isHr || isAdmin) ? "grid-2" : "" %>">
            <!-- Left: Member Roster -->
            <div class="card">
                <div class="section-title">Enrolled Members (Team #<%= teamId %>)</div>
                <div class="section-subtitle">Click an employee to audit their individual records.</div>

                <div class="table-wrap">
                    <table>
                        <thead>
                            <tr>
                                <th>Member Name</th>
                                <th>Department</th>
                                <th>Action</th>
                            </tr>
                        </thead>
                        <tbody>
                            <% if (members != null && !members.isEmpty()) { 
                                for (Map<String, Object> mem : members) { %>
                                    <tr>
                                        <td>
                                            <strong><%= mem.get("name") %></strong>
                                            <div style="font-size: 11px; color: var(--slate-400); font-family: 'JetBrains Mono', monospace;"><%= mem.get("employee_id") %></div>
                                        </td>
                                        <td><%= mem.get("department") %></td>
                                        <td>
                                            <a href="<%= request.getContextPath() %>/drill-reports.jsp?<%= (managerId != null ? "managerId=" + managerId + "&" : "") %>teamId=<%= teamId %>&empId=<%= mem.get("employee_id") %>&reportType=ATTENDANCE" 
                                               style="color: var(--brand-accent); font-weight: 700; text-decoration: none; font-size: 12px;">
                                                Audit Reports &#8594;
                                            </a>
                                        </td>
                                    </tr>
                            <%  } 
                               } else { %>
                                <tr><td colspan="3" style="text-align: center; color: var(--slate-500); padding: 24px;">No members enrolled in this team.</td></tr>
                            <% } %>
                        </tbody>
                    </table>
                </div>
            </div>

            <!-- Right: Team Tasks & Quality Average (HIDDEN FROM HR) -->
            <% if (!isHr || isAdmin) { %>
                <div class="card">
                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; flex-wrap: wrap; gap: 8px;">
                        <div>
                            <div class="section-title">Team Deliverables & Tasks</div>
                            <div class="section-subtitle">Current workflow tracked under Team #<%= teamId %>.</div>
                        </div>

                        <div style="background: var(--warning-bg); border: 1px solid var(--warning-border); padding: 6px 14px; border-radius: 8px; display: flex; align-items: center; gap: 6px;">
                            <span style="font-size: 11px; font-weight: 800; color: var(--warning-text); text-transform: uppercase;">Team Quality Rating:</span>
                            <strong style="color: #b45309; font-size: 13px;">
                                <%= (ratedTeamTasks > 0) ? String.format("%.1f", teamAvgRating) + " ★ (" + ratedTeamTasks + " rated)" : "No ratings yet" %>
                            </strong>
                        </div>
                    </div>

                    <div class="table-wrap">
                        <table>
                            <thead>
                                <tr>
                                    <th style="width: 25%;">Task Title</th>
                                    <th style="width: 15%;">Assignee</th>
                                    <th style="width: 15%;">Due Date</th>
                                    <th style="width: 15%;">Status</th>
                                    <th style="width: 30%;">Quality Rating & Feedback</th>
                                </tr>
                            </thead>
                            <tbody>
                                <% if (tasks != null && !tasks.isEmpty()) { 
                                    for (Map<String, Object> tk : tasks) { 
                                        int rVal = 0;
                                        Object rObj = tk.get("rating");
                                        if (rObj != null) {
                                            try { rVal = Integer.parseInt(rObj.toString()); } catch (Exception ignored) {}
                                        }
                                        String fb = (String) tk.get("manager_feedback");
                                        String st = (String) tk.get("status");

                                        String stBadge = "badge-gray";
                                        if ("COMPLETED".equalsIgnoreCase(st)) stBadge = "badge-green";
                                        else if ("IN_PROGRESS".equalsIgnoreCase(st)) stBadge = "badge-blue";
                                        else if ("SUBMITTED_FOR_REVIEW".equalsIgnoreCase(st)) stBadge = "badge-purple";
                                %>
                                        <tr>
                                            <td><strong><%= tk.get("title") %></strong></td>
                                            <td><%= tk.get("emp_name") %></td>
                                            <td><%= (tk.get("due_date") != null ? tk.get("due_date") : "--") %></td>
                                            <td><span class="badge <%= stBadge %>"><%= st %></span></td>
                                            <td>
                                                <% if (rVal > 0) { %>
                                                    <div class="rating-stars"><%= "★".repeat(rVal) + "☆".repeat(5 - rVal) %> (<%= rVal %>/5)</div>
                                                <% } else { %>
                                                    <span style="color: var(--slate-400); font-size: 11px;">Not rated</span>
                                                <% } %>
                                                <% if (fb != null && !fb.isBlank()) { %>
                                                    <div class="feedback-pill"><%= fb %></div>
                                                <% } %>
                                            </td>
                                        </tr>
                                <%  } 
                                   } else { %>
                                    <tr><td colspan="5" style="text-align: center; color: var(--slate-500); padding: 24px;">No deliverables assigned to this team.</td></tr>
                                <% } %>
                            </tbody>
                        </table>
                    </div>
                </div>
            <% } %>
        </div>
    <% } %>

    <!-- LEVEL 4: EMPLOYEE REPORT AUDIT SUITE -->
    <% if (empId != null) { 
        if (!isAccessAllowed) { %>
            <div class="card" style="text-align: center; padding: 48px 24px;">
                <div style="font-size: 36px; margin-bottom: 12px;">🚫</div>
                <h3 style="font-size: 18px; font-weight: 800; color: var(--danger-text);">Access Restricted</h3>
                <p style="font-size: 13px; color: var(--slate-500); margin-top: 6px;">
                    Managers are only permitted to audit employees assigned to their supervised teams or their own personal records.
                </p>
                <div style="margin-top: 18px;">
                    <a href="<%= request.getContextPath() %>/drill-reports.jsp" class="btn btn-primary">Return to Team Directory</a>
                </div>
            </div>
    <%  } else { %>
            <div class="card">
                
                <div class="print-header">
                    <h2 style="font-size: 16pt; font-weight: 800; margin-bottom: 4px;">EMPLOYEE <%= reportType %> AUDIT REPORT</h2>
                    <p style="font-size: 10pt; color: #555;">
                        <strong>Employee ID:</strong> <%= empId %> &nbsp;|&nbsp; 
                        <strong>Scope:</strong> <%= (teamId != null ? "Team #" + teamId : "Direct / Personnel Registry") %> &nbsp;|&nbsp; 
                        <strong>Timeline:</strong> <%= (fromDate != null && !fromDate.isBlank()) ? fromDate : "Initial" %> to <%= (toDate != null && !toDate.isBlank()) ? toDate : "Current" %>
                    </p>
                    <hr style="margin: 10px 0; border: 0.5px solid #ccc;">
                </div>

                <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 12px;" class="no-print">
                    <div>
                        <div class="section-title">Personnel Audit Profile: <%= empId %></div>
                        <div class="section-subtitle">Review historical activity records, performance scores, and deliverable submissions.</div>
                    </div>

                    <div style="display: flex; gap: 6px;">
                        <a href="<%= request.getContextPath() %>/drill-reports.jsp?<%= (managerId != null ? "managerId=" + managerId + "&" : "") %><%= (teamId != null ? "teamId=" + teamId + "&" : "") %>empId=<%= empId %>&reportType=ATTENDANCE" 
                           class="tab-btn <%= "ATTENDANCE".equals(reportType) ? "active" : "" %>">&#9200; Shift Attendance</a>

                        <a href="<%= request.getContextPath() %>/drill-reports.jsp?<%= (managerId != null ? "managerId=" + managerId + "&" : "") %><%= (teamId != null ? "teamId=" + teamId + "&" : "") %>empId=<%= empId %>&reportType=LEAVES" 
                           class="tab-btn <%= "LEAVES".equals(reportType) ? "active" : "" %>">&#127796; Leave History</a>

                        <!-- TASK DELIVERABLES TAB: VISIBLE ONLY TO MANAGERS AND ADMIN (HIDDEN FROM HR) -->
                        <% if (!isHr || isAdmin) { %>
                            <a href="<%= request.getContextPath() %>/drill-reports.jsp?<%= (managerId != null ? "managerId=" + managerId + "&" : "") %><%= (teamId != null ? "teamId=" + teamId + "&" : "") %>empId=<%= empId %>&reportType=TASKS" 
                               class="tab-btn <%= "TASKS".equals(reportType) ? "active" : "" %>">&#128203; Task Deliverables</a>
                        <% } %>
                    </div>
                </div>

                <!-- Date Filter & Actions -->
                <form action="<%= request.getContextPath() %>/drill-reports.jsp" method="get" class="filter-form no-print">
                    <% if (managerId != null) { %><input type="hidden" name="managerId" value="<%= managerId %>"><% } %>
                    <% if (teamId != null) { %><input type="hidden" name="teamId" value="<%= teamId %>"><% } %>
                    <input type="hidden" name="empId" value="<%= empId %>">
                    <input type="hidden" name="reportType" value="<%= reportType %>">

                    <label style="font-size: 11px; font-weight: 700; color: var(--slate-500); text-transform: uppercase;">From:</label>
                    <input type="date" name="fromDate" value="<%= (fromDate != null ? fromDate : "") %>" class="form-input">

                    <label style="font-size: 11px; font-weight: 700; color: var(--slate-500); text-transform: uppercase;">To:</label>
                    <input type="date" name="toDate" value="<%= (toDate != null ? toDate : "") %>" class="form-input">

                    <button type="submit" class="btn btn-primary">Apply Date Filter</button>
                    <a href="<%= request.getContextPath() %>/drill-reports.jsp?<%= (managerId != null ? "managerId=" + managerId + "&" : "") %><%= (teamId != null ? "teamId=" + teamId + "&" : "") %>empId=<%= empId %>&reportType=<%= reportType %>" 
                       style="font-size: 12px; color: var(--slate-500); text-decoration: none; padding: 0 4px;">Reset</a>

                    <div style="margin-left: auto; display: flex; gap: 8px;">
                        <button type="button" class="btn btn-csv" onclick="exportTableToCSV('<%= empId %>_<%= reportType %>_report.csv')">
                            &#128190; Export to CSV
                        </button>
                        <button type="button" class="btn btn-pdf" onclick="window.print()">
                            &#128424; Print / Save PDF
                        </button>
                    </div>
                </form>

                <div class="table-wrap">
                    <table id="drillReportTable">
                        <% if ("ATTENDANCE".equals(reportType)) { 
                            List<ReportItem> attList = reportDao.getAttendanceReportPaginated(role, loggedIn.getEmployeeId(), empId, fromDate, toDate, 0, 100);
                        %>
                            <thead>
                                <tr>
                                    <th style="width: 25%;">Log Date</th>
                                    <th style="width: 50%;">Time Window (Check-In - Check-Out)</th>
                                    <th style="width: 25%;">Audit Status</th>
                                </tr>
                            </thead>
                            <tbody>
                                <% if (attList != null && !attList.isEmpty()) { 
                                    for (ReportItem r : attList) { %>
                                        <tr>
                                            <td><strong><%= r.getRecordDate() %></strong></td>
                                            <td style="font-family: 'JetBrains Mono', monospace;"><%= r.getDetails() %></td>
                                            <td><span class="badge badge-green"><%= r.getStatus() %></span></td>
                                        </tr>
                                <%  } 
                                   } else { %>
                                    <tr><td colspan="3" style="text-align: center; color: var(--slate-400); padding: 36px;">No attendance logs found matching the date range.</td></tr>
                                <% } %>
                            </tbody>

                        <% } else if ("LEAVES".equals(reportType)) { 
                            List<ReportItem> leaveList = reportDao.getLeaveReportPaginated(role, loggedIn.getEmployeeId(), empId, "ALL", fromDate, toDate, 0, 100);
                        %>
                            <thead>
                                <tr>
                                    <th style="width: 20%;">Attendance Ref</th>
                                    <th style="width: 25%;">Leave Date</th>
                                    <th style="width: 35%;">Reason / Remarks</th>
                                    <th style="width: 20%;">Approval Status</th>
                                </tr>
                            </thead>
                            <tbody>
                                <% if (leaveList != null && !leaveList.isEmpty()) { 
                                    for (ReportItem lv : leaveList) { %>
                                        <tr>
                                            <td><strong><%= lv.getId() %></strong></td>
                                            <td style="font-family: 'JetBrains Mono', monospace;"><%= lv.getStartDate() %></td>
                                            <td><%= (lv.getDetails() != null ? lv.getDetails() : "--") %></td>
                                            <td><span class="badge badge-amber"><%= lv.getStatus() %></span></td>
                                        </tr>
                                <%  } 
                                   } else { %>
                                    <tr><td colspan="4" style="text-align: center; color: var(--slate-400); padding: 36px;">No leave records recorded for this date range.</td></tr>
                                <% } %>
                            </tbody>

                        <% } else if ("TASKS".equals(reportType) && (!isHr || isAdmin)) { 
                            List<ReportItem> taskList = reportDao.getTaskReportPaginated(role, loggedIn.getEmployeeId(), empId, "ALL", fromDate, toDate, 0, 100);
                        %>
                            <thead>
                                <tr>
                                    <th style="width: 10%;">Task ID</th>
                                    <th style="width: 28%;">Title & Briefing</th>
                                    <th style="width: 14%;">Due Date</th>
                                    <th style="width: 12%;">Priority</th>
                                    <th style="width: 14%;">Status</th>
                                    <th style="width: 22%;">Quality Rating & Feedback</th>
                                </tr>
                            </thead>
                            <tbody>
                                <% if (taskList != null && !taskList.isEmpty()) { 
                                    for (ReportItem tk : taskList) { 
                                        int rVal = 0;
                                        String fb = "";
                                        String details = tk.getDetails();
                                        if (details != null && details.contains("::")) {
                                            String[] parts = details.split("::", 2);
                                            try { rVal = Integer.parseInt(parts[0]); } catch (Exception ignored) {}
                                            if (parts.length > 1) fb = parts[1];
                                        }

                                        String st = (tk.getStatus() != null ? tk.getStatus() : "ASSIGNED");

                                        String stBadge = "badge-gray";
                                        if ("COMPLETED".equalsIgnoreCase(st)) stBadge = "badge-green";
                                        else if ("IN_PROGRESS".equalsIgnoreCase(st)) stBadge = "badge-blue";
                                        else if ("SUBMITTED_FOR_REVIEW".equalsIgnoreCase(st)) stBadge = "badge-purple";
                                %>
                                        <tr>
                                            <td><strong>#<%= tk.getId() %></strong></td>
                                            <td><strong><%= tk.getTitle() %></strong></td>
                                            <td style="font-family: 'JetBrains Mono', monospace;"><%= (tk.getEndDate() != null ? tk.getEndDate() : "--") %></td>
                                            <td><span class="badge badge-gray"><%= (tk.getExtra() != null ? tk.getExtra() : "NORMAL") %></span></td>
                                            <td><span class="badge <%= stBadge %>"><%= st %></span></td>
                                            <td>
                                                <% if (rVal > 0) { %>
                                                    <div class="rating-stars"><%= "★".repeat(rVal) + "☆".repeat(5 - rVal) %> (<%= rVal %>/5)</div>
                                                <% } else { %>
                                                    <span style="color: var(--slate-400); font-size: 11px;">Not rated</span>
                                                <% } %>
                                                <% if (fb != null && !fb.isBlank()) { %>
                                                    <div class="feedback-pill"><%= fb %></div>
                                                <% } %>
                                            </td>
                                        </tr>
                                <%  } 
                                   } else { %>
                                    <tr><td colspan="6" style="text-align: center; color: var(--slate-400); padding: 36px;">No task deliverables assigned for this date range.</td></tr>
                                <% } %>
                            </tbody>
                        <% } %>
                    </table>
                </div>

            </div>
    <%  } 
       } %>

</div>

<script>
function filterDirectory(itemClass, inputId) {
    var query = document.getElementById(inputId).value.toLowerCase().trim();
    var items = document.querySelectorAll('.' + itemClass);
    items.forEach(function(item) {
        var text = item.innerText.toLowerCase();
        if (query === '' || text.includes(query)) {
            item.style.display = 'flex';
        } else {
            item.style.display = 'none';
        }
    });
}

function exportTableToCSV(filename) {
    var table = document.getElementById("drillReportTable");
    if (!table) return;

    var csv = [];
    var rows = table.querySelectorAll("tr");

    for (var i = 0; i < rows.length; i++) {
        var row = [];
        var cols = rows[i].querySelectorAll("td, th");
        for (var j = 0; j < cols.length; j++) {
            var cellText = cols[j].innerText.replace(/"/g, '""').trim();
            row.push('"' + cellText + '"');
        }
        csv.push(row.join(","));
    }

    var csvBlob = new Blob([csv.join("\n")], { type: "text/csv;charset=utf-8;" });
    var link = document.createElement("a");
    link.href = URL.createObjectURL(csvBlob);
    link.setAttribute("download", filename);
    link.style.display = "none";
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
}
</script>

</body>
</html>