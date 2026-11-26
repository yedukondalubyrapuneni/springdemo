<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.util.List, java.util.ArrayList, java.sql.*" %>
<%@ page import="com.example.demo.model.LoginHistory" %>
<%@ page import="com.Util.DBConnection" %>

<%
// 1. Unified Session Role Verification
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
        response.sendError(HttpServletResponse.SC_FORBIDDEN, "Access Denied: Only administrators can view login logs.");
        return;
    }

    // 2. Filter Parameters & Pagination Logic
    String selectedEmail = request.getParameter("email");
    if (selectedEmail == null) selectedEmail = "";
    
    String selectedActivity = request.getParameter("activityType");
    if (selectedActivity == null) selectedActivity = "";

    int currentPage = 1;
    try {
        if (request.getParameter("page") != null) {
            currentPage = Integer.parseInt(request.getParameter("page"));
        }
    } catch (NumberFormatException ignored) {}

    int pageSize = 15;
    int offset = (currentPage - 1) * pageSize;

    // 3. Database Query & KPI Metrics
    List<LoginHistory> historyList = new ArrayList<>();
    int totalFilteredRecords = 0;
    int successCountToday = 0;
    int failedCountToday = 0;

    StringBuilder countSql = new StringBuilder("SELECT COUNT(*) FROM login_history WHERE 1=1 ");
    StringBuilder sql = new StringBuilder("SELECT id, user_id, email, activity_type, ip_address, user_agent, created_at FROM login_history WHERE 1=1 ");
    List<Object> params = new ArrayList<>();

    if (!selectedEmail.trim().isEmpty()) {
        String emailPattern = "%" + selectedEmail.trim() + "%";
        countSql.append(" AND email LIKE ? ");
        sql.append(" AND email LIKE ? ");
        params.add(emailPattern);
    }
    if (!selectedActivity.trim().isEmpty()) {
        countSql.append(" AND activity_type = ? ");
        sql.append(" AND activity_type = ? ");
        params.add(selectedActivity.trim());
    }

    sql.append(" ORDER BY id DESC LIMIT ? OFFSET ? ");

    try (Connection conn = DBConnection.getConnection()) {
        // Daily Quick Stats
        try (PreparedStatement ps = conn.prepareStatement(
                "SELECT " +
                " SUM(CASE WHEN activity_type = 'LOGIN' THEN 1 ELSE 0 END) AS success_today, " +
                " SUM(CASE WHEN activity_type = 'FAILED_LOGIN' THEN 1 ELSE 0 END) AS failed_today " +
                "FROM login_history WHERE DATE(created_at) = CURRENT_DATE");
             ResultSet rs = ps.executeQuery()) {
            if (rs.next()) {
                successCountToday = rs.getInt("success_today");
                failedCountToday = rs.getInt("failed_today");
            }
        } catch (Exception ignored) {}

        // Total Matching Records
        try (PreparedStatement ps = conn.prepareStatement(countSql.toString())) {
            for (int i = 0; i < params.size(); i++) {
                ps.setObject(i + 1, params.get(i));
            }
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) totalFilteredRecords = rs.getInt(1);
            }
        } catch (Exception ignored) {}

        // Paginated List
        try (PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            int pIndex = 1;
            for (Object param : params) {
                ps.setObject(pIndex++, param);
            }
            ps.setInt(pIndex++, pageSize);
            ps.setInt(pIndex, offset);

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    LoginHistory lh = new LoginHistory();
                    lh.setUserId(rs.getInt("user_id"));
                    lh.setEmail(rs.getString("email"));
                    lh.setActivityType(rs.getString("activity_type"));
                    lh.setIpAddress(rs.getString("ip_address"));
                    lh.setUserAgent(rs.getString("user_agent"));
                    lh.setCreatedAt(rs.getTimestamp("created_at"));
                    historyList.add(lh);
                }
            }
        }
    } catch (Exception e) {
        System.err.println("Error reading login history: " + e.getMessage());
    }

    int totalPages = (int) Math.ceil((double) totalFilteredRecords / pageSize);
    if (totalPages == 0) totalPages = 1;
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Authentication Logs &amp; Security History</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600&display=swap" rel="stylesheet">
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

        /* Mini Quick Stats */
        .stats-strip {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 16px;
        }
        .stat-card {
            background: var(--surface);
            padding: 16px 20px;
            border-radius: var(--radius-md);
            border: 1px solid var(--border);
            box-shadow: var(--shadow-subtle);
            display: flex;
            align-items: center;
            justify-content: space-between;
        }
        .stat-label {
            font-size: 11.5px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.04em;
            color: var(--text-muted);
        }
        .stat-num {
            font-size: 22px;
            font-weight: 800;
            color: var(--text-heading);
            margin-top: 2px;
        }

        /* Filter Toolbar */
        .card-main {
            background: var(--surface);
            border-radius: var(--radius-md);
            border: 1px solid var(--border);
            padding: 24px;
            box-shadow: var(--shadow-card);
        }
        .filter-form {
            display: flex;
            gap: 12px;
            flex-wrap: wrap;
            align-items: center;
            background: #f8fafc;
            padding: 14px 18px;
            border-radius: var(--radius-md);
            border: 1px solid var(--border);
            margin-bottom: 20px;
        }
        .input-group {
            display: flex;
            align-items: center;
            background: #ffffff;
            border: 1px solid var(--border);
            border-radius: var(--radius-sm);
            padding: 0 12px;
            transition: border-color 0.15s;
        }
        .input-group:focus-within {
            border-color: var(--primary);
            box-shadow: 0 0 0 3px rgba(79, 70, 229, 0.1);
        }
        .input-group input {
            border: none;
            outline: none;
            padding: 9px 8px;
            font-size: 13px;
            font-family: inherit;
            min-width: 260px;
            color: var(--text-body);
        }
        .select-group select {
            padding: 9px 14px;
            border: 1px solid var(--border);
            border-radius: var(--radius-sm);
            background: #ffffff;
            font-size: 13px;
            font-family: inherit;
            color: var(--text-body);
            outline: none;
            cursor: pointer;
        }
        .select-group select:focus {
            border-color: var(--primary);
        }
        .btn-submit {
            background: var(--primary);
            color: #ffffff;
            border: none;
            padding: 9px 18px;
            border-radius: var(--radius-sm);
            font-size: 13px;
            font-weight: 700;
            cursor: pointer;
            transition: background 0.15s ease;
        }
        .btn-submit:hover { background: var(--primary-hover); }
        .btn-reset {
            text-decoration: none;
            color: var(--text-muted);
            background: #ffffff;
            border: 1px solid var(--border);
            padding: 9px 14px;
            border-radius: var(--radius-sm);
            font-size: 13px;
            font-weight: 600;
            transition: all 0.15s ease;
        }
        .btn-reset:hover {
            color: var(--text-heading);
            background: #f1f5f9;
        }

        /* Table */
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
            padding: 12px 16px;
            text-align: left;
            font-weight: 700;
            color: var(--text-muted);
            font-size: 11px;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            border-bottom: 1px solid var(--border);
        }
        th:first-child { border-top-left-radius: var(--radius-sm); }
        th:last-child { border-top-right-radius: var(--radius-sm); }
        td {
            padding: 14px 16px;
            border-bottom: 1px solid #f1f5f9;
            color: var(--text-body);
            vertical-align: middle;
        }
        tr:last-child td { border-bottom: none; }
        tr:hover td { background-color: #fafbfd; }

        /* Badges */
        .badge {
            display: inline-flex;
            align-items: center;
            gap: 5px;
            padding: 4px 10px;
            border-radius: 9999px;
            font-size: 11px;
            font-weight: 700;
            letter-spacing: 0.02em;
        }
        .badge-login { background: var(--success-light); color: var(--success); border: 1px solid #a7f3d0; }
        .badge-logout { background: #f1f5f9; color: #475569; border: 1px solid var(--border); }
        .badge-failed { background: var(--danger-light); color: var(--danger); border: 1px solid #fecaca; }

        code {
            font-family: 'JetBrains Mono', monospace;
            background: #f1f5f9;
            padding: 3px 8px;
            border-radius: 6px;
            font-size: 12px;
            color: #334155;
            font-weight: 500;
            border: 1px solid #e2e8f0;
        }

        /* Pagination Footer */
        .pagination-container {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-top: 24px;
            padding-top: 18px;
            border-top: 1px solid #f1f5f9;
            flex-wrap: wrap;
            gap: 12px;
        }
        .page-meta {
            font-size: 13px;
            color: var(--text-muted);
        }
        .page-controls {
            display: flex;
            gap: 6px;
            align-items: center;
        }
        .page-btn {
            text-decoration: none;
            padding: 7px 14px;
            border: 1px solid var(--border);
            border-radius: var(--radius-sm);
            background: #ffffff;
            color: var(--text-heading);
            font-size: 12.5px;
            font-weight: 600;
            transition: all 0.15s ease;
        }
        .page-btn:hover:not(.disabled) {
            background: #f8fafc;
            border-color: var(--border-hover);
        }
        .page-btn.disabled {
            opacity: 0.4;
            pointer-events: none;
            background: #f1f5f9;
        }
    </style>
</head>
<body>
    <div class="container">
        
        <!-- Header -->
        <header class="top-navbar">
            <div class="header-title">
                <h1>Authentication Logs &amp; Security Auditing</h1>
                <p>Welcome, <b><%= userDisplayName %></b> &bull; Track identity validation, session lifecycles, and brute-force indicators</p>
            </div>
            <nav class="nav-tabs">
                <a href="<%= request.getContextPath() %>/dashboard.jsp" class="nav-link back-btn">&larr; Workspace</a>
                <a href="<%= request.getContextPath() %>/system-dashboard.jsp" class="nav-link">Dashboard</a>
                <a href="<%= request.getContextPath() %>/auditlogs.jsp" class="nav-link">Audit Trail</a>
                <a href="<%= request.getContextPath() %>/login-history.jsp" class="nav-link active">Login History</a>
                <a href="<%= request.getContextPath() %>/system-settings.jsp" class="nav-link">Settings</a>
                <a href="<%= request.getContextPath() %>/system-errors.jsp" class="nav-link">Exceptions</a>
                <a href="<%= request.getContextPath() %>/backup-management.jsp" class="nav-link">Backups</a>
            </nav>
        </header>

        <!-- Stats Strip -->
        <section class="stats-strip">
            <div class="stat-card">
                <div>
                    <div class="stat-label">Matching Logs</div>
                    <div class="stat-num"><%= totalFilteredRecords %></div>
                </div>
                <div style="font-size: 24px;">&#128220;</div>
            </div>
            <div class="stat-card">
                <div>
                    <div class="stat-label">Successful Today</div>
                    <div class="stat-num" style="color: var(--success);"><%= successCountToday %></div>
                </div>
                <div style="font-size: 24px; color: var(--success);">&#10003;</div>
            </div>
            <div class="stat-card">
                <div>
                    <div class="stat-label">Security Violations Today</div>
                    <div class="stat-num" style="color: var(--danger);"><%= failedCountToday %></div>
                </div>
                <div style="font-size: 24px; color: var(--danger);">&#9888;</div>
            </div>
        </section>

        <!-- Main Card -->
        <main class="card-main">
            <!-- Filter Toolbar -->
            <form method="get" action="<%= request.getContextPath() %>/login-history.jsp" class="filter-form">
                <div class="input-group">
                    <span style="color: var(--text-muted); margin-right: 6px;">&#128269;</span>
                    <input type="text" name="email" placeholder="Search by email address..." value="<%= selectedEmail %>">
                </div>

                <div class="select-group">
                    <select name="activityType">
                        <option value="">All Event Types</option>
                        <option value="LOGIN" <%= "LOGIN".equals(selectedActivity) ? "selected" : "" %>>Successful Login</option>
                        <option value="LOGOUT" <%= "LOGOUT".equals(selectedActivity) ? "selected" : "" %>>Logout Session</option>
                        <option value="FAILED_LOGIN" <%= "FAILED_LOGIN".equals(selectedActivity) ? "selected" : "" %>>Failed Authentication</option>
                    </select>
                </div>

                <button type="submit" class="btn-submit">Filter Logs</button>
                <a href="<%= request.getContextPath() %>/login-history.jsp" class="btn-reset">Reset</a>
            </form>

            <!-- Table -->
            <div class="table-responsive">
                <table>
                    <thead>
                        <tr>
                            <th style="width: 18%;">Timestamp</th>
                            <th style="width: 8%;">User ID</th>
                            <th style="width: 24%;">Account / Email</th>
                            <th style="width: 15%;">Event Classification</th>
                            <th style="width: 15%;">Client IP</th>
                            <th style="width: 20%;">Device / User Agent</th>
                        </tr>
                    </thead>
                    <tbody>
                        <%
                            if (historyList != null && !historyList.isEmpty()) {
                                for (LoginHistory item : historyList) {
                                    String act = item.getActivityType() != null ? item.getActivityType() : "";
                        %>
                            <tr>
                                <td style="color: var(--text-muted); font-size: 12.5px;">
                                    <%= item.getCreatedAt() != null ? item.getCreatedAt() : "-" %>
                                </td>
                                <td>
                                    <span style="font-weight: 700; color: var(--text-heading);">
                                        <%= item.getUserId() != null && item.getUserId() > 0 ? "#" + item.getUserId() : "-" %>
                                    </span>
                                </td>
                                <td>
                                    <span style="font-weight: 600; color: var(--text-heading);"><%= item.getEmail() %></span>
                                </td>
                                <td>
                                    <% if ("LOGIN".equalsIgnoreCase(act)) { %>
                                        <span class="badge badge-login">&#10003; LOGIN</span>
                                    <% } else if ("LOGOUT".equalsIgnoreCase(act)) { %>
                                        <span class="badge badge-logout">&#8635; LOGOUT</span>
                                    <% } else { %>
                                        <span class="badge badge-failed">&#9888; FAILED LOGIN</span>
                                    <% } %>
                                </td>
                                <td><code><%= item.getIpAddress() != null ? item.getIpAddress() : "0.0.0.0" %></code></td>
                                <td style="max-width: 240px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; color: var(--text-muted); font-size: 12px;" 
                                    title="<%= item.getUserAgent() != null ? item.getUserAgent() : "" %>">
                                    <%= item.getUserAgent() != null ? item.getUserAgent() : "-" %>
                                </td>
                            </tr>
                        <%
                                }
                            } else {
                        %>
                            <tr>
                                <td colspan="6" style="text-align: center; color: var(--text-muted); padding: 42px 0;">
                                    <div style="font-size: 28px; margin-bottom: 8px;">&#128269;</div>
                                    <div style="font-weight: 600;">No login history records found</div>
                                    <div style="font-size: 12.5px; margin-top: 4px;">Try refining your email or activity filters.</div>
                                </td>
                            </tr>
                        <% } %>
                    </tbody>
                </table>
            </div>

            <!-- Pagination Footer -->
            <div class="pagination-container">
                <div class="page-meta">
                    Showing page <b><%= currentPage %></b> of <b><%= totalPages %></b> &bull; Total <b><%= totalFilteredRecords %></b> entries
                </div>
                <div class="page-controls">
                    <%
                        int prevPage = currentPage > 1 ? currentPage - 1 : 1;
                        int nextPage = currentPage + 1;
                        boolean isFirst = currentPage <= 1;
                        boolean isLast = currentPage >= totalPages;
                    %>
                    <a href="<%= request.getContextPath() %>/login-history.jsp?page=<%= prevPage %>&email=<%= selectedEmail %>&activityType=<%= selectedActivity %>" 
                       class="page-btn <%= isFirst ? "disabled" : "" %>">&laquo; Previous</a>
                    
                    <a href="<%= request.getContextPath() %>/login-history.jsp?page=<%= nextPage %>&email=<%= selectedEmail %>&activityType=<%= selectedActivity %>" 
                       class="page-btn <%= isLast ? "disabled" : "" %>">Next &raquo;</a>
                </div>
            </div>
        </main>
    </div>
</body>
</html>