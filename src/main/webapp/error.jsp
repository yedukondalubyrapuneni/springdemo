<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" isErrorPage="true" %>
<%@ page import="java.sql.*" %>
<%@ page import="com.Util.DBConnection" %>
<%@ page import="com.example.demo.model.Employee" %>

<%
    // 1. Retrieve the exception object provided by isErrorPage="true"
    Throwable t = exception;
    if (t == null) {
        t = (Throwable) request.getAttribute("jakarta.servlet.error.exception");
    }

    String errorType = (t != null) ? t.getClass().getSimpleName() : "NullPointerException";
    String errorMessage = (t != null && t.getMessage() != null) ? t.getMessage() : "Unhandled runtime failure";

    // 2. Resolve User ID if employee is logged in
    Integer userId = null;
    try {
        if (session != null && session.getAttribute("loggedInEmployee") != null) {
            Employee emp = (Employee) session.getAttribute("loggedInEmployee");
            userId = emp.getId();
        }
    } catch (Exception ignored) {}

    // 3. Insert using ONLY your 7 exact table columns
    String sql = "INSERT INTO system_errors (module_name, error_type, error_message, severity, user_id, created_at) " +
                 "VALUES ('TEST_MODULE', ?, ?, 'HIGH', ?, CURRENT_TIMESTAMP)";

    boolean dbSuccess = false;
    String dbError = null;

    try (Connection conn = DBConnection.getConnection();
         PreparedStatement ps = conn.prepareStatement(sql)) {

        ps.setString(1, errorType);
        ps.setString(2, errorMessage.length() > 500 ? errorMessage.substring(0, 500) : errorMessage);

        if (userId != null && userId > 0) {
            ps.setInt(3, userId);
        } else {
            ps.setNull(3, java.sql.Types.INTEGER);
        }

        int rows = ps.executeUpdate();
        dbSuccess = (rows > 0);
        System.out.println(">>> [Auto-Logging Success] Inserted row into system_errors: " + errorType);

    } catch (Exception e) {
        dbError = e.getMessage();
        System.err.println(">>> [Auto-Logging Error]: " + e.getMessage());
    }
%>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Application Error Logged</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f8fafc; color: #334155; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; }
        .card { background: #fff; border: 1px solid #e2e8f0; border-radius: 12px; padding: 32px; max-width: 520px; width: 90%; text-align: center; box-shadow: 0 4px 6px rgba(0,0,0,0.05); }
        .badge { background: <%= dbSuccess ? "#fee2e2" : "#fef3c7" %>; color: <%= dbSuccess ? "#dc2626" : "#b45309" %>; display: inline-block; padding: 5px 14px; border-radius: 20px; font-weight: 700; font-size: 11px; margin-bottom: 12px; }
        h2 { margin: 0 0 8px; color: #0f172a; font-size: 18px; }
        p { font-size: 13px; color: #64748b; line-height: 1.5; margin: 0 0 16px; }
        .code { font-family: monospace; background: #f1f5f9; padding: 10px; border-radius: 6px; font-size: 12px; color: #b91c1c; text-align: left; word-break: break-all; margin-bottom: 20px; }
        .btn { background: #4f46e5; color: #fff; text-decoration: none; padding: 10px 20px; border-radius: 8px; font-size: 13px; font-weight: 600; display: inline-block; }
    </style>
</head>
<body>
    <div class="card">
        <div class="badge"><%= dbSuccess ? "⚠ INCIDENT AUTO-LOGGED" : "⚠ DB LOG FAILED" %></div>
        <h2>System Fault Captured</h2>
        <p><%= dbSuccess ? "The unhandled exception details have been automatically recorded into MySQL." : ("Database recording failed: " + dbError) %></p>
        <div class="code"><%= errorType %>: <%= errorMessage %></div>
        <a href="<%= request.getContextPath() %>/system-errors.jsp" class="btn">← Go to Incident Triage</a>
    </div>
</body>
</html>