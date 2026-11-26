package com.filter;

import com.Util.DBConnection;
import com.model.Employee;

import jakarta.servlet.*;
import jakarta.servlet.annotation.WebFilter;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.sql.Connection;
import java.sql.PreparedStatement;

@WebFilter("/*")
public class GlobalExceptionFilter implements Filter {

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        try {
            // Let the normal request/servlet/JSP execute
            chain.doFilter(request, response);
        } catch (Throwable t) {
            // Unhandled exception caught: log it to MySQL table system_errors
            logSystemError(request, t);
            
            // Re-throw so the application handles error page routing normally
            if (t instanceof ServletException) {
                throw (ServletException) t;
            } else if (t instanceof IOException) {
                throw (IOException) t;
            } else {
                throw new ServletException(t);
            }
        }
    }

    private void logSystemError(ServletRequest request, Throwable t) {
        HttpServletRequest httpRequest = (HttpServletRequest) request;
        
        // 1. Identify User ID if session exists
        Integer userId = null;
        try {
            HttpSession session = httpRequest.getSession(false);
            if (session != null) {
                Object empObj = session.getAttribute("loggedInEmployee");
                if (empObj instanceof Employee) {
                    userId = ((Employee) empObj).getId();
                }
            }
        } catch (Exception ignored) {}

        // 2. Identify Module from URI (e.g., /payroll, /login, /tasks)
        String uri = httpRequest.getRequestURI();
        String moduleName = "SYSTEM";
        if (uri != null) {
            String lowerUri = uri.toLowerCase();
            if (lowerUri.contains("payroll") || lowerUri.contains("salary")) moduleName = "PAYROLL";
            else if (lowerUri.contains("auth") || lowerUri.contains("login")) moduleName = "AUTHENTICATION";
            else if (lowerUri.contains("attendance")) moduleName = "ATTENDANCE";
            else if (lowerUri.contains("leave")) moduleName = "LEAVE_MANAGEMENT";
            else if (lowerUri.contains("team") || lowerUri.contains("employee")) moduleName = "EMPLOYEE_MGMT";
            else if (lowerUri.contains("backup")) moduleName = "BACKUP_ENGINE";
        }

        // 3. Extract Root Cause & Error Metadata
        Throwable root = t;
        while (root.getCause() != null) {
            root = root.getCause();
        }

        String errorType = root.getClass().getSimpleName();
        String errorMessage = root.getMessage();
        if (errorMessage == null || errorMessage.isBlank()) {
            errorMessage = "Unhandled " + errorType + " occurred at " + uri;
        }

        // Determine severity
        String severity = "MEDIUM";
        if (errorType.contains("SQL") || errorType.contains("Database") || errorType.contains("Connection")) {
            severity = "CRITICAL";
        } else if (errorType.contains("NullPointer") || errorType.contains("Fatal") || errorType.contains("Security")) {
            severity = "HIGH";
        }

        // 4. Capture Stack Trace
        StringWriter sw = new StringWriter();
        PrintWriter pw = new PrintWriter(sw);
        root.printStackTrace(pw);
        String stackTrace = sw.toString();

        // 5. Insert directly into system_errors
        String sql = "INSERT INTO system_errors (user_id, module_name, severity, error_type, error_message, stack_trace, created_at) " +
                     "VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)";

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            
            if (userId != null && userId > 0) {
                ps.setInt(1, userId);
            } else {
                ps.setNull(1, java.sql.Types.INTEGER);
            }
            
            ps.setString(2, moduleName);
            ps.setString(3, severity);
            ps.setString(4, errorType);
            ps.setString(5, errorMessage.length() > 500 ? errorMessage.substring(0, 500) : errorMessage);
            ps.setString(6, stackTrace);
            ps.executeUpdate();
            
            System.err.println(">>> [GlobalExceptionFilter] Auto-logged uncaught error: " + errorType + " in " + moduleName);
            
        } catch (Exception e) {
            System.err.println("Failed to insert into system_errors: " + e.getMessage());
        }
    }

    @Override
    public void init(FilterConfig filterConfig) {}

    @Override
    public void destroy() {}
}