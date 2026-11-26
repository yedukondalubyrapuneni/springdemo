<%@ page contentType="text/html;charset=UTF-8" %>
<%@ page import="com.example.demo.model.Employee" %>
<%
    Employee loggedIn = (Employee) session.getAttribute("loggedInEmployee");
    if (loggedIn == null || !"ADMIN".equalsIgnoreCase(loggedIn.getRole())) {
        response.sendRedirect(request.getContextPath() + "/login");
        return;
    }
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Provision New Manager | EMS Enterprise</title>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;600;700;800&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Plus Jakarta Sans', sans-serif; background: #f8fafc; padding: 40px 20px; display: flex; justify-content: center; }
        .card { background: #fff; width: 100%; max-width: 500px; padding: 32px; border-radius: 16px; border: 1px solid #e2e8f0; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05); }
        .form-group { margin-bottom: 16px; }
        label { display: block; font-size: 11px; font-weight: 700; text-transform: uppercase; color: #64748b; margin-bottom: 6px; }
        input, select { width: 100%; height: 42px; border: 1px solid #e2e8f0; border-radius: 8px; padding: 0 12px; font-size: 13px; box-sizing: border-box; }
        .btn-submit { width: 100%; height: 44px; background: #2563eb; color: #fff; border: none; border-radius: 8px; font-weight: 700; cursor: pointer; margin-top: 10px; }
        .btn-submit:hover { background: #1d4ed8; }
        .note { font-size: 12px; color: #64748b; margin-top: 6px; }
    </style>
</head>
<body>
<div class="card">
    <h2 style="font-size: 20px; font-weight: 800; margin-bottom: 6px;">Register Team Manager</h2>
    <p style="font-size: 13px; color: #64748b; margin-bottom: 20px;">Manager ID and temporary password will be dispatched to the provided email.</p>

    <% if (request.getAttribute("message") != null) { %>
        <div style="background: #ecfdf5; color: #065f46; padding: 10px; border-radius: 6px; font-size: 13px; margin-bottom: 16px;">
            &#10004; <%= request.getAttribute("message") %>
        </div>
    <% } %>
    <% if (request.getAttribute("error") != null) { %>
        <div style="background: #fff1f2; color: #e11d48; padding: 10px; border-radius: 6px; font-size: 13px; margin-bottom: 16px;">
            &#9888; <%= request.getAttribute("error") %>
        </div>
    <% } %>

    <form action="<%= request.getContextPath() %>/admin/add-manager" method="post">
        

        <div class="form-group">
            <label>Full Name *</label>
            <input type="text" name="name" placeholder="e.g. Ramesh Varma" required>
        </div>

        <div class="form-group">
            <label>Official Email Address *</label>
            <input type="email" name="email" placeholder="ramesh.manager@company.com" required>
            <div class="note">Credentials will be delivered to this inbox.</div>
        </div>

        <div class="form-group">
            <label>Department</label>
            <select name="department" required>
                <option value="IT">IT</option>
                <option value="HR">HR</option>
                <option value="Finance">Finance</option>
                <option value="Sales">Sales</option>
            </select>
        </div>

        <div class="form-group">
            <label>Initial Temporary Password *</label>
            <input type="password" name="password" value="Pass@123" required>
        </div>

        <button type="submit" class="btn-submit">Provision Manager & Send Mail</button>
    </form>

  <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;">
    <a href="<%= request.getContextPath() %>/dashboard.jsp" 
       style="text-decoration: none; font-size: 13px; font-weight: 700; color: #2563eb; display: inline-flex; align-items: center; gap: 6px;">
        &larr; Back to Dashboard
    </a>
    <span style="font-size: 13px; color: #64748b;">Admin Console</span>
</div>
</div>
</body>
</html>