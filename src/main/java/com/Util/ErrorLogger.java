package com.Util;

import java.io.PrintWriter;
import java.io.StringWriter;
import java.sql.Connection;
import java.sql.PreparedStatement;

public class ErrorLogger {

    public static void log(Integer userId, String moduleName, String severity, Throwable t) {
        if (t == null) return;
        
        String errorType = t.getClass().getSimpleName();
        String errorMessage = t.getMessage() != null ? t.getMessage() : "Error occurred: " + errorType;

        StringWriter sw = new StringWriter();
        t.printStackTrace(new PrintWriter(sw));
        String stackTrace = sw.toString();

        String sql = "INSERT INTO system_errors (user_id, module_name, severity, error_type, error_message, stack_trace, created_at) " +
                     "VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)";

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            if (userId != null && userId > 0) {
                ps.setInt(1, userId);
            } else {
                ps.setNull(1, java.sql.Types.INTEGER);
            }
            ps.setString(2, moduleName != null ? moduleName.toUpperCase() : "GENERAL");
            ps.setString(3, severity != null ? severity.toUpperCase() : "MEDIUM");
            ps.setString(4, errorType);
            ps.setString(5, errorMessage.length() > 500 ? errorMessage.substring(0, 500) : errorMessage);
            ps.setString(6, stackTrace);
            ps.executeUpdate();
        } catch (Exception e) {
            System.err.println("ErrorLogger write error: " + e.getMessage());
        }
    }
}