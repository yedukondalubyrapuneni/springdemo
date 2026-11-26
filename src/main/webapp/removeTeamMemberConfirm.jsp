<%@ page contentType="text/html;charset=UTF-8" %>
<%@ page import="com.example.demo.model.Team" %>
<%@ page import="com.example.demo.model.Employee" %>
<%
    Team team = (Team) request.getAttribute("team");
    Employee emp = (Employee) request.getAttribute("targetEmployee");
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Remove From Team Confirmation</title>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;600;700;800&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Plus Jakarta Sans', sans-serif; background: #f8fafc; display: flex; justify-content: center; align-items: center; min-height: 100vh; padding: 24px; }
        .card { max-width: 440px; width: 100%; background: #fff; border: 1px solid #e2e8f0; border-radius: 16px; padding: 32px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05); }
        .btn-confirm { background: #ef4444; color: white; border: none; padding: 10px 18px; border-radius: 8px; font-weight: 700; cursor: pointer; }
        .btn-cancel { background: #e2e8f0; color: #475569; padding: 10px 18px; border-radius: 8px; text-decoration: none; font-weight: 700; }
    </style>
</head>
<body>
<div class="card">
    <h2 style="font-size: 20px; font-weight: 800; margin-bottom: 12px;">Confirmation</h2>
    <p style="font-size: 14px; color: #334155; line-height: 1.5; margin-bottom: 24px;">
        Are you sure you want to remove <strong><%= emp.getName() %></strong> from <strong><%= team.getTeamName() %></strong>?
    </p>

    <form action="<%= request.getContextPath() %>/teams/member/remove" method="post" style="display: flex; gap: 12px;">
        <input type="hidden" name="teamId" value="<%= team.getId() %>">
        <input type="hidden" name="employeeId" value="<%= emp.getId() %>">
        <button type="submit" class="btn-confirm">Yes</button>
        <a href="<%= request.getContextPath() %>/teams/view?id=<%= team.getId() %>" class="btn-cancel">Cancel</a>
    </form>
</div>
</body>
</html>