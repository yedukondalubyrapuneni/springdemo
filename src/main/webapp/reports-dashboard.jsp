<%@ page contentType="text/html;charset=UTF-8" %>
<%@ page import="com.example.demo.model.Employee" %>
<%
    Employee user = (Employee) session.getAttribute("loggedInEmployee");
    if (user == null) { 
        response.sendRedirect(request.getContextPath() + "/login.jsp"); 
        return; 
    }
    boolean isEmployee = "EMPLOYEE".equalsIgnoreCase(user.getRole());
    String homeUrl = "ADMIN".equalsIgnoreCase(user.getRole()) ? "/dashboard.jsp" : 
                     ("MANAGER".equalsIgnoreCase(user.getRole()) ? "/managerDashboard.jsp" : "/employeeWorkspace.jsp");
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reports Console | EMS Enterprise</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        :root {
            --brand-primary: #2563eb;
            --surface-bg: #f8fafc;
            --border-subtle: #e2e8f0;
            --text-main: #0f172a;
            --text-muted: #64748b;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: 'Plus Jakarta Sans', sans-serif; background: var(--surface-bg); color: var(--text-main); }
        .navbar-custom { background: #ffffff; border-bottom: 1px solid var(--border-subtle); padding: 14px 32px; }
        .report-card { border: 1px solid var(--border-subtle); border-radius: 16px; background: #ffffff; transition: all 0.2s ease; box-shadow: 0 1px 3px rgba(0,0,0,0.02); }
        .report-card:hover { transform: translateY(-3px); box-shadow: 0 10px 20px -5px rgba(0,0,0,0.06); }
        .icon-tile { width: 44px; height: 44px; border-radius: 10px; display: flex; align-items: center; justify-content: center; font-size: 20px; margin-bottom: 16px; }
        .tile-green { background: #ecfdf5; color: #059669; }
        .tile-amber { background: #fef3c7; color: #b45309; }
        .tile-purple { background: #f5f3ff; color: #7c3aed; }
        .btn-brand { background: var(--brand-primary); color: #ffffff; font-weight: 700; border-radius: 8px; border: none; padding: 8px 16px; text-decoration: none; display: inline-block; text-align: center; }
        .btn-brand:hover { background: #1d4ed8; color: #ffffff; }
    </style>
</head>
<body>
    <header class="navbar-custom d-flex justify-content-between align-items-center">
        <div class="d-flex align-items-center gap-2">
            <span style="font-weight: 800; font-size: 18px; color: var(--brand-primary);">EMS</span>
            <span style="font-weight: 800; font-size: 18px; color: var(--text-main);">Enterprise</span>
            <span class="text-muted ms-2 ps-2 border-start small">Reporting Hub</span>
        </div>
        <div class="d-flex align-items-center gap-3">
            <span class="text-muted small">Logged in: <strong><%= user.getName() %></strong> (<%= user.getRole() %>)</span>
            <a href="<%= request.getContextPath() %><%= homeUrl %>" class="btn btn-sm btn-outline-secondary fw-bold">&larr; Back to Workspace</a>
        </div>
    </header>

    <main class="container py-5" style="max-width: 1100px;">
        <div class="mb-4">
            <h3 class="fw-bold mb-1">Operational Reports</h3>
            <p class="text-muted small">Filter historical records, review departmental KPIs, and generate spreadsheet or print-ready exports.</p>
        </div>

        <div class="row g-4 justify-content-center">
            <!-- 1. Attendance Audit Report -->
            <div class="col-md-6 col-lg-4">
                <div class="card report-card h-100 p-4 d-flex flex-column">
                    <div class="icon-tile tile-green">⏱️</div>
                    <h5 class="fw-bold mb-2">Attendance</h5>
                    <p class="text-muted small mb-4 flex-grow-1">
                        <%= isEmployee ? "View and verify your shift punch records, check-ins, and duration." : "Daily shift logs, timestamps, and overall present versus absent summaries." %>
                    </p>
                    <a href="<%= request.getContextPath() %>/reports/attendance" class="btn btn-brand btn-sm w-100">Open Report</a>
                </div>
            </div>

            <!-- 2. Leave Requests Report -->
            <div class="col-md-6 col-lg-4">
                <div class="card report-card h-100 p-4 d-flex flex-column">
                    <div class="icon-tile tile-amber">🌴</div>
                    <h5 class="fw-bold mb-2">Leaves</h5>
                    <p class="text-muted small mb-4 flex-grow-1">
                        <%= isEmployee ? "Track your submitted absence tickets, approvals, and reasons." : "Absence approvals, submitted leave tickets, reasons, and allocation summaries." %>
                    </p>
                    <a href="<%= request.getContextPath() %>/reports/leaves" class="btn btn-brand btn-sm w-100">Open Report</a>
                </div>
            </div>

            <!-- 3. Task Performance Report (Admin & Manager Only) -->
            <% if (!isEmployee) { %>
            <div class="col-md-6 col-lg-4">
                <div class="card report-card h-100 p-4 d-flex flex-column">
                    <div class="icon-tile tile-purple">📋</div>
                    <h5 class="fw-bold mb-2">Tasks</h5>
                    <p class="text-muted small mb-4 flex-grow-1">Deliverables audits, deadline tracking, manager ratings, and completion metrics.</p>
                    <a href="<%= request.getContextPath() %>/reports/tasks" class="btn btn-brand btn-sm w-100">Open Report</a>
                </div>
            </div>
            <% } %>
        </div>
    </main>
</body>
</html>