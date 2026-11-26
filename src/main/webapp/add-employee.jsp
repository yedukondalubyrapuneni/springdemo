<%@ page contentType="text/html;charset=UTF-8" %>
<%@ page import="com.example.demo.model.Employee" %>
<%
    Employee loggedIn = (Employee) session.getAttribute("loggedInEmployee");
    if (loggedIn == null) {
        response.sendRedirect(request.getContextPath() + "/login");
        return;
    }
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Add Employee - EMS</title>
    <style>
        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background-color: #f5f7fa;
            color: #333333;
            padding: 40px 20px;
            display: flex;
            justify-content: center;
            align-items: flex-start;
            min-height: 100vh;
        }

        .card {
            background: #ffffff;
            width: 100%;
            max-width: 520px;
            padding: 35px 40px;
            border-radius: 12px;
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.08);
        }

        .admin-badge {
            background: #eef2f7;
            border-left: 4px solid #007bff;
            padding: 10px 14px;
            border-radius: 4px;
            margin-bottom: 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            font-size: 13px;
        }

        .admin-badge a {
            color: #dc3545;
            text-decoration: none;
            font-weight: 600;
        }

        .header {
            text-align: center;
            margin-bottom: 24px;
        }

        .header h1 {
            font-size: 24px;
            font-weight: 700;
            color: #1a202c;
            letter-spacing: -0.5px;
        }

        .header p {
            color: #718096;
            font-size: 14px;
            margin-top: 6px;
        }

        .alert {
            padding: 12px 16px;
            border-radius: 6px;
            font-size: 14px;
            margin-bottom: 22px;
            line-height: 1.5;
        }

        .alert-success {
            background-color: #d4edda;
            color: #155724;
            border: 1px solid #c3e6cb;
        }

        .alert-error {
            background-color: #f8d7da;
            color: #721c24;
            border: 1px solid #f5c6cb;
        }

        .form-group {
            margin-bottom: 18px;
        }

        label {
            display: block;
            font-size: 13px;
            font-weight: 600;
            color: #4a5568;
            margin-bottom: 8px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }

        .input-control {
            width: 100%;
            padding: 11px 14px;
            border: 1.5px solid #e2e8f0;
            border-radius: 6px;
            font-size: 14px;
            color: #2d3748;
            background-color: #ffffff;
            transition: all 0.2s ease-in-out;
        }

        .input-control:focus {
            outline: none;
            border-color: #007bff;
            box-shadow: 0 0 0 3px rgba(0, 123, 255, 0.15);
        }

        select.input-control {
            cursor: pointer;
        }

        .btn-submit {
            width: 100%;
            padding: 13px;
            background-color: #28a745;
            color: #ffffff;
            font-size: 15px;
            font-weight: 600;
            border: none;
            border-radius: 6px;
            cursor: pointer;
            transition: background-color 0.2s ease;
            margin-top: 10px;
        }

        .btn-submit:hover {
            background-color: #218838;
        }

        .btn-submit:active {
            transform: translateY(1px);
        }

        .footer-action {
            margin-top: 25px;
            text-align: center;
            border-top: 1px solid #edf2f7;
            padding-top: 20px;
        }

        .back-link {
            display: inline-flex;
            align-items: center;
            color: #007bff;
            font-size: 14px;
            font-weight: 600;
            text-decoration: none;
            transition: color 0.2s ease;
        }

        .back-link:hover {
            color: #0056b3;
            text-decoration: underline;
        }
    </style>
</head>
<body>

<div class="card">
    <div class="admin-badge">
        <span>Logged in as Admin: <strong><%= loggedIn.getName() %></strong></span>
        <a href="<%= request.getContextPath() %>/logout">Sign Out</a>
    </div>

    <div class="header">
        <h1>Register New Employee</h1>
        <p>Create credentials and assign system roles</p>
    </div>

    <!-- Success Message -->
    <% if (request.getAttribute("message") != null) { %>
        <div class="alert alert-success">
            &#10004; <%= request.getAttribute("message") %>
        </div>
    <% } %>

    <!-- Error Message -->
    <% if (request.getAttribute("error") != null) { %>
        <div class="alert alert-error">
            &#9888; <%= request.getAttribute("error") %>
        </div>
    <% } %>

    <form action="<%= request.getContextPath() %>/employee/add" method="post" autocomplete="off">
        <div class="form-group">
            <label for="employeeId">Employee ID</label>
            <input type="text" 
                   id="employeeId" 
                   name="employeeId" 
                   class="input-control" 
                   placeholder="e.g. EMP109" 
                   required>
        </div>

        <div class="form-group">
            <label for="name">Full Name</label>
            <input type="text" 
                   id="name" 
                   name="name" 
                   class="input-control" 
                   placeholder="e.g. Rajesh Kumar" 
                   required>
        </div>

        <div class="form-group">
            <label for="department">Department</label>
            <select id="department" name="department" class="input-control" required>
                <option value="" disabled selected>-- Select Department --</option>
                <option value="Engineering">Engineering</option>
                <option value="Human Resources">Human Resources</option>
                <option value="Finance">Finance</option>
                <option value="Sales & Marketing">Sales & Marketing</option>
                <option value="Operations">Operations</option>
                <option value="IT Support">IT Support</option>
            </select>
        </div>

        <!-- Role Selection -->
        <div class="form-group">
            <label for="role">System Role</label>
            <select id="role" name="role" class="input-control" required>
                <option value="EMPLOYEE" selected>Standard Employee (Punches Attendance)</option>
                <option value="HR">HR Manager (Reports & Dashboards)</option>
                <option value="ADMIN">System Admin (Full Access)</option>
            </select>
        </div>

        <!-- Initial Password -->
        <div class="form-group">
            <label for="password">Initial Password</label>
            <input type="password" 
                   id="password" 
                   name="password" 
                   class="input-control" 
                   placeholder="Default: 123456" 
                   value="123456" 
                   required>
        </div>

        <button type="submit" class="btn-submit">Add Employee</button>
    </form>

<<div class="footer-action">
        <a class="back-link" href="<%= request.getContextPath() %>/attendance/dashboard">
           &larr; Back to Dashboard
        </a>
    </div>
</body>
</html>