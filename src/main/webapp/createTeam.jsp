<%@ page contentType="text/html;charset=UTF-8" %>
<%@ page import="com.example.demo.model.Employee" %>
<%@ page import="com.Util.DBConnection" %>
<%@ page import="java.sql.Connection, java.sql.PreparedStatement, java.sql.ResultSet" %>
<%@ page import="java.util.List, java.util.ArrayList" %>

<%
    Employee loggedIn = (Employee) session.getAttribute("loggedInEmployee");
    if (loggedIn == null) {
        response.sendRedirect(request.getContextPath() + "/login.jsp");
        return;
    }

    List<Employee> allEmployees = (List<Employee>) request.getAttribute("allEmployees");
    if (allEmployees == null || allEmployees.isEmpty()) {
        allEmployees = new ArrayList<>();
        
        // Multi-tier direct queries that match your exact schema without metadata sensitivity
        String[] candidateQueries = {
            // Option 1: Standard 'employees' table with 'role'
            "SELECT employee_id, name, role FROM employees WHERE UPPER(role) LIKE '%MGR%' OR UPPER(role) LIKE '%MAN%'",
            // Option 2: 'employees' table with 'designation'
            "SELECT employee_id, name, designation FROM employees WHERE UPPER(designation) LIKE '%MGR%' OR UPPER(designation) LIKE '%MAN%'",
            // Option 3: Singular 'employee' table with 'role'
            "SELECT employee_id, name, role FROM employee WHERE UPPER(role) LIKE '%MGR%' OR UPPER(role) LIKE '%MAN%'",
            // Option 4: Singular 'employee' table with 'designation'
            "SELECT employee_id, name, designation FROM employee WHERE UPPER(designation) LIKE '%MGR%' OR UPPER(designation) LIKE '%MAN%'",
            // Option 5: Any employee who assigned tasks
            "SELECT DISTINCT e.employee_id, e.name, 'MANAGER' as role FROM employees e JOIN tasks t ON e.employee_id = t.assigned_by",
            // Option 6: Fallback - load all employees from 'employees'
            "SELECT employee_id, name, 'MANAGER' as role FROM employees",
            // Option 7: Fallback - load all employees from 'employee'
            "SELECT employee_id, name, 'MANAGER' as role FROM employee"
        };

        try (Connection conn = DBConnection.getConnection()) {
            for (String sql : candidateQueries) {
                try (PreparedStatement ps = conn.prepareStatement(sql);
                     ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        Employee emp = new Employee();
                        emp.setEmployeeId(rs.getString("employee_id"));
                        emp.setName(rs.getString("name"));
                        try {
                            emp.setRole(rs.getString(3));
                        } catch (Exception ex) {
                            emp.setRole("MANAGER");
                        }
                        allEmployees.add(emp);
                    }
                    if (!allEmployees.isEmpty()) {
                        System.out.println("createTeam.jsp successfully loaded " + allEmployees.size() + " managers using: " + sql);
                        break; // Stop at the first query that returns records
                    }
                } catch (Exception ignored) {
                    // Try next candidate query
                }
            }
        } catch (Exception e) {
            System.err.println("Error loading managers in createTeam.jsp: " + e.getMessage());
        }
    }
