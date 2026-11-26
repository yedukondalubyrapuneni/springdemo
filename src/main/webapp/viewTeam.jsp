<%@ page contentType="text/html;charset=UTF-8" %>
<%@ page import="com.example.demo.model.Team" %>
<%@ page import="com.example.demo.model.TeamMember" %>
<%@ page import="com.example.demo.model.Employee" %>
<%@ page import="com.Util.DBConnection" %>
<%@ page import="java.sql.*" %>
<%@ page import="java.util.List" %>
<%@ page import="java.util.ArrayList" %>

<%
    Employee loggedIn = (Employee) session.getAttribute("loggedInEmployee");
    if (loggedIn == null) {
        response.sendRedirect(request.getContextPath() + "/login");
        return;
    }

    boolean isAdmin = "ADMIN".equalsIgnoreCase(loggedIn.getRole());

    Team team = (Team) request.getAttribute("team");
    List<TeamMember> members = (List<TeamMember>) request.getAttribute("members");

    // Fallback if accessed directly by URL
    if (members == null) {
        members = new ArrayList<>();
        String idParam = request.getParameter("id");
        if (idParam != null && !idParam.isBlank()) {
            int tId = Integer.parseInt(idParam.trim());
            String sql = "SELECT tm.id AS tm_id, tm.team_id, tm.employee_id AS tm_emp_code, " +
                         "COALESCE(tm.status, 'ACTIVE') AS member_status, " +
                         "e.employee_id AS emp_code, e.name AS emp_name, " +
                         "COALESCE(e.role, 'EMPLOYEE') AS emp_role, " +
                         "COALESCE(e.department, 'IT Support') AS emp_dept " +
                         "FROM team_members tm " +
                         "LEFT JOIN employee e ON (TRIM(REPLACE(tm.employee_id, ' ', '')) = TRIM(REPLACE(e.employee_id, ' ', ''))) " +
                         "WHERE tm.team_id = ? " +
                         "ORDER BY tm.id ASC";
            try (Connection conn = DBConnection.getConnection();
                 PreparedStatement ps = conn.prepareStatement(sql)) {
                ps.setInt(1, tId);
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        TeamMember m = new TeamMember();
                        m.setId(rs.getInt("tm_id"));
                        m.setTeamId(rs.getInt("team_id"));
                        String code = rs.getString("emp_code") != null ? rs.getString("emp_code") : rs.getString("tm_emp_code");
                        m.setEmpCode(code);
                        try { m.setEmployeeId(Integer.parseInt(code.replaceAll("[^0-9]", ""))); } catch(Throwable ignored){}
                        String name = rs.getString("emp_name");
                        m.setEmployeeName((name != null && !name.isBlank()) ? name : code);
                        m.setRole(rs.getString("emp_role"));
                        m.setDepartment(rs.getString("emp_dept"));
                        m.setStatus(rs.getString("member_status"));
                        members.add(m);
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
    }

    String msg = request.getParameter("msg");
    String error = (String) request.getAttribute("error");

    String teamName = (team != null && team.getTeamName() != null) ? team.getTeamName() : "UI";
    int currentTeamId = (team != null) ? team.getId() : Integer.parseInt(request.getParameter("id"));
    String formattedTeamId = String.format("TEAM%03d", currentTeamId);
    try {
        if (team != null && team.getFormattedTeamId() != null) formattedTeamId = team.getFormattedTeamId();
    } catch (Throwable ignored) {}

    String deptDisplay = "Engineering / IT";
    try { if (team != null && team.getDepartmentName() != null) deptDisplay = team.getDepartmentName(); } catch (Throwable ignored) {}

    String mgrDisplay = "Unassigned";
    try { if (team != null && team.getManagerName() != null) mgrDisplay = team.getManagerName(); } catch (Throwable ignored) {}

    String createdDisplay = "26-10-2026";
    try { if (team != null && team.getFormattedCreatedDate() != null) createdDisplay = team.getFormattedCreatedDate(); } catch (Throwable ignored) {}

    String descDisplay = "Frontend";
    try { if (team != null && team.getDescription() != null && !team.getDescription().isBlank()) descDisplay = team.getDescription(); } catch (Throwable ignored) {}

    String statusDisplay = (team != null && team.getStatus() != null) ? team.getStatus() : "ACTIVE";
%>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Team Details | EMS Enterprise</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        :root {
            --brand: #2563eb;
            --brand-hover: #1d4ed8;
            --surface-bg: #f8fafc;
            --card-bg: #ffffff;
            --border: #e2e8f0;
            --text-main: #0f172a;
            --text-muted: #64748b;
            --rose: #ef4444;
            --rose-bg: #fff1f2;
            --emerald: #10b981;
            --emerald-bg: #ecfdf5;
        }

        * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Plus Jakarta Sans', sans-serif; }
        body {
            background: var(--surface-bg);
            color: var(--text-main);
            padding: 32px 24px;
            -webkit-font-smoothing: antialiased;
        }
        .container {
            max-width: 980px;
            margin: 0 auto;
        }
        .top-nav {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
        }
        .nav-back {
            text-decoration: none;
            font-size: 13px;
            font-weight: 700;
            color: var(--brand);
            display: inline-flex;
            align-items: center;
            gap: 4px;
        }
        .nav-back:hover { text-decoration: underline; }

        .alert {
            padding: 12px 16px;
            border-radius: 8px;
            font-size: 13px;
            font-weight: 600;
            margin-bottom: 20px;
        }
        .alert-success { background: var(--emerald-bg); color: #065f46; border: 1px solid #a7f3d0; }
        .alert-danger { background: var(--rose-bg); color: #9f1239; border: 1px solid #fecdd3; }

        .card {
            background: var(--card-bg);
            border: 1px solid var(--border);
            border-radius: 14px;
            padding: 24px 28px;
            margin-bottom: 24px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.02);
        }
        .card-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 1px solid var(--border);
            padding-bottom: 14px;
            margin-bottom: 18px;
        }
        .card-header h2 {
            font-size: 15px;
            font-weight: 800;
            letter-spacing: 0.3px;
            text-transform: uppercase;
        }

        .info-grid {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 16px 28px;
            font-size: 13px;
        }
        .info-item {
            color: var(--text-muted);
        }
        .info-item strong {
            color: var(--text-main);
            margin-left: 4px;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            font-size: 13px;
            margin-top: 8px;
        }
        th, td {
            padding: 13px 14px;
            text-align: left;
            border-bottom: 1px solid var(--border);
        }
        th {
            background: #f8fafc;
            font-size: 11px;
            font-weight: 800;
            text-transform: uppercase;
            color: var(--text-muted);
            letter-spacing: 0.3px;
        }
        td { vertical-align: middle; }

        .btn-add {
            background: var(--brand);
            color: #fff;
            text-decoration: none;
            font-size: 12px;
            font-weight: 700;
            padding: 8px 14px;
            border-radius: 6px;
            display: inline-flex;
            align-items: center;
            gap: 4px;
            transition: background 0.15s ease;
        }
        .btn-add:hover { background: var(--brand-hover); }

        .btn-remove {
            background: var(--rose-bg);
            color: var(--rose);
            border: 1px solid #fecdd3;
            padding: 5px 12px;
            border-radius: 6px;
            font-size: 11.5px;
            font-weight: 700;
            cursor: pointer;
            text-decoration: none;
            display: inline-block;
            transition: all 0.15s ease;
        }
        .btn-remove:hover { background: #fee2e2; }

        .badge-readonly {
            color: var(--text-muted);
            font-size: 12px;
            font-style: italic;
        }
    </style>
</head>
<body>

<div class="container">
    <div class="top-nav">
        <a href="<%= request.getContextPath() %>/teams/search" class="nav-back">&larr; Back to Teams</a>
        <% if (isAdmin) { %>
            <a href="<%= request.getContextPath() %>/teams/edit?id=<%= currentTeamId %>" 
               style="text-decoration: none; font-size: 13px; font-weight: 700; color: #475569;">
               Edit Team Details &rarr;
            </a>
        <% } %>
    </div>

    <% if (msg != null && !msg.isBlank()) { %>
        <div class="alert alert-success">&#10004; <%= msg %></div>
    <% } %>
    <% if (error != null && !error.isBlank()) { %>
        <div class="alert alert-danger">&#9888; <%= error %></div>
    <% } %>

    <!-- Team Overview -->
    <div class="card">
        <div class="card-header">
            <h2>TEAM OVERVIEW</h2>
            <span style="font-size: 12px; font-weight: 800; color: <%= "ACTIVE".equalsIgnoreCase(statusDisplay) ? "var(--emerald)" : "var(--rose)" %>;">
                &#9679; <%= statusDisplay %>
            </span>
        </div>
        <div class="info-grid">
            <div class="info-item">Team ID: <strong><%= formattedTeamId %></strong></div>
            <div class="info-item">Team Name: <strong><%= teamName %></strong></div>
            <div class="info-item">Department: <strong><%= deptDisplay %></strong></div>
            <div class="info-item">Supervising Manager: <strong><%= mgrDisplay %></strong></div>
            <div class="info-item">Created Date: <strong><%= createdDisplay %></strong></div>
            <div class="info-item" style="grid-column: span 2;">Description: <strong><%= descDisplay %></strong></div>
        </div>
    </div>

    <!-- Assigned Members -->
    <div class="card">
        <div class="card-header">
            <h2>ASSIGNED MEMBERS (<%= (members != null) ? members.size() : 0 %>)</h2>
            <% if (isAdmin) { %>
                <a href="<%= request.getContextPath() %>/teams/member/add?teamId=<%= currentTeamId %>" class="btn-add">
                    + Add Member
                </a>
            <% } %>
        </div>

        <table>
            <thead>
                <tr>
                    <th style="width: 18%;">EMPLOYEE ID</th>
                    <th style="width: 28%;">MEMBER NAME</th>
                    <th style="width: 24%;">DESIGNATION / ROLE</th>
                    <th style="width: 20%;">DEPARTMENT</th>
                    <th style="width: 10%;">ACTION</th>
                </tr>
            </thead>
            <tbody>
                <% if (members != null && !members.isEmpty()) { 
                    for (TeamMember m : members) { 
                        String empDisplay = m.getEmpCode();
                        if (empDisplay == null || empDisplay.isBlank()) {
                            empDisplay = "EMP" + m.getEmployeeId();
                        }
                        String empName = m.getEmployeeName();
                        if (empName == null || empName.isBlank()) empName = empDisplay;
                %>
                        <tr>
                            <td><strong><%= empDisplay %></strong></td>
                            <td><%= empName %></td>
                            <td><%= (m.getRole() != null ? m.getRole() : "EMPLOYEE") %></td>
                            <td><%= (m.getDepartment() != null ? m.getDepartment() : "IT Support") %></td>
                            <td>
                                <% if (isAdmin) { %>
                                    <form action="<%= request.getContextPath() %>/teams/member/remove" method="post" style="display:inline;">
                                        <input type="hidden" name="teamId" value="<%= currentTeamId %>">
                                        <input type="hidden" name="employeeId" value="<%= empDisplay %>">
                                        <button type="submit" class="btn-remove" onclick="return confirm('Remove <%= empName %> from this team?');">
                                            Remove
                                        </button>
                                    </form>
                                <% } else { %>
                                    <span class="badge-readonly">View Only</span>
                                <% } %>
                            </td>
                        </tr>
                <%  } 
                   } else { %>
                    <tr>
                        <td colspan="5" style="text-align: center; color: var(--text-muted); padding: 28px;">
                            No employees assigned to this team yet.
                        </td>
                    </tr>
                <% } %>
            </tbody>
        </table>
    </div>
</div>

</body>
</html>