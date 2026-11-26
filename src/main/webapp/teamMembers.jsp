<%@ page contentType="text/html;charset=UTF-8" %>
<%@ page import="com.example.demo.model.Team" %>
<%@ page import="com.example.demo.model.TeamMember" %>
<%@ page import="java.util.List" %>
<%
    Team team = (Team) request.getAttribute("team");
    List<TeamMember> members = (List<TeamMember>) request.getAttribute("members");
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Team Members | <%= team.getTeamName() %></title>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;600;700;800&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Plus Jakarta Sans', sans-serif; background: #f8fafc; padding: 30px; }
        .table-card { background: white; border-radius: 14px; border: 1px solid #e2e8f0; overflow: hidden; max-width: 960px; margin: 0 auto; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05); }
        table { width: 100%; border-collapse: collapse; font-size: 13px; }
        th, td { padding: 14px 18px; border-bottom: 1px solid #e2e8f0; text-align: left; }
        th { background: #f8fafc; font-size: 11px; text-transform: uppercase; color: #64748b; font-weight: 700; }
        .btn-add { background: #2563eb; color: #fff; padding: 8px 16px; border-radius: 8px; text-decoration: none; font-weight: 700; font-size: 13px; }
        .btn-remove { background: #fee2e2; color: #ef4444; padding: 6px 12px; border-radius: 6px; text-decoration: none; font-weight: 700; font-size: 12px; }
    </style>
</head>
<body>
<div style="max-width: 960px; margin: 0 auto 20px; display: flex; justify-content: space-between; align-items: center;">
    <div>
        <h1 style="font-size: 22px; font-weight: 800;"><%= team.getTeamName() %> Members</h1>
        <p style="font-size: 13px; color: #64748b;">Manage active roster assignments</p>
    </div>
    <a href="<%= request.getContextPath() %>/teams/member/add?teamId=<%= team.getId() %>" class="btn-add">+ Add Member</a>
</div>

<div class="table-card">
    <table>
        <thead>
            <tr>
                <th>Employee ID</th>
                <th>Employee Name</th>
                <th>Designation</th>
                <th>Status</th>
                <th>Action</th>
            </tr>
        </thead>
        <tbody>
            <% if (members != null && !members.isEmpty()) {
                for (TeamMember m : members) { %>
                    <tr>
                        <td><strong><%= m.getEmpCode() %></strong></td>
                        <td><%= m.getEmployeeName() %></td>
                        <td><%= m.getRole() %></td>
                        <td>
                            <span style="font-size: 11px; font-weight: 700; color: <%= "ACTIVE".equalsIgnoreCase(m.getStatus()) ? "#10b981" : "#ef4444" %>">
                                &#9679; <%= m.getStatus() %>
                            </span>
                        </td>
                        <td>
                            <% if ("ACTIVE".equalsIgnoreCase(m.getStatus())) { %>
                                <a href="<%= request.getContextPath() %>/teams/member/remove?teamId=<%= team.getId() %>&employeeId=<%= m.getEmployeeId() %>" class="btn-remove">Remove Member</a>
                            <% } else { %>
                                <span style="font-size: 12px; color: #94a3b8;">Inactive</span>
                            <% } %>
                        </td>
                    </tr>
            <% } } else { %>
                <tr><td colspan="5" style="text-align: center; color: #94a3b8; padding: 30px;">No members enrolled.</td></tr>
            <% } %>
        </tbody>
    </table>
</div>
</body>
</html>