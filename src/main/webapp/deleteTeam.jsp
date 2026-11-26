<%@ page contentType="text/html;charset=UTF-8" %>
<%@ page import="com.example.demo.model.Team" %>
<%
    Team team = (Team) request.getAttribute("team");
    int activeMembers = (request.getAttribute("activeMemberCount") != null) 
                        ? (Integer) request.getAttribute("activeMemberCount") : 0;
    String error = (String) request.getAttribute("error");
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Delete Team Confirmation | EMS Enterprise</title>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;600;700;800&display=swap" rel="stylesheet">
    <style>
        body {
            font-family: 'Plus Jakarta Sans', sans-serif;
            background: #f8fafc;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            padding: 24px;
            margin: 0;
            box-sizing: border-box;
        }
        .card {
            max-width: 480px;
            width: 100%;
            background: #fff;
            border: 1px solid #e2e8f0;
            border-radius: 16px;
            padding: 32px;
            box-shadow: 0 10px 15px -3px rgba(0,0,0,0.05);
        }
        .btn {
            padding: 10px 18px;
            border-radius: 8px;
            border: none;
            font-weight: 700;
            font-size: 13px;
            cursor: pointer;
            text-decoration: none;
            display: inline-flex;
            align-items: center;
            justify-content: center;
        }
        .btn-danger { background: #ef4444; color: white; }
        .btn-danger:hover { background: #dc2626; }
        .btn-warn { background: #f59e0b; color: white; }
        .btn-warn:hover { background: #d97706; }
        .btn-cancel { background: #e2e8f0; color: #475569; }
        .btn-cancel:hover { background: #cbd5e1; }
    </style>
</head>
<body>
<div class="card">
    <h2 style="color: #991b1b; font-size: 20px; font-weight: 800; margin-bottom: 8px;">Delete Confirmation</h2>
    <p style="font-size: 14px; color: #475569; margin-bottom: 16px;">
        Are you sure you want to remove team: <strong><%= (team != null) ? team.getTeamName() : "" %></strong>?
    </p>

    <% if (error != null) { %>
        <div style="background: #fee2e2; border: 1px solid #fecaca; color: #991b1b; padding: 12px; border-radius: 8px; font-size: 13px; font-weight: 600; margin-bottom: 20px;">
            <%= error %>
        </div>
    <% } %>

    <% if (activeMembers > 0) { %>
        <div style="font-size: 13px; color: #b45309; background: #fef3c7; border: 1px solid #fde68a; padding: 12px; border-radius: 8px; margin-bottom: 20px;">
            ⚠️ This team currently contains <strong><%= activeMembers %> active member(s)</strong>. Permanent deletion will remove these assignments automatically. Alternatively, you can deactivate the team.
        </div>

        <form action="<%= request.getContextPath() %>/teams/delete" method="post" style="display: flex; gap: 10px; flex-wrap: wrap;">
            <input type="hidden" name="id" value="<%= (team != null) ? team.getId() : 0 %>">

            <button type="submit" name="actionType" value="HARD_DELETE" class="btn btn-danger" onclick="return confirm('Confirm permanent deletion of this team and its associations?');">
                Delete Permanently
            </button>

            <button type="submit" name="actionType" value="DEACTIVATE" class="btn btn-warn">
                Set INACTIVE
            </button>

            <a href="<%= request.getContextPath() %>/teams/search" class="btn btn-cancel">Cancel</a>
        </form>
    <% } else { %>
        <form action="<%= request.getContextPath() %>/teams/delete" method="post" style="display: flex; gap: 10px;">
            <input type="hidden" name="id" value="<%= (team != null) ? team.getId() : 0 %>">
            <button type="submit" name="actionType" value="HARD_DELETE" class="btn btn-danger">
                Yes, Delete
            </button>
            <a href="<%= request.getContextPath() %>/teams/search" class="btn-cancel">Cancel</a>
        </form>
    <% } %>
</div>
</body>
</html>