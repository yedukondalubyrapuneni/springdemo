<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.util.List" %>
<%@ page import="com.example.demo.model.AuditLog" %>
<%@ page import="com.dao.AuditLogDAO" %>

<%
// 1. Session Role Resolution (Handles both direct string and Employee model)
    String userRole = null;
    if (session != null) {
        if (session.getAttribute("role") != null) {
            userRole = session.getAttribute("role").toString();
        } else if (session.getAttribute("userRole") != null) {
            userRole = session.getAttribute("userRole").toString();
        } else if (session.getAttribute("loggedInEmployee") != null) {
            com.example.demo.model.Employee emp = (com.example.demo.model.Employee) session.getAttribute("loggedInEmployee");
            userRole = emp.getRole();
        } else if (session.getAttribute("employee") != null) {
            com.example.demo.model.Employee emp = (com.example.demo.model.Employee) session.getAttribute("employee");
            userRole = emp.getRole();
        }
    }

    boolean isAdmin = userRole != null && (
        userRole.equalsIgnoreCase("ADMIN") || 
        userRole.equalsIgnoreCase("SUPER ADMIN") || 
        userRole.equalsIgnoreCase("HR")
    );

    if (!isAdmin) {
        response.sendError(HttpServletResponse.SC_FORBIDDEN, "Access Denied: Only administrators can view audit logs.");
        return;
    }

    // 2. Direct DAO Loading & Pagination
    int currentPage = 1;
    try {
        if (request.getParameter("page") != null) {
            currentPage = Integer.parseInt(request.getParameter("page"));
        }
    } catch (NumberFormatException ignored) {}

    int pageSize = 20;
    int offset = (currentPage - 1) * pageSize;

    AuditLogDAO auditDAO = new AuditLogDAO();
    List<AuditLog> auditList = auditDAO.getAllAuditLogs(pageSize, offset);
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Enterprise Audit Trail - SmartOffice</title>
    <style>
        :root { --primary: #2563eb; --bg: #f8fafc; --surface: #ffffff; --border: #e2e8f0; --text-main: #0f172a; --text-muted: #64748b; }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: var(--bg); color: var(--text-main); padding: 24px; }
        .container { max-width: 1400px; margin: 0 auto; display: flex; flex-direction: column; gap: 20px; }
        
        .header { display: flex; justify-content: space-between; align-items: center; background: var(--surface); padding: 18px 24px; border-radius: 12px; border: 1px solid var(--border); box-shadow: 0 1px 3px rgba(0,0,0,0.03); }
        .header h1 { font-size: 20px; font-weight: 700; }
        .nav-link { text-decoration: none; font-size: 13px; font-weight: 600; padding: 7px 14px; border-radius: 8px; color: var(--text-muted); transition: all 0.2s; }
        .nav-link.active { background: var(--primary); color: #fff; }
        .nav-link:hover:not(.active) { background: #eff6ff; color: var(--primary); }

        .card { background: var(--surface); border-radius: 12px; border: 1px solid var(--border); padding: 20px; box-shadow: 0 1px 3px rgba(0,0,0,0.03); }
        table { width: 100%; border-collapse: collapse; font-size: 13px; margin-top: 10px; }
        th { background: #f8fafc; padding: 12px 14px; text-align: left; font-weight: 600; color: var(--text-muted); border-bottom: 2px solid var(--border); }
        td { padding: 12px 14px; border-bottom: 1px solid #f1f5f9; vertical-align: top; }
        tr:hover { background: #fbfcfe; }

        .badge-action { background: #eff6ff; color: #1d4ed8; font-weight: 700; padding: 3px 8px; border-radius: 6px; font-size: 11px; display: inline-block; }
        .badge-create { background: #dcfce7; color: #15803d; }
        .badge-update { background: #fef3c7; color: #b45309; }
        .badge-delete { background: #fee2e2; color: #b91c1c; }
        
        pre { background: #f8fafc; border: 1px solid var(--border); border-radius: 6px; padding: 6px 10px; font-size: 11px; max-width: 280px; overflow-x: auto; color: #334155; }
        code { background: #f1f5f9; padding: 2px 6px; border-radius: 4px; font-size: 12px; font-weight: 600; }

        .pagination { display: flex; justify-content: flex-end; align-items: center; gap: 8px; margin-top: 20px; font-size: 13px; }
        .page-btn { padding: 6px 14px; border: 1px solid var(--border); background: var(--surface); color: var(--text-main); text-decoration: none; border-radius: 6px; font-weight: 500; }
        .page-btn.disabled { pointer-events: none; opacity: 0.4; }
        .page-btn:hover:not(.disabled) { background: #f1f5f9; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div>
                <h1>Immutable Audit Trail &amp; Data Changes</h1>
                <p style="font-size: 13px; color: var(--text-muted);">Cryptographic and chronological record of all administrative operations</p>
            </div>
            <nav style="display:flex; gap: 8px; flex-wrap: wrap;">
                <a href="<%= request.getContextPath() %>/dashboard.jsp" class="nav-link">&larr; Main Workspace</a>
                <a href="<%= request.getContextPath() %>/system-dashboard.jsp" class="nav-link">Dashboard</a>
                <a href="<%= request.getContextPath() %>/auditlogs.jsp" class="nav-link active">Audit Logs</a>
                <a href="<%= request.getContextPath() %>/login-history.jsp" class="nav-link">Login History</a>
                <a href="<%= request.getContextPath() %>/system-settings.jsp" class="nav-link">Settings</a>
                <a href="<%= request.getContextPath() %>/system-errors.jsp" class="nav-link">Errors</a>
                <a href="<%= request.getContextPath() %>/backup-management.jsp" class="nav-link">Backups</a>
            </nav>
        </div>

        <div class="card">
            <table>
                <thead>
                    <tr>
                        <th style="width: 15%;">Timestamp</th>
                        <th style="width: 8%;">User</th>
                        <th style="width: 14%;">Module</th>
                        <th style="width: 10%;">Action</th>
                        <th style="width: 10%;">Target ID</th>
                        <th style="width: 21%;">Description</th>
                        <th style="width: 22%;">Payload Snapshot</th>
                    </tr>
                </thead>
                <tbody>
                    <%
                        if (auditList != null && !auditList.isEmpty()) {
                            for (AuditLog log : auditList) {
                                String act = log.getActionType() != null ? log.getActionType().toUpperCase() : "";
                                String bClass = "badge-action";
                                if (act.contains("CREATE") || act.contains("INSERT")) bClass += " badge-create";
                                else if (act.contains("UPDATE") || act.contains("MODIFY")) bClass += " badge-update";
                                else if (act.contains("DELETE") || act.contains("REMOVE")) bClass += " badge-delete";
                    %>
                        <tr>
                            <td><%= log.getCreatedAt() != null ? log.getCreatedAt() : "-" %></td>
                            <td><b><%= log.getUserId() != null ? "UID #" + log.getUserId() : "System" %></b></td>
                            <td><%= log.getModuleName() != null ? log.getModuleName() : "-" %></td>
                            <td><span class="<%= bClass %>"><%= act %></span></td>
                            <td><code><%= log.getRecordId() != null ? log.getRecordId() : "-" %></code></td>
                            <td style="color: var(--text-muted);"><%= log.getDescription() != null ? log.getDescription() : "-" %></td>
                            <td>
                                <% if (log.getNewValues() != null && !log.getNewValues().trim().isEmpty() && !log.getNewValues().equals("{}")) { %>
                                    <pre><%= log.getNewValues() %></pre>
                                <% } else { %>
                                    <span style="color: #94a3b8; font-size: 12px;">No state change recorded</span>
                                <% } %>
                            </td>
                        </tr>
                    <%
                            }
                        } else {
                    %>
                        <tr>
                            <td colspan="7" style="text-align: center; color: var(--text-muted); padding: 32px;">No audit records found in the database.</td>
                        </tr>
                    <% } %>
                </tbody>
            </table>

            <div class="pagination">
                <%
                    int prev = currentPage > 1 ? currentPage - 1 : 1;
                    int next = currentPage + 1;
                    boolean isFirst = currentPage <= 1;
                    boolean isLast = auditList == null || auditList.size() < pageSize;
                %>
                <a href="<%= request.getContextPath() %>/auditlogs.jsp?page=<%= prev %>" class="page-btn <%= isFirst ? "disabled" : "" %>">&laquo; Previous</a>
                <span style="color: var(--text-muted); font-weight: 600;">Page <%= currentPage %></span>
                <a href="<%= request.getContextPath() %>/auditlogs.jsp?page=<%= next %>" class="page-btn <%= isLast ? "disabled" : "" %>">Next &raquo;</a>
            </div>
        </div>
    </div>
</body>
</html>