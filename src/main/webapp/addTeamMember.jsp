<%@ page contentType="text/html;charset=UTF-8" %>
<%@ page import="com.example.demo.model.Team" %>
<%@ page import="com.example.demo.model.Employee" %>
<%@ page import="java.util.List" %>

<%
    Employee loggedIn = (Employee) session.getAttribute("loggedInEmployee");
    if (loggedIn == null || !"ADMIN".equalsIgnoreCase(loggedIn.getRole())) {
        response.sendRedirect(request.getContextPath() + "/teams/search");
        return;
    }

    Team team = (Team) request.getAttribute("team");
    List<Employee> allEmployees = (List<Employee>) request.getAttribute("allEmployees");
    String error = (String) request.getAttribute("error");
%>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Assign Member to Team | EMS Enterprise</title>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;600;700;800&display=swap" rel="stylesheet">
    <style>
        body {
            font-family: 'Plus Jakarta Sans', sans-serif;
            background: #f8fafc;
            margin: 0;
            padding: 40px 16px;
            display: flex;
            justify-content: center;
        }
        .card {
            background: #ffffff;
            width: 100%;
            max-width: 480px;
            border: 1px solid #e2e8f0;
            border-radius: 16px;
            padding: 32px;
            box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05);
        }
        .team-badge {
            background: #eff6ff;
            color: #2563eb;
            font-size: 12px;
            font-weight: 700;
            padding: 4px 10px;
            border-radius: 6px;
            display: inline-block;
            margin-bottom: 12px;
        }
        h2 { font-size: 20px; font-weight: 800; margin-bottom: 6px; }
        p { font-size: 13px; color: #64748b; margin-bottom: 22px; }
        .form-group { margin-bottom: 18px; }
        label { display: block; font-size: 11px; font-weight: 700; text-transform: uppercase; color: #64748b; margin-bottom: 6px; }
        select {
            width: 100%;
            height: 42px;
            border: 1px solid #e2e8f0;
            border-radius: 8px;
            padding: 0 12px;
            font-size: 13px;
            box-sizing: border-box;
            outline: none;
            background: #fff;
        }
        select:focus { border-color: #2563eb; }
        .btn-submit {
            width: 100%;
            height: 44px;
            background: #2563eb;
            color: white;
            border: none;
            border-radius: 8px;
            font-weight: 700;
            font-size: 13px;
            cursor: pointer;
            margin-top: 10px;
        }
        .btn-submit:hover { background: #1d4ed8; }
        .alert-error {
            background: #fff1f2;
            color: #be123c;
            border: 1px solid #fecdd3;
            padding: 10px 14px;
            border-radius: 8px;
            font-size: 13px;
            font-weight: 600;
            margin-bottom: 16px;
        }
        .back-link {
            display: block;
            text-align: center;
            margin-top: 18px;
            font-size: 13px;
            color: #64748b;
            text-decoration: none;
            font-weight: 600;
        }
        .back-link:hover { color: #0f172a; }
    </style>
</head>
<body>

<div class="card">
    <% if (team != null) { %>
        <span class="team-badge"><%= team.getFormattedTeamId() %> &bull; <%= team.getTeamName() %></span>
        <h2>Add Team Member</h2>
        <p>Assign an active staff member or developer to this operational team.</p>

        <% if (error != null) { %>
            <div class="alert-error">&#9888; <%= error %></div>
        <% } %>

        <form action="<%= request.getContextPath() %>/teams/member/add" method="post">
            <input type="hidden" name="teamId" value="<%= team.getId() %>">

            <div class="form-group">
                <label>Select Employee *</label>
                <select name="employeeId" required>
                    <option value="">-- Choose Employee --</option>
                    <% if (allEmployees != null) { 
                        for (Employee emp : allEmployees) { 
                            // Only allow staff/employees to be added as team members
                            if ("ADMIN".equalsIgnoreCase(emp.getRole()) || "MANAGER".equalsIgnoreCase(emp.getRole())) continue;
                    %>
                        <!-- Fixed: send String employee_id (e.g. EMP101) directly -->
                        <option value="<%= emp.getEmployeeId() %>">
                            <%= emp.getEmployeeId() %> - <%= emp.getName() %> (<%= emp.getDepartment() %> &bull; <%= emp.getRole() %>)
                        </option>
                    <%  } 
                       } %>
                </select>
            </div>

            <button type="submit" class="btn-submit">Confirm Member Assignment</button>
        </form>

        <a href="<%= request.getContextPath() %>/teams/view?id=<%= team.getId() %>" class="back-link">
            &larr; Cancel and Return to Team Roster
        </a>
    <% } else { %>
        <p>Invalid team selection.</p>
        <a href="<%= request.getContextPath() %>/teams/search" class="back-link">&larr; Back to Catalog</a>
    <% } %>
</div>

</body>
</html>