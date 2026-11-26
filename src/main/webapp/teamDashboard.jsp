<%@ page contentType="text/html;charset=UTF-8" %>
<%@ page import="com.Util.DBConnection, java.sql.*, java.util.Map, java.util.LinkedHashMap" %>
<%
    Map<String, Object> metrics = (Map<String, Object>) request.getAttribute("metrics");
    int total = 0, active = 0, inactive = 0, members = 0;
    Map<String, Integer> deptCounts = null;

    if (metrics != null) {
        if (metrics.containsKey("totalTeams")) total = (Integer) metrics.get("totalTeams");
        if (metrics.containsKey("activeTeams")) active = (Integer) metrics.get("activeTeams");
        if (metrics.containsKey("inactiveTeams")) inactive = (Integer) metrics.get("inactiveTeams");
        if (metrics.containsKey("totalMembers")) members = (Integer) metrics.get("totalMembers");
        if (metrics.containsKey("deptCounts")) deptCounts = (Map<String, Integer>) metrics.get("deptCounts");
    } else {
        // Direct DB fallback if accessed without servlet dispatcher
        deptCounts = new LinkedHashMap<>();
        try (Connection conn = DBConnection.getConnection()) {
            try (Statement st = conn.createStatement();
                 ResultSet rs = st.executeQuery(
                     "SELECT " +
                     " COUNT(*) AS total_teams, " +
                     " SUM(CASE WHEN UPPER(status) = 'ACTIVE' THEN 1 ELSE 0 END) AS active_teams, " +
                     " SUM(CASE WHEN UPPER(status) = 'INACTIVE' THEN 1 ELSE 0 END) AS inactive_teams " +
                     "FROM teams")) {
                if (rs.next()) {
                    total = rs.getInt("total_teams");
                    active = rs.getInt("active_teams");
                    inactive = rs.getInt("inactive_teams");
                }
            }
            try (Statement st = conn.createStatement();
                 ResultSet rs = st.executeQuery("SELECT COUNT(*) FROM team_members")) {
                if (rs.next()) members = rs.getInt(1);
            }
            try (Statement st = conn.createStatement();
                 ResultSet rs = st.executeQuery(
                     "SELECT COALESCE(d.department_name, e.department, 'Operations') AS dept, COUNT(t.id) AS cnt " +
                     "FROM teams t " +
                     "LEFT JOIN department d ON t.department_id = d.id " +
                     "LEFT JOIN employee e ON (e.employee_id = t.manager_id OR e.employee_id = CAST(t.manager_id AS CHAR)) " +
                     "GROUP BY dept")) {
                while (rs.next()) {
                    deptCounts.put(rs.getString("dept"), rs.getInt("cnt"));
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Team Dashboard | EMS Analytics</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;600;700;800&display=swap" rel="stylesheet">
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Plus Jakarta Sans', sans-serif; }
        body { background: #f8fafc; padding: 36px 32px; color: #0f172a; -webkit-font-smoothing: antialiased; }
        .container { max-width: 1040px; margin: 0 auto; display: flex; flex-direction: column; gap: 24px; }
        .top-row { display: flex; justify-content: space-between; align-items: center; }
        .top-title { font-size: 22px; font-weight: 800; letter-spacing: -0.3px; }
        .back-link { color: #2563eb; text-decoration: none; font-weight: 700; font-size: 13px; display: inline-flex; align-items: center; gap: 4px; }
        .back-link:hover { text-decoration: underline; }

        .grid-stats { display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; }
        @media (max-width: 820px) { .grid-stats { grid-template-columns: repeat(2, 1fr); } }

        .stat-card { background: #ffffff; border: 1px solid #e2e8f0; border-radius: 14px; padding: 22px; text-align: center; box-shadow: 0 1px 3px rgba(0,0,0,0.02); }
        .stat-lbl { font-size: 11px; font-weight: 800; text-transform: uppercase; color: #64748b; margin-bottom: 8px; letter-spacing: 0.3px; }
        .stat-val { font-size: 32px; font-weight: 800; line-height: 1; }

        .panel { background: #ffffff; border: 1px solid #e2e8f0; border-radius: 14px; padding: 24px; box-shadow: 0 1px 3px rgba(0,0,0,0.02); }
        .panel-heading { font-size: 13px; font-weight: 800; margin-bottom: 16px; text-transform: uppercase; color: #64748b; letter-spacing: 0.3px; }
        .dept-item { display: flex; justify-content: space-between; align-items: center; padding: 14px 0; border-bottom: 1px solid #f1f5f9; font-size: 14px; }
        .dept-item:last-child { border-bottom: none; }
    </style>
</head>
<body>
<div class="container">
    <div class="top-row">
        <h1 class="top-title">TEAM DASHBOARD</h1>
        <a href="<%= request.getContextPath() %>/teams/search" class="back-link">&larr; Back to Catalog</a>
    </div>

    <div class="grid-stats">
        <div class="stat-card">
            <div class="stat-lbl">Total Teams</div>
            <div class="stat-val" style="color: #2563eb;"><%= total %></div>
        </div>
        <div class="stat-card">
            <div class="stat-lbl">Active Teams</div>
            <div class="stat-val" style="color: #10b981;"><%= active %></div>
        </div>
        <div class="stat-card">
            <div class="stat-lbl">Inactive Teams</div>
            <div class="stat-val" style="color: #ef4444;"><%= inactive %></div>
        </div>
        <div class="stat-card">
            <div class="stat-lbl">Total Team Members</div>
            <div class="stat-val" style="color: #0284c7;"><%= members %></div>
        </div>
    </div>

    <div class="panel">
        <div class="panel-heading">Department-wise Allocation</div>
        <% if (deptCounts != null && !deptCounts.isEmpty()) { 
            for (Map.Entry<String, Integer> e : deptCounts.entrySet()) { %>
                <div class="dept-item">
                    <span><strong><%= e.getKey() %></strong></span>
                    <span style="font-weight: 700; color: #2563eb;"><%= e.getValue() %> Teams</span>
                </div>
        <% } } else { %>
            <p style="color: #94a3b8; font-size: 13px;">No department metrics available.</p>
        <% } %>
    </div>
</div>
</body>
</html>