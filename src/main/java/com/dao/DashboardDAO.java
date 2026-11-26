package com.dao;

import com.model.*;
import com.Util.DBConnection;

import java.sql.*;
import java.util.*;

public class DashboardDAO {

    public DashboardSummaryDTO getDashboardMetrics() {
        DashboardSummaryDTO dto = new DashboardSummaryDTO();

        // 1. User & Attendance Aggregations
        String userSql = "SELECT " +
                         " COUNT(*) AS total_users, " +
                         " SUM(CASE WHEN status = 'ACTIVE' THEN 1 ELSE 0 END) AS active_users, " +
                         " SUM(CASE WHEN status != 'ACTIVE' THEN 1 ELSE 0 END) AS inactive_users " +
                         "FROM users";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(userSql);
             ResultSet rs = ps.executeQuery()) {
            if (rs.next()) {
                dto.setTotalUsers(rs.getInt("total_users"));
                dto.setActiveUsers(rs.getInt("active_users"));
                dto.setInactiveUsers(rs.getInt("inactive_users"));
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }

        // 2. Total Audit Records Count
        String auditCountSql = "SELECT COUNT(*) FROM audit_logs";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(auditCountSql);
             ResultSet rs = ps.executeQuery()) {
            if (rs.next()) dto.setTotalAuditRecords(rs.getInt(1));
        } catch (SQLException e) {
            e.printStackTrace();
        }

        // 3. Today's Login and Failed Attempts
        String loginCountSql = "SELECT " +
                               " SUM(CASE WHEN activity_type = 'LOGIN' THEN 1 ELSE 0 END) AS today_logins, " +
                               " SUM(CASE WHEN activity_type = 'FAILED_LOGIN' THEN 1 ELSE 0 END) AS today_failed " +
                               "FROM login_history WHERE DATE(created_at) = CURRENT_DATE";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(loginCountSql);
             ResultSet rs = ps.executeQuery()) {
            if (rs.next()) {
                dto.setTodayLogins(rs.getInt("today_logins"));
                dto.setFailedLoginsToday(rs.getInt("today_failed"));
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }

        // 4. Total Error Records
        String errCountSql = "SELECT COUNT(*) FROM system_errors";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(errCountSql);
             ResultSet rs = ps.executeQuery()) {
            if (rs.next()) dto.setTotalErrors(rs.getInt(1));
        } catch (SQLException e) {
            e.printStackTrace();
        }

        // 5. Latest Backup Status
        String backupSql = "SELECT status, created_at FROM backup_history ORDER BY created_at DESC LIMIT 1";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(backupSql);
             ResultSet rs = ps.executeQuery()) {
            if (rs.next()) {
                dto.setLatestBackupStatus(rs.getString("status"));
                dto.setLatestBackupTime(rs.getString("created_at"));
            } else {
                dto.setLatestBackupStatus("NONE");
                dto.setLatestBackupTime("No backups initiated");
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }

        // 6. Recent Activity Streams (Last 5 records each)
        dto.setRecentAuditLogs(new AuditLogDAO().getAllAuditLogs(5, 0));
        dto.setRecentLoginHistory(new LoginHistoryDAO().getFilteredHistory(null, null, 5, 0));
        dto.setRecentErrors(new SystemErrorDAO().getFilteredErrors(null, null, 5));
        dto.setRecentBackups(new BackupHistoryDAO().getAllBackups(5));

        // 7. System Configuration Overview
        Map<String, String> settingsMap = new LinkedHashMap<>();
        for (SystemSetting s : new SystemSettingsDAO().getAllSettings()) {
            settingsMap.put(s.getSettingKey(), s.getSettingValue());
        }
        dto.setSystemSettingsOverview(settingsMap);

        return dto;
    }
}