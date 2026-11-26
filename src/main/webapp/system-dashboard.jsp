<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.util.List, java.util.ArrayList, java.util.Map, java.sql.*" %>
<%@ page import="com.example.demo.model.AuditLog" %>
<%@ page import="com.example.demo.model.LoginHistory" %>
<%@ page import="com.example.demo.model.SystemError" %>
<%@ page import="com.dao.AuditLogDAO" %>
<%@ page import="com.dao.SystemErrorDAO" %>
<%@ page import="com.dao.SystemSettingsDAO" %>
<%@ page import="com.Util.DBConnection" %>

<%
// 1. Session Role Verification (Supports Employee bean, role string, or userRole)
    String userRole = null;
    String userDisplayName = "Administrator";
    if (session != null) {
        if (session.getAttribute("role") != null) {
            userRole = session.getAttribute("role").toString();
        } else if (session.getAttribute("userRole") != null) {
            userRole = session.getAttribute("userRole").toString();
        } else if (session.getAttribute("loggedInEmployee") != null) {
            com.example.demo.model.Employee emp = (com.example.demo.model.Employee) session.getAttribute("loggedInEmployee");
            userRole = emp.getRole();
            if (emp.getName() != null) userDisplayName = emp.getName();
        } else if (session.getAttribute("employee") != null) {
            com.example.demo.model.Employee emp = (com.example.demo.model.Employee) session.getAttribute("employee");
            userRole = emp.getRole();
            if (emp.getName() != null) userDisplayName = emp.getName();
        }
    }

    boolean isAdmin = userRole != null && (
        userRole.equalsIgnoreCase("ADMIN") || 
        userRole.equalsIgnoreCase("SUPER ADMIN") || 
        userRole.equalsIgnoreCase("HR")
    );

    if (!isAdmin) {
        response.sendError(HttpServletResponse.SC_FORBIDDEN, "Access Denied: Administrator authority required.");
        return;
    }

    // 2. Headcount & Metrics Aggregation
    int totalUsers = 0, activeUsers = 0, inactiveUsers = 0;
    try {
        SystemSettingsDAO settingsDAO = new SystemSettingsDAO();
        Map<String, Object> userMetrics = settingsDAO.getUserMonitoringMetrics();
        if (userMetrics != null) {
            if (userMetrics.get("totalUsers") != null) totalUsers = (Integer) userMetrics.get("totalUsers");
            if (userMetrics.get("activeUsers") != null) activeUsers = (Integer) userMetrics.get("activeUsers");
            if (userMetrics.get("inactiveUsers") != null) inactiveUsers = (Integer) userMetrics.get("inactiveUsers");
        }
    } catch (Exception ignored) {}

    // 3. Direct SQL for Login Stream (Eliminates getFilteredLoginHistory method errors)
    List<LoginHistory> recentLogins = new ArrayList<>();
    int totalAuditRecords = 0;
    int todayLogins = 0;
    int todayFailedLogins = 0;
    String latestBackupStatus = "NONE";
    String latestBackupTime = "No snapshots found";

    try (Connection conn = DBConnection.getConnection()) {
        // Recent 5 Logins
        try (PreparedStatement ps = conn.prepareStatement(
                "SELECT id, user_id, email, activity_type, ip_address, user_agent, created_at " +
                "FROM login_history ORDER BY id DESC LIMIT 5");
             ResultSet rs = ps.executeQuery()) {
        	while (rs.next()) {
                LoginHistory lh = new LoginHistory();
                lh.setUserId(rs.getInt("user_id"));
                lh.setEmail(rs.getString("email"));
                lh.setActivityType(rs.getString("activity_type"));
                lh.setIpAddress(rs.getString("ip_address"));
                lh.setUserAgent(rs.getString("user_agent"));
                lh.setCreatedAt(rs.getTimestamp("created_at"));
                recentLogins.add(lh);
            }
        } catch (Exception ignored) {}

        // Total Audits
        try (PreparedStatement ps = conn.prepareStatement("SELECT COUNT(*) FROM audit_logs");
             ResultSet rs = ps.executeQuery()) {
            if (rs.next()) totalAuditRecords = rs.getInt(1);
        } catch (Exception ignored) {}

        // Today's Successful vs Failed Logins
        try (PreparedStatement ps = conn.prepareStatement(
                "SELECT " +
                " SUM(CASE WHEN activity_type = 'LOGIN' THEN 1 ELSE 0 END) AS success_today, " +
                " SUM(CASE WHEN activity_type = 'FAILED_LOGIN' THEN 1 ELSE 0 END) AS failed_today " +
                "FROM login_history WHERE DATE(created_at) = CURRENT_DATE");
             ResultSet rs = ps.executeQuery()) {
            if (rs.next()) {
                todayLogins = rs.getInt("success_today");
                todayFailedLogins = rs.getInt("failed_today");
            }
        } catch (Exception ignored) {}

        // Latest Database Snapshot Status
        try (PreparedStatement ps = conn.prepareStatement(
                "SELECT status, created_at FROM backup_history ORDER BY id DESC LIMIT 1");
             ResultSet rs = ps.executeQuery()) {
            if (rs.next()) {
                latestBackupStatus = rs.getString("status");
                Timestamp ts = rs.getTimestamp("created_at");
                if (ts != null) latestBackupTime = ts.toString();
            }
        } catch (Exception ignored) {}
    } catch (Exception e) {
        e.printStackTrace();
    }

    // 4. Audits & Errors Feeds
    List<AuditLog> recentAudits = new ArrayList<>();
    try {
        AuditLogDAO auditDAO = new AuditLogDAO();
        recentAudits = auditDAO.getAllAuditLogs(5, 0);
    } catch (Exception ignored) {}

    List<SystemError> recentErrors = new ArrayList<>();
    try {
        SystemErrorDAO errorDAO = new SystemErrorDAO();
        recentErrors = errorDAO.getFilteredErrors(null, null, 5);
    } catch (Exception ignored) {}
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>System &amp; Security Control Center</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@500;600&display=swap" rel="stylesheet">
    <style>
        :root {
            --primary: #4f46e5;
            --primary-hover: #4338ca;
            --primary-light: #eef2ff;
            --surface: #ffffff;
            --background: #f8fafc;
            --border: #e2e8f0;
            --border-hover: #cbd5e1;
            --text-heading: #0f172a;
            --text-body: #334155;
            --text-muted: #64748b;
            --success: #10b981;
            --success-light: #ecfdf5;
            --danger: #ef4444;
            --danger-light: #fef2f2;
            --warning: #f59e0b;
            --warning-light: #fffbeb;
            --radius-sm: 8px;
            --radius-md: 12px;
            --radius-lg: 16px;
            --shadow-subtle: 0 1px 3px 0 rgba(0, 0, 0, 0.05), 0 1px 2px -1px rgba(0, 0, 0, 0.05);
            --shadow-card: 0 4px 6px -1px rgba(0, 0, 0, 0.04), 0 2px 4px -2px rgba(0, 0, 0, 0.04);
            --shadow-float: 0 10px 15px -3px rgba(0, 0, 0, 0.05), 0 4px 6px -4px rgba(0, 0, 0, 0.03);
        }

        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background-color: var(--background);
            color: var(--text-body);
            line-height: 1.5;
            padding: 32px 24px;
            -webkit-font-smoothing: antialiased;
        }

        .container {
            max-width: 1440px;
            margin: 0 auto;
            display: flex;
            flex-direction: column;
            gap: 24px;
        }

        /* Top Hero Header Bar */
        .top-navbar {
            background: var(--surface);
            border-radius: var(--radius-lg);
            border: 1px solid var(--border);
            padding: 20px 28px;
            box-shadow: var(--shadow-card);
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 16px;
            position: relative;
            overflow: hidden;
        }
        .top-navbar::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 4px;
            background: linear-gradient(90deg, #4f46e5, #06b6d4, #10b981);
        }
        .header-title h1 {
            font-size: 22px;
            font-weight: 800;
            color: var(--text-heading);
            letter-spacing: -0.02em;
        }
        .header-title p {
            font-size: 13px;
            color: var(--text-muted);
            margin-top: 2px;
        }

        /* Navigation Pills */
        .nav-tabs {
            display: flex;
            gap: 6px;
            flex-wrap: wrap;
            background: #f1f5f9;
            padding: 6px;
            border-radius: var(--radius-md);
        }
        .nav-link {
            text-decoration: none;
            font-size: 13px;
            font-weight: 600;
            padding: 8px 16px;
            border-radius: var(--radius-sm);
            color: var(--text-muted);
            transition: all 0.18s ease-in-out;
            display: inline-flex;
            align-items: center;
            gap: 6px;
        }
        .nav-link:hover {
            color: var(--primary);
            background: rgba(255, 255, 255, 0.7);
        }
        .nav-link.active {
            background: var(--surface);
            color: var(--primary);
            box-shadow: var(--shadow-subtle);
        }
        .nav-link.back-btn {
            background: transparent;
            color: var(--text-heading);
            border: 1px solid var(--border);
        }
        .nav-link.back-btn:hover {
            background: var(--surface);
        }

        /* Metric Cards Grid */
        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
            gap: 18px;
        }
        .metric-card {
            background: var(--surface);
            padding: 22px;
            border-radius: var(--radius-md);
            border: 1px solid var(--border);
            box-shadow: var(--shadow-card);
            position: relative;
            transition: transform 0.2s ease, box-shadow 0.2s ease;
        }
        .metric-card:hover {
            transform: translateY(-2px);
            box-shadow: var(--shadow-float);
            border-color: var(--border-hover);
        }
        .metric-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 12px;
        }
        .metric-label {
            font-size: 12px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: var(--text-muted);
        }
        .metric-icon-box {
            width: 32px;
            height: 32px;
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 15px;
        }
        .metric-value {
            font-size: 32px;
            font-weight: 800;
            letter-spacing: -0.03em;
            color: var(--text-heading);
            line-height: 1.1;
        }
        .metric-footer {
            margin-top: 10px;
            font-size: 12.5px;
            color: var(--text-muted);
            display: flex;
            align-items: center;
            gap: 6px;
        }

        /* Panels Grid */
        .feed-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 24px;
        }
        @media (max-width: 1080px) {
            .feed-grid { grid-template-columns: 1fr; }
        }

        .panel {
            background: var(--surface);
            border-radius: var(--radius-md);
            border: 1px solid var(--border);
            padding: 24px;
            box-shadow: var(--shadow-card);
            display: flex;
            flex-direction: column;
        }
        .panel-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 18px;
            padding-bottom: 14px;
            border-bottom: 1px solid #f1f5f9;
        }
        .panel-header h3 {
            font-size: 16px;
            font-weight: 700;
            color: var(--text-heading);
            letter-spacing: -0.01em;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        .panel-header a {
            font-size: 12.5px;
            color: var(--primary);
            text-decoration: none;
            font-weight: 600;
            padding: 4px 10px;
            border-radius: var(--radius-sm);
            background: var(--primary-light);
            transition: all 0.15s ease;
        }
        .panel-header a:hover {
            background: #e0e7ff;
            color: var(--primary-hover);
        }

        /* Modern Data Tables */
        .table-responsive {
            width: 100%;
            overflow-x: auto;
        }
        table {
            width: 100%;
            border-collapse: separate;
            border-spacing: 0;
            font-size: 13px;
        }
        th {
            background: #f8fafc;
            padding: 10px 14px;
            text-align: left;
            font-weight: 600;
            color: var(--text-muted);
            font-size: 11.5px;
            text-transform: uppercase;
            letter-spacing: 0.04em;
            border-bottom: 1px solid var(--border);
        }
        th:first-child { border-top-left-radius: var(--radius-sm); }
        th:last-child { border-top-right-radius: var(--radius-sm); }
        td {
            padding: 13px 14px;
            border-bottom: 1px solid #f1f5f9;
            color: var(--text-body);
            vertical-align: middle;
        }
        tr:last-child td { border-bottom: none; }
        tr:hover td { background-color: #fafbfd; }

        /* Badges & Monospace Code */
        .badge {
            display: inline-flex;
            align-items: center;
            gap: 4px;
            padding: 3px 9px;
            border-radius: 9999px;
            font-size: 11px;
            font-weight: 700;
            letter-spacing: 0.02em;
        }
        .badge-success { background: var(--success-light); color: var(--success); }
        .badge-danger { background: var(--danger-light); color: var(--danger); }
        .badge-info { background: #f0fdf4; color: #0284c7; }
        .badge-neutral { background: #f1f5f9; color: #475569; }

        code {
            font-family: 'JetBrains Mono', monospace;
            background: #f1f5f9;
            padding: 2px 7px;
            border-radius: 4px;
            font-size: 11.5px;
            color: #334155;
            font-weight: 500;
            border: 1px solid #e2e8f0;
        }

        /* Action Cards on Panel 4 */
        .action-link-card {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 14px 18px;
            background: #f8fafc;
            border: 1px solid var(--border);
            border-radius: var(--radius-md);
            text-decoration: none;
            color: var(--text-heading);
            font-weight: 600;
            font-size: 13.5px;
            transition: all 0.2s ease;
            margin-bottom: 10px;
        }
        .action-link-card:last-child { margin-bottom: 0; }
        .action-link-card:hover {
            border-color: var(--primary);
            background: #ffffff;
            transform: translateX(3px);
            box-shadow: var(--shadow-subtle);
        }
        .action-arrow {
            color: var(--primary);
            font-size: 15px;
            font-weight: 700;
        }
    </style>
</head>
<body>
    <div class="container">
        
        <!-- Header & Nav Bar -->
        <header class="top-navbar">
            <div class="header-title">
                <h1>System Security &amp; Audit Command Center</h1>
                <p>Welcome, <b><%= userDisplayName %></b> &bull; Real-time infrastructure health and transactional oversight</p>
            </div>
            <nav class="nav-tabs">
                <a href="<%= request.getContextPath() %>/dashboard.jsp" class="nav-link back-btn">&larr; Main Workspace</a>
                <a href="<%= request.getContextPath() %>/system-dashboard.jsp" class="nav-link active">&#9670; Dashboard</a>
                <a href="<%= request.getContextPath() %>/auditlogs.jsp" class="nav-link">Audit Trail</a>
                <a href="<%= request.getContextPath() %>/login-history.jsp" class="nav-link">Login History</a>
                <a href="<%= request.getContextPath() %>/system-settings.jsp" class="nav-link">Settings</a>
                <a href="<%= request.getContextPath() %>/system-errors.jsp" class="nav-link">Exceptions</a>
                <a href="<%= request.getContextPath() %>/backup-management.jsp" class="nav-link">Backups</a>
            </nav>
        </header>

        <!-- KPI Statistic Metric Cards -->
        <section class="metrics-grid">
            <!-- 1. Total Registered -->
            <div class="metric-card">
                <div class="metric-header">
                    <span class="metric-label">Employee Base</span>
                    <div class="metric-icon-box" style="background:#eff6ff; color:#2563eb;">&#128101;</div>
                </div>
                <div class="metric-value"><%= totalUsers %></div>
                <div class="metric-footer">
                    <span style="color: var(--success); font-weight:700;">&#9679; <%= activeUsers %> Active</span>
                    <span style="color: #94a3b8;">&bull;</span>
                    <span style="color: var(--danger); font-weight:600;"><%= inactiveUsers %> Inactive</span>
                </div>
            </div>

            <!-- 2. Audit Trail Logs -->
            <div class="metric-card">
                <div class="metric-header">
                    <span class="metric-label">Audit Log Count</span>
                    <div class="metric-icon-box" style="background:#f5f3ff; color:#7c3aed;">&#128221;</div>
                </div>
                <div class="metric-value"><%= totalAuditRecords %></div>
                <div class="metric-footer">
                    <span>Immutable transaction traces</span>
                </div>
            </div>

            <!-- 3. Successful Sessions Today -->
            <div class="metric-card">
                <div class="metric-header">
                    <span class="metric-label">Authenticated Today</span>
                    <div class="metric-icon-box" style="background:var(--success-light); color:var(--success);">&#10003;</div>
                </div>
                <div class="metric-value" style="color: var(--success);"><%= todayLogins %></div>
                <div class="metric-footer">
                    <span>Successful user sessions</span>
                </div>
            </div>

            <!-- 4. Security Failures Today -->
            <div class="metric-card">
                <div class="metric-header">
                    <span class="metric-label">Access Violations</span>
                    <div class="metric-icon-box" style="background:var(--danger-light); color:var(--danger);">&#9888;</div>
                </div>
                <div class="metric-value" style="color: var(--danger);"><%= todayFailedLogins %></div>
                <div class="metric-footer">
                    <span style="color: var(--danger); font-weight:600;">Failed authentication attempts</span>
                </div>
            </div>

            <!-- 5. Snapshot Engine -->
            <div class="metric-card">
                <div class="metric-header">
                    <span class="metric-label">Database Backup</span>
                    <div class="metric-icon-box" style="background:#f1f5f9; color:#475569;">&#128190;</div>
                </div>
                <div style="margin: 6px 0 2px 0;">
                    <% if ("SUCCESS".equalsIgnoreCase(latestBackupStatus)) { %>
                        <span class="badge badge-success" style="font-size:12px; padding: 4px 10px;">&#10004; <%= latestBackupStatus %></span>
                    <% } else { %>
                        <span class="badge badge-danger" style="font-size:12px; padding: 4px 10px;">&#9888; <%= latestBackupStatus %></span>
                    <% } %>
                </div>
                <div class="metric-footer" style="font-size: 11.5px; color: var(--text-muted); margin-top: 14px;">
                    <%= latestBackupTime %>
                </div>
            </div>
        </section>

        <!-- Live Feeds & Operational Panels -->
        <main class="feed-grid">
            
            <!-- Feed 1: Audit Activity -->
            <div class="panel">
                <div class="panel-header">
                    <h3>&#128269; Recent Administrative Changes</h3>
                    <a href="<%= request.getContextPath() %>/auditlogs.jsp">View All &rarr;</a>
                </div>
                <div class="table-responsive">
                    <table>
                        <thead>
                            <tr>
                                <th>Timestamp</th>
                                <th>Module</th>
                                <th>Action</th>
                                <th>Record ID</th>
                            </tr>
                        </thead>
                        <tbody>
                            <%
                                if (recentAudits != null && !recentAudits.isEmpty()) {
                                    for (AuditLog a : recentAudits) {
                            %>
                                <tr>
                                    <td style="color: var(--text-muted); font-size: 12px;"><%= a.getCreatedAt() != null ? a.getCreatedAt() : "-" %></td>
                                    <td><b><%= a.getModuleName() != null ? a.getModuleName() : "-" %></b></td>
                                    <td><span class="badge badge-info"><%= a.getActionType() != null ? a.getActionType() : "LOG" %></span></td>
                                    <td><code><%= a.getRecordId() != null ? a.getRecordId() : "-" %></code></td>
                                </tr>
                            <%
                                    }
                                } else {
                            %>
                                <tr><td colspan="4" style="text-align:center; color: var(--text-muted); padding: 24px;">No audit logs currently recorded.</td></tr>
                            <% } %>
                        </tbody>
                    </table>
                </div>
            </div>

            <!-- Feed 2: Live Authentication Stream -->
            <div class="panel">
                <div class="panel-header">
                    <h3>&#128272; Live Authentication Feed</h3>
                    <a href="<%= request.getContextPath() %>/login-history.jsp">Security Logs &rarr;</a>
                </div>
                <div class="table-responsive">
                    <table>
                        <thead>
                            <tr>
                                <th>Timestamp</th>
                                <th>User / Email</th>
                                <th>Status</th>
                                <th>Remote IP</th>
                            </tr>
                        </thead>
                        <tbody>
                            <%
                                if (recentLogins != null && !recentLogins.isEmpty()) {
                                    for (LoginHistory l : recentLogins) {
                                        String act = l.getActivityType() != null ? l.getActivityType() : "";
                            %>
                                <tr>
                                    <td style="color: var(--text-muted); font-size: 12px;"><%= l.getCreatedAt() != null ? l.getCreatedAt() : "-" %></td>
                                    <td><b><%= l.getEmail() != null ? l.getEmail() : "-" %></b></td>
                                    <td>
                                        <% if ("LOGIN".equalsIgnoreCase(act)) { %>
                                            <span class="badge badge-success">&#10003; LOGIN</span>
                                        <% } else if ("LOGOUT".equalsIgnoreCase(act)) { %>
                                            <span class="badge badge-neutral">LOGOUT</span>
                                        <% } else { %>
                                            <span class="badge badge-danger">&#9888; FAILED</span>
                                        <% } %>
                                    </td>
                                    <td><code><%= l.getIpAddress() != null ? l.getIpAddress() : "0.0.0.0" %></code></td>
                                </tr>
                            <%
                                    }
                                } else {
                            %>
                                <tr><td colspan="4" style="text-align:center; color: var(--text-muted); padding: 24px;">No login sessions recorded yet.</td></tr>
                            <% } %>
                        </tbody>
                    </table>
                </div>
            </div>

            <!-- Feed 3: Application Exceptions -->
            <div class="panel">
                <div class="panel-header">
                    <h3>&#9888; Application Exception Triage</h3>
                    <a href="<%= request.getContextPath() %>/system-errors.jsp">Diagnostics &rarr;</a>
                </div>
                <div class="table-responsive">
                    <table>
                        <thead>
                            <tr>
                                <th>Timestamp</th>
                                <th>Origin Module</th>
                                <th>Severity</th>
                                <th>Exception Message</th>
                            </tr>
                        </thead>
                        <tbody>
                            <%
                                if (recentErrors != null && !recentErrors.isEmpty()) {
                                    for (SystemError e : recentErrors) {
                                        String sev = e.getSeverity() != null ? e.getSeverity() : "LOW";
                            %>
                                <tr>
                                    <td style="color: var(--text-muted); font-size: 12px;"><%= e.getCreatedAt() != null ? e.getCreatedAt() : "-" %></td>
                                    <td><b><%= e.getModuleName() != null ? e.getModuleName() : "-" %></b></td>
                                    <td><span class="badge <%= "CRITICAL".equalsIgnoreCase(sev) || "HIGH".equalsIgnoreCase(sev) ? "badge-danger" : "badge-neutral" %>"><%= sev %></span></td>
                                    <td style="max-width: 200px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;" title="<%= e.getErrorMessage() %>">
                                        <%= e.getErrorMessage() != null ? e.getErrorMessage() : "-" %>
                                    </td>
                                </tr>
                            <%
                                    }
                                } else {
                            %>
                                <tr><td colspan="4" style="text-align:center; color: var(--success); font-weight:600; padding: 24px;">&#10004; Zero exceptions recorded. System fully healthy.</td></tr>
                            <% } %>
                        </tbody>
                    </table>
                </div>
            </div>

            <!-- Feed 4: Quick Action Command Center -->
            <div class="panel">
                <div class="panel-header">
                    <h3>&#9881; Administrative Shortcuts</h3>
                    <a href="<%= request.getContextPath() %>/system-settings.jsp">Parameters &rarr;</a>
                </div>
                <div style="display: flex; flex-direction: column; gap: 8px; justify-content: center; height: 100%;">
                    <a href="<%= request.getContextPath() %>/backup-management.jsp" class="action-link-card">
                        <div>
                            <div style="font-weight: 700; color: var(--text-heading);">&#128190; Generate Database Snapshot</div>
                            <div style="font-size: 12px; color: var(--text-muted); font-weight: 400;">Execute an immediate compressed point-in-time SQL dump</div>
                        </div>
                        <span class="action-arrow">&rarr;</span>
                    </a>

                    <a href="<%= request.getContextPath() %>/system-settings.jsp" class="action-link-card">
                        <div>
                            <div style="font-weight: 700; color: var(--text-heading);">&#9881; Global System Variables</div>
                            <div style="font-size: 12px; color: var(--text-muted); font-weight: 400;">Manage password policies, session timeouts, and maintenance modes</div>
                        </div>
                        <span class="action-arrow">&rarr;</span>
                    </a>

                    <a href="<%= request.getContextPath() %>/login-history.jsp?activityType=FAILED_LOGIN" class="action-link-card">
                        <div>
                            <div style="font-weight: 700; color: var(--danger);">&#128680; Inspect Failed Login Attempts</div>
                            <div style="font-size: 12px; color: var(--text-muted); font-weight: 400;">Check suspicious IP addresses and repeated credential rejections</div>
                        </div>
                        <span class="action-arrow" style="color: var(--danger);">&rarr;</span>
                    </a>
                </div>
            </div>

        </main>
    </div>
</body>
</html>