package com.model;

import java.util.List;
import java.util.Map;

public class DashboardSummaryDTO {
    // Top-row Metrics (Section 8 Functional Requirements)
    private int totalUsers;
    private int activeUsers;
    private int inactiveUsers;
    private int totalAuditRecords;
    private int todayLogins;
    private int failedLoginsToday;
    private int totalErrors;
    private String latestBackupStatus;
    private String latestBackupTime;

    // Recent Activity Feeds (Section 8 Additional Sections)
    private List<AuditLog> recentAuditLogs;
    private List<LoginHistory> recentLoginHistory;
    private List<SystemError> recentErrors;
    private List<BackupHistory> recentBackups;
    private Map<String, String> systemSettingsOverview;

    public DashboardSummaryDTO() {}

    // Getters and Setters
    public int getTotalUsers() { return totalUsers; }
    public void setTotalUsers(int totalUsers) { this.totalUsers = totalUsers; }

    public int getActiveUsers() { return activeUsers; }
    public void setActiveUsers(int activeUsers) { this.activeUsers = activeUsers; }

    public int getInactiveUsers() { return inactiveUsers; }
    public void setInactiveUsers(int inactiveUsers) { this.inactiveUsers = inactiveUsers; }

    public int getTotalAuditRecords() { return totalAuditRecords; }
    public void setTotalAuditRecords(int totalAuditRecords) { this.totalAuditRecords = totalAuditRecords; }

    public int getTodayLogins() { return todayLogins; }
    public void setTodayLogins(int todayLogins) { this.todayLogins = todayLogins; }

    public int getFailedLoginsToday() { return failedLoginsToday; }
    public void setFailedLoginsToday(int failedLoginsToday) { this.failedLoginsToday = failedLoginsToday; }

    public int getTotalErrors() { return totalErrors; }
    public void setTotalErrors(int totalErrors) { this.totalErrors = totalErrors; }

    public String getLatestBackupStatus() { return latestBackupStatus; }
    public void setLatestBackupStatus(String latestBackupStatus) { this.latestBackupStatus = latestBackupStatus; }

    public String getLatestBackupTime() { return latestBackupTime; }
    public void setLatestBackupTime(String latestBackupTime) { this.latestBackupTime = latestBackupTime; }

    public List<AuditLog> getRecentAuditLogs() { return recentAuditLogs; }
    public void setRecentAuditLogs(List<AuditLog> recentAuditLogs) { this.recentAuditLogs = recentAuditLogs; }

    public List<LoginHistory> getRecentLoginHistory() { return recentLoginHistory; }
    public void setRecentLoginHistory(List<LoginHistory> recentLoginHistory) { this.recentLoginHistory = recentLoginHistory; }

    public List<SystemError> getRecentErrors() { return recentErrors; }
    public void setRecentErrors(List<SystemError> recentErrors) { this.recentErrors = recentErrors; }

    public List<BackupHistory> getRecentBackups() { return recentBackups; }
    public void setRecentBackups(List<BackupHistory> recentBackups) { this.recentBackups = recentBackups; }

    public Map<String, String> getSystemSettingsOverview() { return systemSettingsOverview; }
    public void setSystemSettingsOverview(Map<String, String> systemSettingsOverview) { this.systemSettingsOverview = systemSettingsOverview; }
}