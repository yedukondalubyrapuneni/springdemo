<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.util.List, java.util.ArrayList, java.sql.*" %>
<%@ page import="com.example.demo.model.SystemError" %>
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
        response.sendError(HttpServletResponse.SC_FORBIDDEN, "Access Denied: Only administrators can view error logs.");
        return;
    }

    // 2. Query Filters & Direct JDBC Query
    String selectedModule = request.getParameter("module");
    if (selectedModule == null) selectedModule = "";

    String selectedSeverity = request.getParameter("severity");
    if (selectedSeverity == null) selectedSeverity = "";

    List<SystemError> errorList = new ArrayList<>();
    int criticalCount = 0;
    int highCount = 0;
    int totalCount = 0;

    StringBuilder sql = new StringBuilder("SELECT id, user_id, module_name, error_type, error_message, severity, created_at FROM system_errors WHERE 1=1 ");
    List<Object> params = new ArrayList<>();

    if (!selectedModule.trim().isEmpty()) {
        sql.append(" AND module_name LIKE ? ");
        params.add("%" + selectedModule.trim() + "%");
    }
    if (!selectedSeverity.trim().isEmpty()) {
        sql.append(" AND severity = ? ");
        params.add(selectedSeverity.trim());
    }
    sql.append(" ORDER BY id DESC LIMIT 50 ");

    try (Connection conn = DBConnection.getConnection()) {
        // Quick Severity Count Metrics
        try (PreparedStatement ps = conn.prepareStatement(
                "SELECT " +
                " COUNT(*) AS total_errors, " +
                " SUM(CASE WHEN UPPER(severity) = 'CRITICAL' THEN 1 ELSE 0 END) AS critical_errors, " +
                " SUM(CASE WHEN UPPER(severity) = 'HIGH' THEN 1 ELSE 0 END) AS high_errors " +
                "FROM system_errors");
             ResultSet rs = ps.executeQuery()) {
            if (rs.next()) {
                totalCount = rs.getInt("total_errors");
                criticalCount = rs.getInt("critical_errors");
                highCount = rs.getInt("high_errors");
            }
        } catch (Exception ignored) {}

        // Filtered Error List
        try (PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            for (int i = 0; i < params.size(); i++) {
                ps.setObject(i + 1, params.get(i));
            }
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    SystemError err = new SystemError();
                    err.setUserId(rs.getInt("user_id"));
                    err.setModuleName(rs.getString("module_name"));
                    err.setErrorType(rs.getString("error_type"));
                    err.setErrorMessage(rs.getString("error_message"));
                    err.setSeverity(rs.getString("severity"));
                    err.setCreatedAt(rs.getTimestamp("created_at"));
                    errorList.add(err);
                }
            }
        }
    } catch (Exception e) {
        System.err.println("Error fetching system errors: " + e.getMessage());
    }
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Application Error &amp; Exception Logs - SmartOffice</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600&display=swap" rel="stylesheet">
    <style>
        :root {
            --primary: #4f46e5;
            --primary-hover: #4338ca;
            --surface: #ffffff;
            --background: #f8fafc;
            --border: #e2e8f0;
            --border-hover: #cbd5e1;
            --text-heading: #0f172a;
            --text-body: #334155;
            --text-muted: #64748b;
            --danger: #ef4444;
            --danger-light: #fef2f2;
            --warning: #f59e0b;
            --warning-light: #fffbeb;
            --info: #0284c7;
            --info-light: #f0f9ff;
            --radius-sm: 8px;
            --radius-md: 12px;
            --radius-lg: 16px;
            --shadow-subtle: 0 1px 3px 0 rgba(0, 0, 0, 0.05), 0 1px 2px -1px rgba(0, 0, 0, 0.05);
            --shadow-card: 0 4px 6px -1px rgba(0, 0, 0, 0.04), 0 2px 4px -2px rgba(0, 0, 0, 0.04);
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

        /* Top Bar */
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
            background: linear-gradient(90deg, #ef4444, #f59e0b, #4f46e5);
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

        /* Nav Tabs */
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
        .nav-link:hover { color: var(--primary); background: rgba(255, 255, 255, 0.7); }
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
        .nav-link.back-btn:hover { background: var(--surface); }

        /* KPI Strip */
        .kpi-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
            gap: 18px;
        }
        .kpi-card {
            background: var(--surface);
            padding: 20px 24px;
            border-radius: var(--radius-md);
            border: 1px solid var(--border);
            box-shadow: var(--shadow-card);
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .kpi-label {
            font-size: 11.5px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: var(--text-muted);
        }
        .kpi-value {
            font-size: 30px;
            font-weight: 800;
            color: var(--text-heading);
            line-height: 1.1;
            margin-top: 4px;
        }
        .kpi-icon {
            width: 44px;
            height: 44px;
            border-radius: 10px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 20px;
        }

        /* Filter Form */
        .content-card {
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
        }
        .input-group input {
            border: none;
            outline: none;
            padding: 9px 8px;
            font-size: 13px;
            font-family: inherit;
            min-width: 240px;
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
        .btn-submit {
            background: var(--primary);
            color: #ffffff;
            border: none;
            padding: 9px 18px;
            border-radius: var(--radius-sm);
            font-size: 13px;
            font-weight: 700;
            cursor: pointer;
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
        }
        .btn-reset:hover { background: #f1f5f9; color: var(--text-heading); }

        /* Tables */
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
            vertical-align: top;
        }
        tr:last-child td { border-bottom: none; }
        tr:hover td { background-color: #fafbfd; }

        /* Severity Badges */
        .badge {
            display: inline-flex;
            align-items: center;
            gap: 4px;
            padding: 4px 10px;
            border-radius: 9999px;
            font-size: 11px;
            font-weight: 700;
            letter-spacing: 0.02em;
        }
        .badge-CRITICAL { background: var(--danger-light); color: var(--danger); border: 1px solid #fecaca; }
        .badge-HIGH { background: var(--warning-light); color: var(--warning); border: 1px solid #fed7aa; }
        .badge-MEDIUM { background: #fefce8; color: #a16207; border: 1px solid #fef08a; }
        .badge-LOW { background: var(--info-light); color: var(--info); border: 1px solid #bae6fd; }

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
    </style>
</head>
<body>
    <div class="container">
        
        <!-- Header -->
        <header class="top-navbar">
            <div class="header-title">
                <h1>Application Exception &amp; Incident Triage</h1>
                <p>Welcome, <b><%= userDisplayName %></b> &bull; Real-time system errors, caught exceptions, and failure diagnostics</p>
            </div>
            <nav class="nav-tabs">
                <a href="<%= request.getContextPath() %>/dashboard.jsp" class="nav-link back-btn">&larr; Workspace</a>
                <a href="<%= request.getContextPath() %>/system-dashboard.jsp" class="nav-link">Dashboard</a>
                <a href="<%= request.getContextPath() %>/auditlogs.jsp" class="nav-link">Audit Trail</a>
                <a href="<%= request.getContextPath() %>/login-history.jsp" class="nav-link">Login History</a>
                <a href="<%= request.getContextPath() %>/system-settings.jsp" class="nav-link">Settings</a>
                <a href="<%= request.getContextPath() %>/system-errors.jsp" class="nav-link active">Exceptions</a>
                <a href="<%= request.getContextPath() %>/backup-management.jsp" class="nav-link">Backups</a>
            </nav>
        </header>

        <!-- KPI Strip -->
        <section class="kpi-grid">
            <div class="kpi-card">
                <div>
                    <div class="kpi-label">Total Logged Incidents</div>
                    <div class="kpi-value"><%= totalCount %></div>
                </div>
                <div class="kpi-icon" style="background:#f1f5f9; color:#475569;">&#128196;</div>
            </div>

            <div class="kpi-card">
                <div>
                    <div class="kpi-label">Critical Faults</div>
                    <div class="kpi-value" style="color: var(--danger);"><%= criticalCount %></div>
                </div>
                <div class="kpi-icon" style="background:var(--danger-light); color:var(--danger);">&#9888;</div>
            </div>

            <div class="kpi-card">
                <div>
                    <div class="kpi-label">High Severity Faults</div>
                    <div class="kpi-value" style="color: var(--warning);"><%= highCount %></div>
                </div>
                <div class="kpi-icon" style="background:var(--warning-light); color:var(--warning);">&#9881;</div>
            </div>
        </section>

        <!-- Main Content -->
        <main class="content-card">
            <!-- Filter Toolbar -->
            <form method="get" action="<%= request.getContextPath() %>/system-errors.jsp" class="filter-form">
                <div class="input-group">
                    <span style="color: var(--text-muted); margin-right: 6px;">&#128269;</span>
                    <input type="text" name="module" placeholder="Filter by module (e.g. AUTH, PAYROLL)..." value="<%= selectedModule %>">
                </div>

                <div class="select-group">
                    <select name="severity">
                        <option value="">All Severities</option>
                        <option value="CRITICAL" <%= "CRITICAL".equalsIgnoreCase(selectedSeverity) ? "selected" : "" %>>CRITICAL</option>
                        <option value="HIGH" <%= "HIGH".equalsIgnoreCase(selectedSeverity) ? "selected" : "" %>>HIGH</option>
                        <option value="MEDIUM" <%= "MEDIUM".equalsIgnoreCase(selectedSeverity) ? "selected" : "" %>>MEDIUM</option>
                        <option value="LOW" <%= "LOW".equalsIgnoreCase(selectedSeverity) ? "selected" : "" %>>LOW</option>
                    </select>
                </div>

                <button type="submit" class="btn-submit">Filter Exceptions</button>
                <a href="<%= request.getContextPath() %>/system-errors.jsp" class="btn-reset">Reset</a>
            </form>

            <!-- Table -->
            <div class="table-responsive">
                <table>
                    <thead>
                        <tr>
                            <th style="width: 16%;">Timestamp</th>
                            <th style="width: 14%;">Module</th>
                            <th style="width: 10%;">Severity</th>
                            <th style="width: 18%;">Exception Type</th>
                            <th style="width: 34%;">Diagnostic Message</th>
                            <th style="width: 8%;">User ID</th>
                        </tr>
                    </thead>
                    <tbody>
                        <%
                            if (errorList != null && !errorList.isEmpty()) {
                                for (SystemError err : errorList) {
                                    String sev = err.getSeverity() != null ? err.getSeverity().toUpperCase() : "LOW";
                        %>
                            <tr>
                                <td style="color: var(--text-muted); font-size: 12.5px;">
                                    <%= err.getCreatedAt() != null ? err.getCreatedAt() : "-" %>
                                </td>
                                <td><b><%= err.getModuleName() != null ? err.getModuleName() : "-" %></b></td>
                                <td><span class="badge badge-<%= sev %>"><%= sev %></span></td>
                                <td><code><%= err.getErrorType() != null ? err.getErrorType() : "-" %></code></td>
                                <td style="color: var(--text-body); max-width: 320px; word-break: break-word;">
                                    <%= err.getErrorMessage() != null ? err.getErrorMessage() : "-" %>
                                </td>
                                <td>
                                    <span style="font-weight: 600; color: #475569;">
                                        <%= err.getUserId() != null && err.getUserId() > 0 ? "#" + err.getUserId() : "-" %>
                                    </span>
                                </td>
                            </tr>
                        <%
                                }
                            } else {
                        %>
                            <tr>
                                <td colspan="6" style="text-align: center; color: var(--text-muted); padding: 48px 0;">
                                    <div style="font-size: 28px; margin-bottom: 8px;">&#10004;</div>
                                    <div style="font-weight: 700; color: #10b981;">No exceptions found</div>
                                    <div style="font-size: 12.5px; margin-top: 4px;">No application errors recorded matching the filter criteria.</div>
                                </td>
                            </tr>
                        <% } %>
                    </tbody>
                </table>
            </div>
        </main>
    </div>
</body>
</html>