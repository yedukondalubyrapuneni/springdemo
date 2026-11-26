<%@ page contentType="text/html;charset=UTF-8" %>
<%@ page import="com.example.demo.model.ReportItem, java.util.List, java.util.Map" %>
<%
    List<ReportItem> records = (List<ReportItem>) request.getAttribute("records");
    Map<String, Integer> summary = (Map<String, Integer>) request.getAttribute("summary");
    String empId = (String) request.getAttribute("employeeId");
    String status = (String) request.getAttribute("status");
    String fromDate = (String) request.getAttribute("fromDate");
    String toDate = (String) request.getAttribute("toDate");
    String userRole = (String) request.getAttribute("userRole");
    boolean isEmployee = "EMPLOYEE".equalsIgnoreCase(userRole);

    int currentPage = (request.getAttribute("currentPage") != null) ? (Integer) request.getAttribute("currentPage") : 1;
    int totalPages = (request.getAttribute("totalPages") != null) ? (Integer) request.getAttribute("totalPages") : 1;
    int totalRecords = (request.getAttribute("totalRecords") != null) ? (Integer) request.getAttribute("totalRecords") : 0;
    int pageSize = (request.getAttribute("pageSize") != null) ? (Integer) request.getAttribute("pageSize") : 10;

    String cleanEmp = (empId != null) ? empId : "";
    String cleanStatus = (status != null) ? status : "ALL";
    String cleanFrom = (fromDate != null) ? fromDate : "";
    String cleanTo = (toDate != null) ? toDate : "";

    int pendingCount = (summary != null) ? summary.getOrDefault("PENDING", 0) : 0;
    int approvedCount = (summary != null) ? summary.getOrDefault("APPROVED", 0) : 0;
    int rejectedCount = (summary != null) ? summary.getOrDefault("REJECTED", 0) : 0;
    int cancelledCount = (summary != null) ? summary.getOrDefault("CANCELLED", 0) : 0;
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><%= isEmployee ? "My Leave Audit" : "Leave Allocations Audit" %> | EMS Enterprise</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@500;600&display=swap" rel="stylesheet">
    <style>
        :root {
            --brand-primary: #1e40af;
            --brand-accent: #3b82f6;
            --brand-soft: #eff6ff;
            --slate-50: #f8fafc;
            --slate-100: #f1f5f9;
            --slate-200: #e2e8f0;
            --slate-300: #cbd5e1;
            --slate-400: #94a3b8;
            --slate-500: #64748b;
            --slate-600: #475569;
            --slate-700: #334155;
            --slate-800: #1e293b;
            --slate-900: #0f172a;
            --success-border: #bbf7d0;
            --success-bg: #f0fdf4;
            --success-text: #15803d;
            --danger-border: #fecaca;
            --danger-bg: #fef2f2;
            --danger-text: #b91c1c;
            --warning-border: #fef08a;
            --warning-bg: #fefce8;
            --warning-text: #a16207;
            --shadow-subtle: 0 1px 3px 0 rgba(15, 23, 42, 0.04), 0 1px 2px -1px rgba(15, 23, 42, 0.04);
            --shadow-card: 0 4px 6px -1px rgba(15, 23, 42, 0.04), 0 2px 4px -2px rgba(15, 23, 42, 0.03);
            --radius-md: 10px;
            --radius-lg: 14px;
        }

        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, sans-serif;
            background-color: var(--slate-50);
            color: var(--slate-900);
            padding: 36px 28px;
            -webkit-font-smoothing: antialiased;
            line-height: 1.5;
        }

        .container { max-width: 1280px; margin: 0 auto; }

        .page-meta {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
            font-size: 13px;
        }
        .breadcrumb {
            display: flex;
            align-items: center;
            gap: 8px;
            color: var(--slate-500);
            font-weight: 500;
        }
        .breadcrumb a { color: var(--slate-500); text-decoration: none; transition: color 0.15s ease; }
        .breadcrumb a:hover { color: var(--brand-primary); }
        .breadcrumb-sep { color: var(--slate-400); font-size: 11px; }
        .breadcrumb-active { color: var(--slate-800); font-weight: 700; }

        .audit-card {
            background: #ffffff;
            border: 1px solid var(--slate-200);
            border-radius: var(--radius-lg);
            padding: 28px 32px;
            box-shadow: var(--shadow-card);
        }

        .header-strip {
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            flex-wrap: wrap;
            gap: 20px;
            padding-bottom: 24px;
            border-bottom: 1px solid var(--slate-200);
            margin-bottom: 28px;
        }
        .title-block h1 {
            font-size: 22px;
            font-weight: 800;
            letter-spacing: -0.02em;
            color: var(--slate-900);
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .title-tag {
            font-size: 11px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            padding: 3px 8px;
            background: var(--brand-soft);
            color: var(--brand-primary);
            border-radius: 6px;
        }
        .title-block p {
            font-size: 13.5px;
            color: var(--slate-500);
            margin-top: 4px;
        }

        .actions-group { display: flex; gap: 10px; flex-wrap: wrap; align-items: center; }

        .btn {
            font-family: inherit;
            font-size: 12.5px;
            font-weight: 700;
            padding: 8px 16px;
            border-radius: 8px;
            border: 1px solid transparent;
            cursor: pointer;
            text-decoration: none;
            display: inline-flex;
            align-items: center;
            gap: 8px;
            transition: all 0.15s ease;
            box-shadow: var(--shadow-subtle);
        }
        .btn svg { width: 14px; height: 14px; stroke-width: 2.2; }
        .btn-outline { background: #ffffff; border-color: var(--slate-300); color: var(--slate-700); }
        .btn-outline:hover { background: var(--slate-50); border-color: var(--slate-400); color: var(--slate-900); }
        .btn-success { background: #059669; color: #ffffff; }
        .btn-success:hover { background: #047857; }
        .btn-primary { background: var(--brand-primary); color: #ffffff; }
        .btn-primary:hover { background: #172554; }

        .kpi-grid {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 18px;
            margin-bottom: 28px;
        }
        .kpi-card {
            border: 1px solid var(--slate-200);
            border-radius: var(--radius-md);
            padding: 18px 20px;
            background: #ffffff;
            position: relative;
        }
        .kpi-top {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 8px;
        }
        .kpi-label {
            font-size: 11.5px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: var(--slate-500);
        }
        .kpi-icon-wrapper {
            width: 28px;
            height: 28px;
            border-radius: 6px;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .kpi-amber .kpi-icon-wrapper { background: var(--warning-bg); color: var(--warning-text); }
        .kpi-green .kpi-icon-wrapper { background: var(--success-bg); color: var(--success-text); }
        .kpi-red .kpi-icon-wrapper   { background: var(--danger-bg);  color: var(--danger-text); }
        .kpi-gray .kpi-icon-wrapper  { background: var(--slate-100);  color: var(--slate-600); }

        .kpi-value {
            font-size: 28px;
            font-weight: 800;
            color: var(--slate-900);
            letter-spacing: -0.02em;
            line-height: 1.1;
        }
        .kpi-subtext { font-size: 11.5px; color: var(--slate-400); margin-top: 6px; }

        .filter-panel {
            background: var(--slate-50);
            border: 1px solid var(--slate-200);
            border-radius: var(--radius-md);
            padding: 14px 18px;
            margin-bottom: 24px;
            display: flex;
            flex-wrap: wrap;
            gap: 12px;
            align-items: center;
        }
        .input-group { display: flex; flex-direction: column; gap: 3px; }
        .input-label {
            font-size: 10.5px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.04em;
            color: var(--slate-500);
        }
        .form-input, .form-select {
            height: 38px;
            padding: 0 12px;
            border: 1px solid var(--slate-300);
            border-radius: 7px;
            background: #ffffff;
            font-family: inherit;
            font-size: 13px;
            color: var(--slate-800);
            outline: none;
            transition: all 0.15s ease;
        }
        .form-input:focus, .form-select:focus {
            border-color: var(--brand-accent);
            box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.12);
        }
        .filter-actions {
            display: flex;
            gap: 8px;
            align-items: flex-end;
            margin-top: auto;
        }

        .table-wrap {
            border: 1px solid var(--slate-200);
            border-radius: var(--radius-md);
            overflow: hidden;
            background: #ffffff;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            font-size: 13px;
            text-align: left;
        }
        th {
            background: #f8fafc;
            color: var(--slate-600);
            font-weight: 700;
            font-size: 11px;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            padding: 13px 18px;
            border-bottom: 1px solid var(--slate-200);
            white-space: nowrap;
        }
        td {
            padding: 15px 18px;
            border-bottom: 1px solid var(--slate-200);
            vertical-align: middle;
            color: var(--slate-700);
        }
        tr:last-child td { border-bottom: none; }
        tr:hover td { background: #f8fafc; }

        .date-cell {
            font-weight: 700;
            color: var(--slate-900);
            font-family: 'JetBrains Mono', monospace;
            font-size: 12.5px;
        }
        .emp-cell { display: flex; align-items: center; gap: 12px; }
        .emp-avatar {
            width: 32px;
            height: 32px;
            border-radius: 8px;
            background: var(--slate-100);
            border: 1px solid var(--slate-200);
            color: var(--slate-700);
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 12px;
            font-weight: 700;
        }
        .emp-info strong { display: block; color: var(--slate-900); font-size: 13px; }
        .emp-id-sub { font-size: 11px; color: var(--slate-400); font-family: 'JetBrains Mono', monospace; }

        .badge-pill {
            padding: 4px 10px;
            border-radius: 6px;
            font-size: 11px;
            font-weight: 700;
            display: inline-flex;
            align-items: center;
            gap: 5px;
        }
        .badge-pill::before { content: ''; width: 5px; height: 5px; border-radius: 50%; }
        .badge-amber { background: var(--warning-bg); color: var(--warning-text); border: 1px solid var(--warning-border); }
        .badge-amber::before { background: #ca8a04; }
        .badge-green { background: var(--success-bg); color: var(--success-text); border: 1px solid var(--success-border); }
        .badge-green::before { background: #16a34a; }
        .badge-red   { background: var(--danger-bg);  color: var(--danger-text);  border: 1px solid var(--danger-border); }
        .badge-red::before { background: #dc2626; }
        .badge-gray  { background: var(--slate-100);  color: var(--slate-600);    border: 1px solid var(--slate-200); }
        .badge-gray::before { background: #94a3b8; }

        .pagination-bar {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-top: 24px;
            font-size: 13px;
            color: var(--slate-500);
        }
        .pagination-list { display: flex; list-style: none; gap: 4px; }
        .page-link {
            padding: 6px 12px;
            border: 1px solid var(--slate-200);
            border-radius: 6px;
            text-decoration: none;
            color: var(--slate-700);
            font-weight: 600;
            font-size: 12.5px;
            background: #ffffff;
            transition: all 0.15s ease;
        }
        .page-link:hover { border-color: var(--slate-300); background: var(--slate-50); }
        .page-link.active { background: var(--brand-primary); color: #ffffff; border-color: var(--brand-primary); }
        .page-link.disabled { opacity: 0.45; cursor: not-allowed; pointer-events: none; }

        @media print {
            .no-print, .page-meta { display: none !important; }
            body { padding: 0 !important; background: #ffffff !important; }
            .container { max-width: 100% !important; margin: 0 !important; }
            .audit-card { border: none !important; box-shadow: none !important; padding: 0 !important; }
            .header-strip { border-bottom: 2px solid #000 !important; padding-bottom: 12px !important; margin-bottom: 16px !important; }
            .kpi-grid { grid-template-columns: repeat(4, 1fr) !important; gap: 10px !important; margin-bottom: 20px !important; }
            .kpi-card { border: 1px solid #ccc !important; padding: 12px !important; }
            .kpi-value { font-size: 20px !important; }
            .table-wrap { border: 1px solid #000 !important; }
            table { font-size: 11px !important; }
            th, td { padding: 8px 10px !important; border: 1px solid #ddd !important; }
            th { background: #f0f0f0 !important; color: #000 !important; }
        }

        @media (max-width: 992px) {
            .kpi-grid { grid-template-columns: repeat(2, 1fr); }
            .audit-card { padding: 20px; }
            body { padding: 20px 14px; }
        }
    </style>
</head>
<body>

<div class="container">
    <div class="page-meta">
        <div class="breadcrumb">
            <a href="<%= request.getContextPath() %>/dashboard.jsp">Dashboard</a>
            <span class="breadcrumb-sep">/</span>
            <a href="<%= request.getContextPath() %>/reports-dashboard.jsp">Reporting Hub</a>
            <span class="breadcrumb-sep">/</span>
            <span class="breadcrumb-active">Leave & Absence Allocations</span>
        </div>
        <div style="font-size: 12px; color: var(--slate-500); font-weight: 500;">
            Corporate Absence Registry
        </div>
    </div>

    <div class="audit-card">
        <div class="header-strip">
            <div class="title-block">
                <h1>
                    <%= isEmployee ? "My Leave Records" : "Leave Allocations Audit" %>
                    <span class="title-tag">HR Feed</span>
                </h1>
                <p>Review leave applications, operational approvals, rejection rationales, and schedule impact.</p>
            </div>
            <div class="actions-group no-print">
                <button type="button" onclick="window.print()" class="btn btn-outline">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><polyline points="6 9 6 2 18 2 18 9"></polyline><path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"></path><rect x="6" y="14" width="12" height="8"></rect></svg>
                    Print / Export PDF
                </button>
                <a href="<%= request.getContextPath() %>/reports/export?type=leaves&employeeId=<%= cleanEmp %>&status=<%= cleanStatus %>&fromDate=<%= cleanFrom %>&toDate=<%= cleanTo %>" class="btn btn-success">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>
                    Export CSV
                </a>
                <a href="<%= request.getContextPath() %>/reports-dashboard.jsp" class="btn btn-outline">
                    &larr; Reports Hub
                </a>
            </div>
        </div>

        <div class="kpi-grid">
            <div class="kpi-card kpi-amber">
                <div class="kpi-top">
                    <span class="kpi-label">Pending Approval</span>
                    <div class="kpi-icon-wrapper">
                        <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><circle cx="12" cy="12" r="10"></circle><polyline points="12 6 12 12 16 14"></polyline></svg>
                    </div>
                </div>
                <div class="kpi-value"><%= pendingCount %></div>
                <div class="kpi-subtext">Awaiting supervisor review</div>
            </div>

            <div class="kpi-card kpi-green">
                <div class="kpi-top">
                    <span class="kpi-label">Approved Leaves</span>
                    <div class="kpi-icon-wrapper">
                        <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"></polyline></svg>
                    </div>
                </div>
                <div class="kpi-value"><%= approvedCount %></div>
                <div class="kpi-subtext">Authorized schedule misses</div>
            </div>

            <div class="kpi-card kpi-red">
                <div class="kpi-top">
                    <span class="kpi-label">Rejected Requests</span>
                    <div class="kpi-icon-wrapper">
                        <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
                    </div>
                </div>
                <div class="kpi-value"><%= rejectedCount %></div>
                <div class="kpi-subtext">Denied applications</div>
            </div>

            <div class="kpi-card kpi-gray">
                <div class="kpi-top">
                    <span class="kpi-label">Cancelled Tickets</span>
                    <div class="kpi-icon-wrapper">
                        <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><circle cx="12" cy="12" r="10"></circle><line x1="4.93" y1="4.93" x2="19.07" y2="19.07"></line></svg>
                    </div>
                </div>
                <div class="kpi-value"><%= cancelledCount %></div>
                <div class="kpi-subtext">Revoked by applicant</div>
            </div>
        </div>

        <form method="get" action="<%= request.getContextPath() %>/reports/leaves" class="filter-panel no-print">
            <% if (!isEmployee) { %>
            <div class="input-group" style="flex: 2; min-width: 160px;">
                <span class="input-label">Filter Employee</span>
                <input type="text" name="employeeId" class="form-input" placeholder="e.g. EMP106" value="<%= cleanEmp %>">
            </div>
            <% } %>

            <div class="input-group" style="flex: 1.5; min-width: 140px;">
                <span class="input-label">Approval Status</span>
                <select name="status" class="form-select">
                    <option value="ALL">All Statuses</option>
                    <option value="PENDING" <%= "PENDING".equalsIgnoreCase(cleanStatus) ? "selected" : "" %>>PENDING</option>
                    <option value="APPROVED" <%= "APPROVED".equalsIgnoreCase(cleanStatus) ? "selected" : "" %>>APPROVED</option>
                    <option value="REJECTED" <%= "REJECTED".equalsIgnoreCase(cleanStatus) ? "selected" : "" %>>REJECTED</option>
                    <option value="CANCELLED" <%= "CANCELLED".equalsIgnoreCase(cleanStatus) ? "selected" : "" %>>CANCELLED</option>
                </select>
            </div>

            <div class="input-group" style="flex: 1.5; min-width: 130px;">
                <span class="input-label">From Date</span>
                <input type="date" name="fromDate" class="form-input" value="<%= cleanFrom %>">
            </div>

            <div class="input-group" style="flex: 1.5; min-width: 130px;">
                <span class="input-label">To Date</span>
                <input type="date" name="toDate" class="form-input" value="<%= cleanTo %>">
            </div>

            <div class="input-group" style="width: 100px;">
                <span class="input-label">Page Size</span>
                <select name="limit" class="form-select" onchange="this.form.submit()">
                    <option value="5" <%= (pageSize == 5) ? "selected" : "" %>>5 / page</option>
                    <option value="10" <%= (pageSize == 10) ? "selected" : "" %>>10 / page</option>
                    <option value="25" <%= (pageSize == 25) ? "selected" : "" %>>25 / page</option>
                </select>
            </div>

            <div class="filter-actions">
                <button type="submit" class="btn btn-primary">Filter</button>
                <a href="<%= request.getContextPath() %>/reports/leaves" class="btn btn-outline">Reset</a>
            </div>
        </form>

        <div class="table-wrap">
            <table>
                <thead>
                    <tr>
                        <th style="width: 22%;">Employee</th>
                        <th style="width: 15%;">Leave Classification</th>
                        <th style="width: 13%;">Effective Date</th>
                        <th style="width: 13%;">End Window</th>
                        <th style="width: 23%;">Reason / Justification</th>
                        <th style="width: 14%;">Approval Status</th>
                    </tr>
                </thead>
                <tbody>
                    <% if (records != null && !records.isEmpty()) { 
                        for (ReportItem r : records) { 
                            String bClass = "badge-amber";
                            String st = (r.getStatus() != null) ? r.getStatus().toUpperCase() : "PENDING";
                            if (st.contains("APPROV")) bClass = "badge-green";
                            else if (st.contains("REJECT")) bClass = "badge-red";
                            else if (st.contains("CANCEL")) bClass = "badge-gray";

                            String initial = (r.getEmployeeName() != null && !r.getEmployeeName().isBlank()) 
                                             ? r.getEmployeeName().substring(0, 1).toUpperCase() : "E";
                    %>
                        <tr>
                            <td>
                                <div class="emp-cell">
                                    <div class="emp-avatar"><%= initial %></div>
                                    <div class="emp-info">
                                        <strong><%= r.getEmployeeName() %></strong>
                                        <span class="emp-id-sub"><%= r.getEmployeeId() %></span>
                                    </div>
                                </div>
                            </td>
                            <td><%= (r.getTitle() != null ? r.getTitle() : "Casual Leave") %></td>
                            <td class="date-cell"><%= r.getStartDate() %></td>
                            <td class="date-cell"><%= (r.getEndDate() != null ? r.getEndDate() : r.getStartDate()) %></td>
                            <td><%= (r.getDetails() != null ? r.getDetails() : "--") %></td>
                            <td><span class="badge-pill <%= bClass %>"><%= st %></span></td>
                        </tr>
                    <% } } else { %>
                        <tr>
                            <td colspan="6" style="text-align: center; color: var(--slate-400); padding: 48px 24px;">
                                No leave applications match the selected criteria.
                            </td>
                        </tr>
                    <% } %>
                </tbody>
            </table>
        </div>

        <% if (totalPages > 1) { %>
            <div class="pagination-bar no-print">
                <span>Showing page <strong><%= currentPage %></strong> of <strong><%= totalPages %></strong> (<%= totalRecords %> records total)</span>
                <ul class="pagination-list">
                    <li>
                        <a class="page-link <%= (currentPage <= 1) ? "disabled" : "" %>" 
                           href="<%= request.getContextPath() %>/reports/leaves?page=<%= currentPage - 1 %>&limit=<%= pageSize %>&employeeId=<%= cleanEmp %>&status=<%= cleanStatus %>&fromDate=<%= cleanFrom %>&toDate=<%= cleanTo %>">
                           &larr; Prev
                        </a>
                    </li>
                    <% for (int p = 1; p <= totalPages; p++) { %>
                        <li>
                            <a class="page-link <%= (p == currentPage) ? "active" : "" %>" 
                               href="<%= request.getContextPath() %>/reports/leaves?page=<%= p %>&limit=<%= pageSize %>&employeeId=<%= cleanEmp %>&status=<%= cleanStatus %>&fromDate=<%= cleanFrom %>&toDate=<%= cleanTo %>">
                               <%= p %>
                            </a>
                        </li>
                    <% } %>
                    <li>
                        <a class="page-link <%= (currentPage >= totalPages) ? "disabled" : "" %>" 
                           href="<%= request.getContextPath() %>/reports/leaves?page=<%= currentPage + 1 %>&limit=<%= pageSize %>&employeeId=<%= cleanEmp %>&status=<%= cleanStatus %>&fromDate=<%= cleanFrom %>&toDate=<%= cleanTo %>">
                           Next &rarr;
                        </a>
                    </li>
                </ul>
            </div>
        <% } %>
    </div>
</div>

</body>
</html>