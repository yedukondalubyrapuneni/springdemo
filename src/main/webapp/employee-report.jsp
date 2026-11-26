<%@ page contentType="text/html;charset=UTF-8" %>
<%@ page import="com.example.demo.model.ReportItem, java.util.List" %>
<%
    List<ReportItem> records = (List<ReportItem>) request.getAttribute("records");
    String search = (String) request.getAttribute("search");
    String dept = (String) request.getAttribute("department");
    int currentPage = (request.getAttribute("currentPage") != null) ? (Integer) request.getAttribute("currentPage") : 1;
    int totalPages = (request.getAttribute("totalPages") != null) ? (Integer) request.getAttribute("totalPages") : 1;
    int totalRecords = (request.getAttribute("totalRecords") != null) ? (Integer) request.getAttribute("totalRecords") : 0;
    int pageSize = (request.getAttribute("pageSize") != null) ? (Integer) request.getAttribute("pageSize") : 10;

    String cleanSearch = search != null ? search : "";
    String cleanDept = dept != null ? dept : "ALL";
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Employee Report | EMS Enterprise</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;600;700;800&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Plus Jakarta Sans', sans-serif; background: #f8fafc; color: #0f172a; }
        .card-custom { border: 1px solid #e2e8f0; border-radius: 14px; background: #fff; padding: 24px; box-shadow: 0 1px 3px rgba(0,0,0,0.02); }
    </style>
</head>
<body class="p-4">
<div class="container card-custom">
    <div class="d-flex justify-content-between align-items-center mb-4 flex-wrap gap-2">
        <div>
            <h4 class="fw-bold mb-1">Employee Directory Report</h4>
            <p class="text-muted small mb-0">Showing <%= totalRecords %> matching personnel records across authorized departments.</p>
        </div>
        <div class="d-flex gap-2">
            <a href="<%= request.getContextPath() %>/reports/export?type=employees&search=<%= cleanSearch %>&department=<%= cleanDept %>" 
               class="btn btn-success btn-sm fw-bold">
                ⬇️ Export to CSV
            </a>
            <a href="<%= request.getContextPath() %>/reports/reports-dashboard.jsp" class="btn btn-outline-secondary btn-sm fw-bold">
                &larr; Reports Hub
            </a>
        </div>
    </div>

    <form method="get" action="<%= request.getContextPath() %>/reports/employees" class="row g-2 mb-4 align-items-center">
        <div class="col-md-4">
            <input type="text" name="search" class="form-control form-control-sm" placeholder="Search by ID or Name..." value="<%= cleanSearch %>">
        </div>
        <div class="col-md-3">
            <select name="department" class="form-select form-select-sm">
                <option value="ALL">All Departments</option>
                <option value="Engineering" <%= "Engineering".equalsIgnoreCase(cleanDept) ? "selected" : "" %>>Engineering</option>
                <option value="Human Resources" <%= "Human Resources".equalsIgnoreCase(cleanDept) ? "selected" : "" %>>Human Resources</option>
                <option value="Finance" <%= "Finance".equalsIgnoreCase(cleanDept) ? "selected" : "" %>>Finance</option>
                <option value="Executive" <%= "Executive".equalsIgnoreCase(cleanDept) ? "selected" : "" %>>Executive</option>
                <option value="Operations" <%= "Operations".equalsIgnoreCase(cleanDept) ? "selected" : "" %>>Operations</option>
            </select>
        </div>
        <div class="col-md-2">
            <select name="limit" class="form-select form-select-sm" onchange="this.form.submit()">
                <option value="5" <%= pageSize == 5 ? "selected" : "" %>>5 per page</option>
                <option value="10" <%= pageSize == 10 ? "selected" : "" %>>10 per page</option>
                <option value="25" <%= pageSize == 25 ? "selected" : "" %>>25 per page</option>
                <option value="50" <%= pageSize == 50 ? "selected" : "" %>>50 per page</option>
            </select>
        </div>
        <div class="col-md-2">
            <button type="submit" class="btn btn-primary btn-sm w-100 fw-bold">Apply Filter</button>
        </div>
        <div class="col-md-1">
            <a href="<%= request.getContextPath() %>/reports/employees" class="btn btn-light btn-sm border w-100">Reset</a>
        </div>
    </form>

    <div class="table-responsive">
        <table class="table table-bordered table-hover align-middle small mb-3">
            <thead class="table-light">
                <tr>
                    <th style="width: 15%;">Employee ID</th>
                    <th style="width: 25%;">Full Name</th>
                    <th style="width: 25%;">Corporate Email</th>
                    <th style="width: 15%;">Department</th>
                    <th style="width: 10%;">System Role</th>
                    <th style="width: 10%;">Status</th>
                </tr>
            </thead>
            <tbody>
                <% if (records != null && !records.isEmpty()) { 
                    for (ReportItem r : records) { %>
                        <tr>
                            <td><strong><%= r.getEmployeeId() %></strong></td>
                            <td><%= r.getEmployeeName() %></td>
                            <td><%= r.getTitle() %></td>
                            <td><%= r.getDepartment() != null ? r.getDepartment() : "General" %></td>
                            <td><span class="badge bg-secondary"><%= r.getRole() %></span></td>
                            <td><span class="badge bg-success"><%= r.getStatus() %></span></td>
                        </tr>
                <% } } else { %>
                    <tr>
                        <td colspan="6" class="text-center py-4 text-muted">
                            No employees match your search query or department selection.
                        </td>
                    </tr>
                <% } %>
            </tbody>
        </table>
    </div>

    <% if (totalPages > 1) { %>
        <nav class="d-flex justify-content-between align-items-center mt-3 flex-wrap gap-2">
            <span class="text-muted small">
                Page <strong><%= currentPage %></strong> of <strong><%= totalPages %></strong> (<%= totalRecords %> records total)
            </span>
            <ul class="pagination pagination-sm mb-0">
                <li class="page-item <%= currentPage <= 1 ? "disabled" : "" %>">
                    <a class="page-link" href="<%= request.getContextPath() %>/reports/employees?page=<%= currentPage - 1 %>&limit=<%= pageSize %>&search=<%= cleanSearch %>&department=<%= cleanDept %>">&laquo; Prev</a>
                </li>
                <% for (int p = 1; p <= totalPages; p++) { %>
                    <li class="page-item <%= p == currentPage ? "active" : "" %>">
                        <a class="page-link" href="<%= request.getContextPath() %>/reports/employees?page=<%= p %>&limit=<%= pageSize %>&search=<%= cleanSearch %>&department=<%= cleanDept %>"><%= p %></a>
                    </li>
                <% } %>
                <li class="page-item <%= currentPage >= totalPages ? "disabled" : "" %>">
                    <a class="page-link" href="<%= request.getContextPath() %>/reports/employees?page=<%= currentPage + 1 %>&limit=<%= pageSize %>&search=<%= cleanSearch %>&department=<%= cleanDept %>">Next &raquo;</a>
                </li>
            </ul>
        </nav>
    <% } %>
</div>
</body>
</html>