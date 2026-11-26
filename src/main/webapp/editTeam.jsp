<%@ page contentType="text/html;charset=UTF-8" %>
<%@ page import="com.example.demo.model.Team" %>
<%@ page import="com.example.demo.model.Employee" %>
<%@ page import="com.Util.DBConnection" %>
<%@ page import="java.sql.*" %>
<%@ page import="java.util.List" %>
<%@ page import="java.util.ArrayList" %>

<%
    Team team = (Team) request.getAttribute("team");
    List<Employee> allEmployees = (List<Employee>) request.getAttribute("allEmployees");

    // Fallback: If accessed directly via URL (e.g. editTeam.jsp?id=3), fetch team from DB
    String idParam = request.getParameter("id");
    if (team == null && idParam != null && !idParam.isBlank()) {
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement("SELECT * FROM teams WHERE id = ?")) {
            ps.setInt(1, Integer.parseInt(idParam.trim()));
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    team = new Team();
                    team.setId(rs.getInt("id"));
                    team.setTeamName(rs.getString("team_name"));
                    try { team.setDescription(rs.getString("description")); } catch (Throwable ignored) {}
                    try { team.setDepartmentId(rs.getInt("department_id")); } catch (Throwable ignored) {}
                    try { team.setManagerId(rs.getInt("manager_id")); } catch (Throwable ignored) {}
                    try { team.setStatus(rs.getString("status")); } catch (Throwable ignored) {}
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    // Fallback: If allEmployees list was not passed by a servlet, fetch active managers/employees from DB
    if (allEmployees == null) {
        allEmployees = new ArrayList<>();
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(
                 "SELECT * FROM employee WHERE UPPER(role) = 'MANAGER' OR UPPER(role) = 'ADMIN' ORDER BY name ASC")) {
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Employee emp = new Employee();
                    try { emp.setId(rs.getInt("id")); } catch (Throwable ignored) {}
                    try { emp.setEmployeeId(rs.getString("employee_id")); } catch (Throwable ignored) {}
                    try { emp.setName(rs.getString("name")); } catch (Throwable ignored) {}
                    allEmployees.add(emp);
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    // Safety guard: if team still does not exist, redirect back cleanly
    if (team == null) {
        response.sendRedirect(request.getContextPath() + "/manageTeams.jsp");
        return;
    }

    // Safe retrieval of team ID display
    String displayTeamId = "#" + team.getId();
    try {
        if (team.getFormattedTeamId() != null) {
            displayTeamId = team.getFormattedTeamId();
        }
    } catch (Throwable ignored) {}
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Edit Team | EMS Enterprise</title>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;600;700;800&display=swap" rel="stylesheet">
    <style>
        :root { --brand: #2563eb; --brand-hover: #1d4ed8; --border: #e2e8f0; --bg: #f8fafc; --text: #0f172a; }
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Plus Jakarta Sans', sans-serif; }
        body { background: var(--bg); display: flex; justify-content: center; align-items: center; min-height: 100vh; padding: 24px; color: var(--text); }
        .card { width: 100%; max-width: 500px; background: #fff; border: 1px solid var(--border); border-radius: 16px; padding: 32px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05); }
        .form-group { margin-bottom: 16px; }
        label { display: block; font-size: 11px; font-weight: 700; text-transform: uppercase; margin-bottom: 6px; color: #64748b; letter-spacing: 0.3px; }
        input, select, textarea { width: 100%; padding: 10px 14px; border: 1px solid var(--border); border-radius: 8px; font-size: 13px; outline: none; background: #fff; font-family: inherit; }
        input:focus, select:focus, textarea:focus { border-color: var(--brand); }
        .actions-row { display: flex; gap: 10px; margin-top: 22px; }
        .btn-submit { flex: 1; padding: 12px; background: var(--brand); color: #fff; border: none; border-radius: 8px; font-weight: 700; cursor: pointer; transition: background 0.15s ease; }
        .btn-submit:hover { background: var(--brand-hover); }
        .btn-cancel { padding: 12px 18px; background: #fff; border: 1px solid var(--border); border-radius: 8px; font-weight: 700; font-size: 13px; color: #64748b; text-decoration: none; display: inline-flex; align-items: center; justify-content: center; }
        .btn-cancel:hover { background: #f1f5f9; }
    </style>
</head>
<body>
<div class="card">
    <h2 style="font-size: 20px; font-weight: 800; margin-bottom: 6px;">EDIT TEAM</h2>
    <p style="font-size: 13px; color: #64748b; margin-bottom: 20px;">Update core structural parameters for <%= displayTeamId %></p>

    <form action="<%= request.getContextPath() %>/teams/edit" method="post">
        <input type="hidden" name="id" value="<%= team.getId() %>">

        <div class="form-group">
            <label>Team Name</label>
            <input type="text" name="teamName" value="<%= (team.getTeamName() != null ? team.getTeamName() : "") %>" required>
        </div>

        <div class="form-group">
            <label>Description</label>
            <textarea name="description" rows="3"><%= (team.getDescription() != null ? team.getDescription() : "") %></textarea>
        </div>

        <div class="form-group">
            <label>Department</label>
            <select name="departmentId">
                <option value="1" <%= (team.getDepartmentId() != null && team.getDepartmentId() == 1) ? "selected" : "" %>>IT</option>
                <option value="2" <%= (team.getDepartmentId() != null && team.getDepartmentId() == 2) ? "selected" : "" %>>HR</option>
                <option value="3" <%= (team.getDepartmentId() != null && team.getDepartmentId() == 3) ? "selected" : "" %>>Finance</option>
                <option value="4" <%= (team.getDepartmentId() != null && team.getDepartmentId() == 4) ? "selected" : "" %>>Sales</option>
            </select>
        </div>

        <div class="form-group">
            <label>Manager</label>
            <select name="managerId">
                <option value="">-- Select Manager --</option>
                <% if (allEmployees != null && !allEmployees.isEmpty()) { 
                    for (Employee e : allEmployees) { 
                        boolean isSelected = false;
                        try {
                            if (team.getManagerId() != null && team.getManagerId() == e.getId()) {
                                isSelected = true;
                            }
                        } catch (Throwable ignored) {}
                %>
                    <option value="<%= e.getId() %>" <%= isSelected ? "selected" : "" %>>
                        <%= e.getName() %> <%= (e.getEmployeeId() != null ? "(" + e.getEmployeeId() + ")" : "") %>
                    </option>
                <%  } 
                   } %>
            </select>
        </div>

        <div class="form-group">
            <label>Status</label>
            <select name="status">
                <option value="ACTIVE" <%= (team.getStatus() != null && "ACTIVE".equalsIgnoreCase(team.getStatus())) ? "selected" : "" %>>ACTIVE</option>
                <option value="INACTIVE" <%= (team.getStatus() != null && "INACTIVE".equalsIgnoreCase(team.getStatus())) ? "selected" : "" %>>INACTIVE</option>
            </select>
        </div>

        <div class="actions-row">
            <button type="submit" class="btn-submit">Update Team</button>
            <a href="<%= request.getContextPath() %>/manageTeams.jsp" class="btn-cancel">Cancel</a>
        </div>
    </form>
</div>
</body>
</html>