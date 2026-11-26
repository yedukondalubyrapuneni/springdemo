<%@ page contentType="text/html;charset=UTF-8" %>
<%@ page import="com.example.demo.model.ReportItem, java.util.List, java.util.Map" %>
<%
    List<ReportItem> records = (List<ReportItem>) request.getAttribute("records");
    Map<String, Integer> summary = (Map<String, Integer>) request.getAttribute("summary");
    String empId = (String) request.getAttribute("employeeId");
    String status = (String) request.getAttribute("status");
    String fromDate = (String) request.getAttribute("fromDate");
    String toDate = (String) request.getAttribute("toDate");
    int currentPage = (request.getAttribute("currentPage") != null) ? (Integer) request.getAttribute("currentPage") : 1;
    int totalPages = (request.getAttribute("totalPages") != null) ? (Integer) request.getAttribute("totalPages") : 1;
    int totalRecords = (request.getAttribute("totalRecords") != null) ? (Integer) request.getAttribute("totalRecords") : 0;
    int pageSize = (request.getAttribute("pageSize") != null) ? (Integer) request.getAttribute("pageSize") : 10;

    String cleanEmp = (empId != null) ? empId : "";
    String cleanStatus = (status != null) ? status : "ALL";
    String cleanFrom = (fromDate != null) ? fromDate : "";
    String cleanTo = (toDate != null) ? toDate : "";
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Task Report | EMS Enterprise</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Plus Jakarta Sans', sans-serif; background: #f8fafc; color: #0f172a; }
        .card-custom { border: 1px solid #e2e8f0; border-radius: 16px; background: #ffffff; padding: 24px; box-shadow: 0 1px 3px rgba(0,0,0,0.02); }
        .table th { background: #f8fafc; font-size: 11px; text-transform: uppercase; color: #64748b; font-weight: 700; padding: 12px 14px; border-bottom: 1px solid #e2e8f0; }
        .table td { padding: 12px 14px; border-bottom: 1px solid #e2e8f0; font-size: 13px; vertical-align: middle; }
        .badge-assigned { background-color: #f1f5f9; color: #475569; }
        .badge-in_progress { background-color: #eff6ff; color: #2563eb; }
        .badge-on_hold { background-color: #fef3c7; color: #b45309; }
        .badge-completed { background-color: #ecfdf5; color: #059669; }
        .badge-cancelled { background-color: #fee2e2; color: #dc2626; }

        @media print {
            nav, .navbar-custom, form, .btn, .pagination, .no-print { display: none !important; }
            body, .container, .card-custom { background: #ffffff !important; padding: 0 !important; margin: 0 !important; border: none !important; box-shadow: none !important; width: 100% !important; max-width: 100% !important; }
            .table { width: 100% !important; border-collapse: collapse !important; }
            .table th, .table td { border: 1px solid #000000 !important; color: #000000 !important; padding: 6px !important; }
            .kpi-row { display: flex !important; flex-wrap: nowrap !important; margin-bottom: 16px !important; }
            .kpi-col { border: 1px solid #ccc !important; padding: 8px !important; margin: 0 4px !important; }
        }
    </style>
</head>
<body class="p-4">
<div class="container card-custom">
    <!-- Header Strip -->
    <div class="d-flex justify-content-between align-items-center mb-3 flex-wrap gap-2">
        <div>
            <h4 class="fw-bold mb-0">Task Management Audit</h4>
            <span class="text-muted small"><%= totalRecords %> task deliverables logged</span>
        </div>
        <div class="d-flex gap-2 no-print">
            <button type="button" onclick="window.print()" class="btn btn-outline-dark btn-sm fw-bold">
                🖨️ Print / Save PDF
            </button>
            <a href="<%= request.getContextPath() %>/reports/export?type=tasks&employeeId=<%= cleanEmp %>&status=<%= cleanStatus %>&fromDate=<%= cleanFrom %>&toDate=<%= cleanTo %>" 
               class="btn btn-success btn-sm fw-bold">
                ⬇️ Export to CSV
            </a>
            <a href="<%= request.getContextPath() %>/reports-dashboard.jsp" class="btn btn-outline-secondary btn-sm fw-bold">
                &larr; Reports Hub
            </a>
        </div>
    </div>

    <!-- Summary Metrics Cards -->
    <div class="row g-2 mb-4 text-center kpi-row">
        <div class="col kpi-col"><div class="p-2 border rounded"><small class="fw-bold">ASSIGNED</small><h5 class="fw-bold mb-0"><%= (summary != null) ? summary.getOrDefault("ASSIGNED", 0) : 0 %></h5></div></div>
        <div class="col kpi-col"><div class="p-2 border rounded text-primary"><small class="fw-bold">IN PROGRESS</small><h5 class="fw-bold mb-0"><%= (summary != null) ? summary.getOrDefault("IN_PROGRESS", 0) : 0 %></h5></div></div>
        <div class="col kpi-col"><div class="p-2 border rounded text-warning"><small class="fw-bold">ON HOLD</small><h5 class="fw-bold mb-0"><%= (summary != null) ? summary.getOrDefault("ON_HOLD", 0) : 0 %></h5></div></div>
        <div class="col kpi-col"><div class="p-2 border rounded text-success"><small class="fw-bold">COMPLETED</small><h5 class="fw-bold mb-0"><%= (summary != null) ? summary.getOrDefault("COMPLETED", 0) : 0 %></h5></div></div>
        <div class="col kpi-col"><div class="p-2 border rounded text-danger"><small class="fw-bold">CANCELLED</small><h5 class="fw-bold mb-0"><%= (summary != null) ? summary.getOrDefault("CANCELLED", 0) : 0 %></h5></div></div>
    </div>

    <!-- Filter Form -->
    <form method="get" action="<%= request.getContextPath() %>/reports/tasks" class="row g-2 mb-4 align-items-center no-print">
        <div class="col-md-3">
            <input type="text" name="employeeId" class="form-control form-control-sm" placeholder="Assignee Employee ID..." value="<%= cleanEmp %>">
        </div>
        <div class="col-md-2">
            <select name="status" class="form-select form-select-sm">
                <option value="ALL">All Statuses</option>
                <option value="ASSIGNED" <%= "ASSIGNED".equalsIgnoreCase(cleanStatus) ? "selected" : "" %>>ASSIGNED</option>
                <option value="IN_PROGRESS" <%= "IN_PROGRESS".equalsIgnoreCase(cleanStatus) ? "selected" : "" %>>IN_PROGRESS</option>
                <option value="ON_HOLD" <%= "ON_HOLD".equalsIgnoreCase(cleanStatus) ? "selected" : "" %>>ON_HOLD</option>
                <option value="COMPLETED" <%= "COMPLETED".equalsIgnoreCase(cleanStatus) ? "selected" : "" %>>COMPLETED</option>
                <option value="CANCELLED" <%= "CANCELLED".equalsIgnoreCase(cleanStatus) ? "selected" : "" %>>CANCELLED</option>
            </select>
        </div>
        <div class="col-md-2">
            <input type="date" name="fromDate" class="form-control form-control-sm" value="<%= cleanFrom %>">
        </div>
        <div class="col-md-2">
            <input type="date" name="toDate" class="form-control form-control-sm" value="<%= cleanTo %>">
        </div>
        <div class="col-md-1">
            <select name="limit" class="form-select form-select-sm" onchange="this.form.submit()">
                <option value="5" <%= (pageSize == 5) ? "selected" : "" %>>5</option>
                <option value="10" <%= (pageSize == 10) ? "selected" : "" %>>10</option>
                <option value="25" <%= (pageSize == 25) ? "selected" : "" %>>25</option>
            </select>
        </div>
        <div class="col-md-1">
            <button type="submit" class="btn btn-primary btn-sm w-100 fw-bold">Filter</button>
        </div>
        <div class="col-md-1">
            <a href="<%= request.getContextPath() %>/reports/tasks" class="btn btn-light btn-sm border w-100">Reset</a>
        </div>
    </form>

    <!-- Data Grid -->
    <div class="table-responsive">
        <table class="table table-bordered table-hover align-middle mb-3">
            <thead>
                <tr>
                    <th style="width: 10%;">Task ID</th>
                    <th style="width: 25%;">Title</th>
                    <th style="width: 20%;">Assignee</th>
                    <th style="width: 12%;">Assigned Date</th>
                    <th style="width: 12%;">Due Date</th>
                    <th style="width: 9%;">Priority</th>
                    <th style="width: 12%;">Status</th>
                </tr>
            </thead>
            <tbody>
                <% if (records != null && !records.isEmpty()) { 
                    for (ReportItem r : records) { 
                        String st = (r.getStatus() != null) ? r.getStatus().toLowerCase() : "assigned";
                        String badgeClass = "badge-assigned";
                        if ("completed".equals(st)) badgeClass = "badge-completed";
                        else if ("in_progress".equals(st)) badgeClass = "badge-in_progress";
                        else if ("on_hold".equals(st)) badgeClass = "badge-on_hold";
                        else if ("cancelled".equals(st)) badgeClass = "badge-cancelled";
                %>
                        <tr>
                            <td><strong>#<%= r.getId() %></strong></td>
                            <td><strong><%= r.getTitle() %></strong></td>
                            <td><%= r.getEmployeeName() %></td>
                            <td><%= (r.getStartDate() != null) ? r.getStartDate() : "--" %></td>
                            <td><%= (r.getEndDate() != null) ? r.getEndDate() : "--" %></td>
                            <td><span class="badge bg-secondary"><%= (r.getExtra() != null) ? r.getExtra() : "NORMAL" %></span></td>
                            <td><span class="badge <%= badgeClass %>">&bull; <%= r.getStatus() %></span></td>
                        </tr>
                <% } } else { %>
                    <tr><td colspan="7" class="text-center py-4 text-muted">No task deliverables found.</td></tr>
                <% } %>
            </tbody>
        </table>
    </div>

    <!-- Pagination Controls -->
    <% if (totalPages > 1) { %>
        <nav class="d-flex justify-content-between align-items-center mt-3 flex-wrap gap-2 no-print">
            <span class="text-muted small">Page <strong><%= currentPage %></strong> of <strong><%= totalPages %></strong></span>
            <ul class="pagination pagination-sm mb-0">
                <li class="page-item <%= (currentPage <= 1) ? "disabled" : "" %>">
                    <a class="page-link" href="<%= request.getContextPath() %>/reports/tasks?page=<%= currentPage - 1 %>&limit=<%= pageSize %>&employeeId=<%= cleanEmp %>&status=<%= cleanStatus %>&fromDate=<%= cleanFrom %>&toDate=<%= cleanTo %>">&laquo; Prev</a>
                </li>
                <% for (int p = 1; p <= totalPages; p++) { %>
                    <li class="page-item <%= (p == currentPage) ? "active" : "" %>">
                        <a class="page-link" href="<%= request.getContextPath() %>/reports/tasks?page=<%= p %>&limit=<%= pageSize %>&employeeId=<%= cleanEmp %>&status=<%= cleanStatus %>&fromDate=<%= cleanFrom %>&toDate=<%= cleanTo %>"><%= p %></a>
                    </li>
                <% } %>
                <li class="page-item <%= (currentPage >= totalPages) ? "disabled" : "" %>">
                    <a class="page-link" href="<%= request.getContextPath() %>/reports/tasks?page=<%= currentPage + 1 %>&limit=<%= pageSize %>&employeeId=<%= cleanEmp %>&status=<%= cleanStatus %>&fromDate=<%= cleanFrom %>&toDate=<%= cleanTo %>">Next &raquo;</a>
                </li>
            </ul>
        </nav>
    <% } %>
</div>
</body>
</html>