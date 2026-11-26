<%@ page contentType="text/html;charset=UTF-8" %>
<%@ page import="com.example.demo.model.Team" %>
<%@ page import="com.example.demo.model.TeamMember" %>
<%@ page import="java.util.List" %>
<%
    boolean isManager = (Boolean) request.getAttribute("isManager");
    Team team = (Team) request.getAttribute("team");
    List<TeamMember> members = (List<TeamMember>) request.getAttribute("members");
    List<Team> managedTeams = (List<Team>) request.getAttribute("managedTeams");
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>My Team | EMS</title>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;600;700;800&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Plus Jakarta Sans', sans-serif; background: #f8fafc; padding: 32px; color: #0f172a; }
        .card { max-width: 800px; margin: 0 auto 24px; background: #fff; border: 1px solid #e2e8f0; border-radius: 16px; padding: 28px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.04); }
        .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; font-size: 13px; margin-bottom: 20px; }
        table { width: 100%; border-collapse: collapse; font-size: 13px; }
        th, td { padding: 12px 14px; border-bottom: 1px solid #e2e8f0; text-align: left; }
        th { background: #f8fafc; font-size: 11px; text-transform: uppercase; color: #64748b; font-weight: 700; }
    </style>
</head>
<body>

<div class="card">
    <h1 style="font-size: 22px; font-weight: 800; margin-bottom: 18px;">MY TEAM</h1>

    <% if (isManager) { %>
        <% if (managedTeams != null && !managedTeams.isEmpty()) { 
            for (Team t : managedTeams) { %>
                <div style="border: 1px solid #e2e8f0; border-radius: 12px; padding: 20px; margin-bottom: 16px;">
                    <h3 style="font-size: 16px; font-weight: 700; margin-bottom: 8px;"><%= t.getTeamName() %></h3>
                    <div style="font-size: 13px; color: #475569; margin-bottom: 12px;">Manager: <strong><%= t.getManagerName() %></strong></div>
                    <a href="<%= request.getContextPath() %>/teams/view?id=<%= t.getId() %>" style="color: #2563eb; text-decoration: none; font-weight: 700; font-size: 13px;">View Roster &rarr;</a>
                </div>
        <% } } else { %>
            <p style="color: #94a3b8;">No teams currently assigned under your leadership.</p>
        <% } %>
    <% } else { %>
        <% if (team != null) { %>
            <div class="grid">
                <div>Team Name: <strong><%= team.getTeamName() %></strong></div>
                <div>Department: <strong><%= team.getDepartmentName() %></strong></div>
                <div>Team Manager: <strong><%= team.getManagerName() %></strong></div>
                <div>Description: <strong><%= team.getDescription() %></strong></div>
            </div>

            <h3 style="font-size: 15px; font-weight: 700; margin-bottom: 12px; text-transform: uppercase;">Team Members</h3>
            <table>
                <thead>
                    <tr>
                        <th>Employee</th>
                        <th>Designation</th>
                    </tr>
                </thead>
                <tbody>
                    <% if (members != null) { 
                        for (TeamMember m : members) { 
                            if ("ACTIVE".equalsIgnoreCase(m.getStatus())) { %>
                            <tr>
                                <td><strong><%= m.getEmployeeName() %></strong> (<%= m.getEmpCode() %>)</td>
                                <td><%= m.getRole() %></td>
                            </tr>
                    <% } } } %>
                </tbody>
            </table>
        <% } else { %>
            <p style="color: #94a3b8;">You are not currently assigned to an operational team.</p>
        <% } %>
    <% } %>
</div>
</body>
</html>