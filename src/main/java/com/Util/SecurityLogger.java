package com.Util;

import java.sql.Connection;
import java.sql.PreparedStatement;
import jakarta.servlet.http.HttpServletRequest;

public class SecurityLogger {

    public static void logAuthEvent(Integer userId, String email, String activityType, HttpServletRequest request) {
        String ipAddress = request.getHeader("X-Forwarded-For");
        if (ipAddress == null || ipAddress.isEmpty() || "unknown".equalsIgnoreCase(ipAddress)) {
            ipAddress = request.getRemoteAddr();
        } else {
            // First IP in chain if proxies are present
            ipAddress = ipAddress.split(",")[0].trim();
        }

        String userAgent = request.getHeader("User-Agent");
        if (userAgent == null) {
            userAgent = "Unknown Client";
        }

        String sql = "INSERT INTO login_history (user_id, email, activity_type, ip_address, user_agent, created_at) " +
                     "VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)";

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            if (userId != null && userId > 0) {
                ps.setInt(1, userId);
            } else {
                ps.setNull(1, java.sql.Types.INTEGER);
            }
            ps.setString(2, email != null ? email : "unknown");
            ps.setString(3, activityType); // 'LOGIN', 'FAILED_LOGIN', or 'LOGOUT'
            ps.setString(4, ipAddress);
            ps.setString(5, userAgent);
            ps.executeUpdate();
        } catch (Exception e) {
            System.err.println("Failed to insert login history: " + e.getMessage());
        }
    }
}