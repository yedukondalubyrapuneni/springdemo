<%@ page contentType="text/html;charset=UTF-8" %>
<%@ page import="com.example.demo.model.Employee,com.example.demo.model.Task, java.util.List" %>
<%
    Employee admin = (Employee) session.getAttribute("loggedInEmployee");
    List<Task> allTasks = (List<Task>) request.getAttribute("allTasks");

    int totalTasks = (allTasks != null) ? allTasks.size() : 0;
    int completedCount = 0;
    int pendingCount = 0;
    int ratedCount = 0;
    double totalRatingSum = 0.0;

    if (allTasks != null) {
        for (Task t : allTasks) {
            if ("COMPLETED".equalsIgnoreCase(t.getStatus())) {
                completedCount++;
            } else {
                pendingCount++;
            }
            if (t.getRating() != null && t.getRating() > 0) {
                ratedCount++;
                totalRatingSum += t.getRating();
            }
        }
    }

    double avgRating = (ratedCount > 0) ? (totalRatingSum / ratedCount) : 0.0;
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Admin - Task & Team Performance Monitor | EMS Enterprise</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        :root {
            --brand-primary: #2563eb;
            --border-subtle: #e2e8f0;
            --text-main: #0f172a;
            --text-muted: #64748b;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: 'Plus Jakarta Sans', sans-serif; background: #f8fafc; color: var(--text-main); }
        .navbar { display: flex; justify-content: space-between; align-items: center; padding: 14px 32px; background: #fff; border-bottom: 1px solid var(--border-subtle); }
        .container { max-width: 1320px; margin: 24px auto; padding: 0 20px; display: flex; flex-direction: column; gap: 24px; }
        .card { background: #fff; border: 1px solid var(--border-subtle); border-radius: 16px; padding: 24px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.03); }
        .grid-4 { display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; }
        .stat-card { background: #f8fafc; border: 1px solid var(--border-subtle); border-radius: 12px; padding: 18px; text-align: center; }
        .stat-num { font-size: 26px; font-weight: 800; color: var(--text-main); margin-top: 4px; }
        .stat-label { font-size: 11px; font-weight: 700; text-transform: uppercase; color: var(--text-muted); }
        .badge-pill { padding: 4px 12px; border-radius: 20px; font-size: 11px; font-weight: 700; display: inline-flex; align-items: center; }
        .badge-green { background: #ecfdf5; color: #059669; }
        .badge-amber { background: #fef3c7; color: #b45309; }
        .badge-gray { background: #f1f5f9; color: #475569; }
        .badge-blue { background: #eff6ff; color: #2563eb; }
        .badge-purple { background: #f5f3ff; color: #7c3aed; }
        .readonly-tag { background: #fee2e2; color: #991b1b; border: 1px solid #fecaca; padding: 4px 10px; border-radius: 6px; font-size: 11px; font-weight: 800; }
        .form-input { height: 36px; border: 1px solid var(--border-subtle); border-radius: 8px; padding: 0 12px; font-size: 13px; outline: none; }
        .form-input:focus { border-color: var(--brand-primary); }
        table { width: 100%; border-collapse: collapse; margin-top: 14px; font-size: 13px; }
        th { text-align: left; padding: 10px 12px; background: #f8fafc; color: var(--text-muted); font-weight: 700; font-size: 11px; text-transform: uppercase; border-bottom: 1px solid var(--border-subtle); }
        td { padding: 12px; border-bottom: 1px solid var(--border-subtle); vertical-align: middle; }
        .file-link { color: #2563eb; text-decoration: none; font-weight: 700; font-size: 11px; display: inline-flex; align-items: center; gap: 4px; }
        .file-link:hover { text-decoration: underline; }
        .feedback-bubble { background: #fef3c7; color: #92400e; padding: 4px 8px; border-radius: 6px; font-size: 11px; display: inline-block; }
    </style>
</head>
<body>

    <header class="navbar">
        <div style="font-size: 15px; font-weight: 800;">
            <span style="color: var(--brand-primary);">EMS Enterprise</span> &bull; Executive Admin Console
        </div>
        <div style="display: flex; align-items: center; gap: 18px; font-size: 13px;">
            <span>Logged in as: <strong><%= (admin != null) ? admin.getName() : "Admin" %> (<%= (admin != null) ? admin.getEmployeeId() : "" %>)</strong></span>
            <a href="<%= request.getContextPath() %>/logout" style="color: #ef4444; font-weight: 700; text-decoration: none;">Sign Out</a>
        </div>
    </header>

    <div class="container">

        <!-- Top Header Card -->
        <div class="card" style="display: flex; justify-content: space-between; align-items: center;">
            <div>
                <h2 style="font-size: 18px; font-weight: 800; margin-bottom: 4px;">Company-Wide Task & Performance Monitor</h2>
                <p style="font-size: 12px; color: var(--text-muted);">
                    Comprehensive view of all teams, employee deliverables, document submissions, manager ratings, and quality feedback.
                </p>
            </div>
            <div>
                <span class="readonly-tag">&#128274; READ-ONLY AUDIT MODE</span>
            </div>
        </div>

        <!-- Metric KPI Cards -->
        <div class="grid-4">
            <div class="stat-card">
                <div class="stat-label">Total Allocated Tasks</div>
                <div class="stat-num"><%= totalTasks %></div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Completed Deliverables</div>
                <div class="stat-num" style="color: #059669;"><%= completedCount %></div>
            </div>
            <div class="stat-card">
                <div class="stat-label">In-Progress / Pending</div>
                <div class="stat-num" style="color: #2563eb;"><%= pendingCount %></div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Average Quality Rating</div>
                <div class="stat-num" style="color: #d97706;">
                    <%= (ratedCount > 0) ? String.format("%.1f", avgRating) + " ★" : "--" %>
                </div>
            </div>
        </div>

        <!-- Filter & Search Toolbar -->
        <div class="card">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; flex-wrap: wrap; gap: 10px;">
                <h3 style="font-size: 16px; font-weight: 800;">Team Tasks & Ratings Audit Log</h3>
                <div style="display: flex; gap: 8px;">
                    <input type="text" id="adminSearchInput" onkeyup="filterAdminTasks()" class="form-input" placeholder="Search task, employee, manager..." style="width: 260px;">
                    <select id="statusFilter" onchange="filterAdminTasks()" class="form-input" style="width: 140px;">
                        <option value="ALL">All Statuses</option>
                        <option value="COMPLETED">COMPLETED</option>
                        <option value="IN_PROGRESS">IN_PROGRESS</option>
                        <option value="SUBMITTED_FOR_REVIEW">SUBMITTED</option>
                        <option value="REVISION_NEEDED">REVISION</option>
                        <option value="ASSIGNED">ASSIGNED</option>
                    </select>
                </div>
            </div>

            <table id="adminTasksTable">
                <thead>
                    <tr>
                        <th style="width: 10%;">Task ID</th>
                        <th style="width: 22%;">Task & Briefing</th>
                        <th style="width: 12%;">Assigned Employee</th>
                        <th style="width: 10%;">Manager</th>
                        <th style="width: 12%;">Status</th>
                        <th style="width: 14%;">Submission Proof</th>
                        <th style="width: 20%;">Manager Rating & Feedback</th>
                    </tr>
                </thead>
                <tbody>
                    <% if (allTasks != null && !allTasks.isEmpty()) { 
                        for (Task t : allTasks) { 
                            String sClass = "badge-gray";
                            if ("COMPLETED".equalsIgnoreCase(t.getStatus())) sClass = "badge-green";
                            else if ("IN_PROGRESS".equalsIgnoreCase(t.getStatus())) sClass = "badge-blue";
                            else if ("SUBMITTED_FOR_REVIEW".equalsIgnoreCase(t.getStatus())) sClass = "badge-purple";
                            else if ("REVISION_NEEDED".equalsIgnoreCase(t.getStatus())) sClass = "badge-amber";
                    %>
                            <tr class="admin-task-row">
                                <td><strong><%= t.getFormattedTaskId() %></strong></td>
                                <td>
                                    <strong><%= (t.getTaskTitle() != null ? t.getTaskTitle() : "") %></strong>
                                    <% if (t.getDescription() != null && !t.getDescription().isBlank()) { %>
                                        <div style="font-size: 11px; color: var(--text-muted); margin-top: 2px;"><%= t.getDescription() %></div>
                                    <% } %>
                                    <% if (t.getTaskFilePath() != null && !t.getTaskFilePath().isBlank()) { %>
                                        <div style="margin-top: 4px;">
                                            <a href="<%= request.getContextPath() %>/uploads/tasks/<%= t.getTaskFilePath() %>" target="_blank" class="file-link">&#128206; Manager Briefing File</a>
                                        </div>
                                    <% } %>
                                </td>
                                <td>
                                    <strong><%= (t.getAssignedToName() != null ? t.getAssignedToName() : t.getAssignedTo()) %></strong>
                                </td>
                                <td>
                                    <%= (t.getCreatedByName() != null ? t.getCreatedByName() : "Manager") %>
                                </td>
                                <td>
                                    <span class="badge-pill <%= sClass %>">&bull; <%= t.getStatus() %></span>
                                </td>
                                <td>
                                    <% if (t.getSubmissionFilePath() != null && !t.getSubmissionFilePath().isBlank()) { %>
                                        <a href="<%= request.getContextPath() %>/uploads/submissions/<%= t.getSubmissionFilePath() %>" target="_blank" class="file-link" style="color: #059669;">
                                            &#128196; View Submitted Doc
                                        </a>
                                        <% if (t.getEmployeeComment() != null && !t.getEmployeeComment().isBlank()) { %>
                                            <div style="font-size: 11px; color: var(--text-muted); margin-top: 2px;">Note: "<%= t.getEmployeeComment() %>"</div>
                                        <% } %>
                                    <% } else { %>
                                        <span style="color: var(--text-muted); font-size: 11px;">No submission</span>
                                    <% } %>
                                </td>
                                <td>
                                    <% if (t.getRating() != null && t.getRating() > 0) { %>
                                        <div style="color: #f59e0b; font-weight: 800; font-size: 12px;">
                                            <%= "★".repeat(t.getRating()) + "☆".repeat(5 - t.getRating()) %> (<%= t.getRating() %>/5)
                                        </div>
                                    <% } else { %>
                                        <span style="color: var(--text-muted); font-size: 11px;">Not rated</span>
                                    <% } %>
                                    <% if (t.getManagerFeedback() != null && !t.getManagerFeedback().isBlank()) { %>
                                        <div class="feedback-bubble" style="margin-top: 4px;">
                                            <%= t.getManagerFeedback() %>
                                        </div>
                                    <% } %>
                                </td>
                            </tr>
                    <%  } 
                       } else { %>
                            <tr><td colspan="7" style="text-align: center; color: var(--text-muted); padding: 24px;">No company tasks recorded.</td></tr>
                    <% } %>
                </tbody>
            </table>
        </div>

    </div>

    <script>
    function filterAdminTasks() {
        var query = document.getElementById('adminSearchInput').value.toLowerCase();
        var status = document.getElementById('statusFilter').value.toUpperCase();
        var rows = document.querySelectorAll('.admin-task-row');

        rows.forEach(function(row) {
            var text = row.innerText.toLowerCase();
            var matchesQuery = text.includes(query);
            var matchesStatus = (status === 'ALL') || text.includes(status.toLowerCase());

            if (matchesQuery && matchesStatus) {
                row.style.display = '';
            } else {
                row.style.display = 'none';
            }
        });
    }
    </script>
</body>
</html>