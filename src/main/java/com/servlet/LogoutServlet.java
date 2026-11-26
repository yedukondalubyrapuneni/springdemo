package com.servlet;

import com.model.Employee;
import com.Util.DBConnection;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;
import java.sql.Connection;
import java.sql.PreparedStatement;

@WebServlet("/logout")
public class LogoutServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        
        HttpSession session = request.getSession(false);
        if (session != null) {
            Employee loggedIn = (Employee) session.getAttribute("loggedInEmployee");
            
            if (loggedIn != null) {
                // 1. Record LOGOUT into login_history
                recordLogoutHistory(loggedIn.getId(), loggedIn.getEmail(), request);

                // 2. Append LOGOUT action to audit_logs
                recordAuditTrail(loggedIn.getId(), "AUTHENTICATION", "LOGOUT", 
                    String.valueOf(loggedIn.getId()), 
                    "User signed out from active session", 
                    "{\"employee_id\":\"" + loggedIn.getEmployeeId() + "\",\"email\":\"" + loggedIn.getEmail() + "\"}");
            }

            // Invalidate the session
            session.invalidate();
        }

        response.sendRedirect(request.getContextPath() + "/login");
    }

    // Helper: Appends row into login_history
    private void recordLogoutHistory(Integer userId, String email, HttpServletRequest request) {
        String clientIp = request.getHeader("X-Forwarded-For");
        if (clientIp == null || clientIp.isBlank() || "unknown".equalsIgnoreCase(clientIp)) {
            clientIp = request.getRemoteAddr();
        } else {
            clientIp = clientIp.split(",")[0].trim();
        }

        String userAgent = request.getHeader("User-Agent");
        if (userAgent == null || userAgent.isBlank()) {
            userAgent = "Unknown Client";
        }

        String sql = "INSERT INTO login_history (user_id, email, activity_type, ip_address, user_agent, created_at) " +
                     "VALUES (?, ?, 'LOGOUT', ?, ?, CURRENT_TIMESTAMP)";

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            if (userId != null && userId > 0) {
                ps.setInt(1, userId);
            } else {
                ps.setNull(1, java.sql.Types.INTEGER);
            }
            ps.setString(2, (email != null && !email.isBlank()) ? email : "unknown");
            ps.setString(3, clientIp);
            ps.setString(4, userAgent);
            ps.executeUpdate();
        } catch (Exception e) {
            System.err.println("Failed to insert logout into login_history: " + e.getMessage());
        }
    }

    // Helper: Appends row into audit_logs
    private void recordAuditTrail(Integer userId, String module, String action, String recordId, String desc, String payload) {
        String sql = "INSERT INTO audit_logs (user_id, module_name, action_type, record_id, description, new_values, created_at) " +
                     "VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)";

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            if (userId != null && userId > 0) {
                ps.setInt(1, userId);
            } else {
                ps.setNull(1, java.sql.Types.INTEGER);
            }
            ps.setString(2, module);
            ps.setString(3, action);
            ps.setString(4, recordId);
            ps.setString(5, desc);
            ps.setString(6, payload);
            ps.executeUpdate();
        } catch (Exception e) {
            System.err.println("Failed to insert logout into audit_logs: " + e.getMessage());
        }
    }
}