%>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Create Team | EMS Enterprise</title>
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
            --rose-surface: #fff1f2;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: 'Plus Jakarta Sans', sans-serif;
            background: var(--surface-bg);
            color: var(--text-main);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 24px;
        }
        .form-card {
            width: 100%;
            max-width: 500px;
            background: var(--card-bg);
            border: 1px solid var(--border);
            border-radius: 16px;
            padding: 32px;
            box-shadow: 0 10px 25px -5px rgba(0,0,0,0.05);
        }
        .form-card h2 {
            font-size: 20px;
            font-weight: 800;
            margin-bottom: 6px;
        }
        .sub-desc {
            font-size: 13px;
            color: var(--text-muted);
            margin-bottom: 22px;
        }
        .alert-error {
            background: var(--rose-surface);
            border: 1px solid #fecdd3;
            color: #9f1239;
            padding: 10px 14px;
            border-radius: 8px;
            font-size: 13px;
            font-weight: 600;
            margin-bottom: 18px;
        }
        .form-group {
            margin-bottom: 16px;
        }
        label {
            display: block;
            font-size: 11px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: var(--text-muted);
            margin-bottom: 6px;
        }
        input, select, textarea {
            width: 100%;
            padding: 10px 14px;
            border: 1px solid var(--border);
            border-radius: 8px;
            font-size: 13px;
            font-family: inherit;
            outline: none;
            background: #ffffff;
            transition: all 0.2s;
        }
        input:focus, select:focus, textarea:focus {
            border-color: var(--brand);
            box-shadow: 0 0 0 3px rgba(37,99,235,0.15);
        }
        .btn-submit {
            width: 100%;
            padding: 12px;
            background: var(--brand);
            color: #fff;
            border: none;
            border-radius: 8px;
            font-size: 14px;
            font-weight: 700;
            cursor: pointer;
            margin-top: 10px;
            transition: background 0.2s;
        }
        .btn-submit:hover { background: var(--brand-hover); }
        .back-link {
            display: block;
            text-align: center;
            margin-top: 16px;
            font-size: 13px;
            color: var(--brand);
            text-decoration: none;
            font-weight: 700;
        }
        .back-link:hover { text-decoration: underline; }
    </style>
</head>
<body>

<div class="form-card">
    <h2>CREATE TEAM</h2>
    <p class="sub-desc">Define a new operational department team and allocate leadership.</p>

    <% if (request.getAttribute("error") != null) { %>
        <div class="alert-error">&#9888; <%= request.getAttribute("error") %></div>
    <% } %>

    <form action="<%= request.getContextPath() %>/teams/create" method="post">
        <div class="form-group">
            <label>Team Name *</label>
            <input type="text" name="teamName" placeholder="e.g. Java Development Team" required>
        </div>

        <div class="form-group">
            <label>Description (Max 500 characters)</label>
            <textarea name="description" rows="3" placeholder="Backend development team"></textarea>
        </div>

        <div class="form-group">
            <label>Department *</label>
            <select name="departmentId" required>
                <option value="">-- Select Department --</option>
                <option value="1">Engineering / IT</option>
                <option value="2">Human Resources (HR)</option>
                <option value="3">Operations</option>
                <option value="4">Finance</option>
                <option value="5">Sales & Marketing</option>
            </select>
        </div>

        <div class="form-group">
            <label>Team Manager *</label>
            <select name="managerId" required>
                <option value="">-- Select Manager --</option>
                <% if (allEmployees != null && !allEmployees.isEmpty()) { 
                    for (Employee emp : allEmployees) { 
                        String val = emp.getEmployeeId() != null && !emp.getEmployeeId().isBlank() 
                                     ? emp.getEmployeeId() 
                                     : String.valueOf(emp.getId());
                %>
                        <option value="<%= val %>">
                            <%= emp.getName() %> (<%= emp.getEmployeeId() != null ? emp.getEmployeeId() : (emp.getRole() != null ? emp.getRole() : "Manager") %>)
                        </option>
                <%  } 
                   } else { %>
                    <option disabled>No registered managers found</option>
                <% } %>
            </select>
        </div>

        <div class="form-group">
            <label>Status *</label>
            <select name="status">
                <option value="ACTIVE" selected>ACTIVE</option>
                <option value="INACTIVE">INACTIVE</option>
            </select>
        </div>

        <button type="submit" class="btn-submit">Create Team</button>
    </form>

    <a href="<%= request.getContextPath() %>/dashboard.jsp" class="back-link">
        &larr; Back to Dashboard
    </a>
</div>

</body>
</html>