package com.dao;

import com.Util.DBConnection;
import com.model.ReportItem;

import java.sql.*;
import java.util.*;

public class ReportDAO {
	// Validates whether targetEmployeeId belongs to an active team assigned to managerEmployeeId
    public boolean isEmployeeInManagerTeams(String managerEmployeeId, String targetEmployeeId) {
        if (managerEmployeeId == null || targetEmployeeId == null) return false;

        String sql = "SELECT COUNT(*) FROM team_members tm " +
                     "JOIN teams t ON tm.team_id = t.id " +
                     "WHERE TRIM(REPLACE(t.manager_id, ' ', '')) = TRIM(REPLACE(?, ' ', '')) " +
                     "  AND TRIM(REPLACE(tm.employee_id, ' ', '')) = TRIM(REPLACE(?, ' ', '')) " +
                     "  AND (tm.status IS NULL OR UPPER(tm.status) = 'ACTIVE')";

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, managerEmployeeId);
            ps.setString(2, targetEmployeeId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return rs.getInt(1) > 0;
                }
            }
        } catch (SQLException e) {
            System.err.println("Error verifying manager team member: " + e.getMessage());
            e.printStackTrace();
        }
        return false;
    }
    // ==========================================
    // 1. ATTENDANCE REPORT (ROLE-AWARE & SAFE)
    // ==========================================
    public int countAttendance(String role, String currentEmpId, String targetEmpId, String fromDate, String toDate) {
        StringBuilder sql = new StringBuilder(
            "SELECT COUNT(*) FROM attendance a " +
            "LEFT JOIN team_members tm ON a.employee_id = tm.employee_id " +
            "LEFT JOIN teams t ON tm.team_id = t.id WHERE 1=1 "
        );
        List<Object> params = new ArrayList<>();

        String cleanRole = (role != null) ? role.trim().toUpperCase() : "EMPLOYEE";

        if ("EMPLOYEE".equals(cleanRole)) {
            sql.append("AND a.employee_id = ? ");
            params.add(currentEmpId);
        } else if ("MANAGER".equals(cleanRole)) {
            int numericMgrId = 0;
            try {
                numericMgrId = Integer.parseInt(currentEmpId.replaceAll("[^0-9]", ""));
            } catch (Exception ignored) {}
            sql.append("AND (t.manager_id = ? OR t.manager_id = ? OR a.employee_id = ?) ");
            params.add(numericMgrId);
            params.add(currentEmpId);
            params.add(currentEmpId);
        }

        if (targetEmpId != null && !targetEmpId.isBlank() && !"ALL".equalsIgnoreCase(targetEmpId)) {
            sql.append("AND a.employee_id = ? ");
            params.add(targetEmpId.trim());
        }
        if (fromDate != null && !fromDate.isBlank()) {
            sql.append("AND a.attendance_date >= ? ");
            params.add(java.sql.Date.valueOf(fromDate.trim()));
        }
        if (toDate != null && !toDate.isBlank()) {
            sql.append("AND a.attendance_date <= ? ");
            params.add(java.sql.Date.valueOf(toDate.trim()));
        }

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            for (int i = 0; i < params.size(); i++) ps.setObject(i + 1, params.get(i));
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) return rs.getInt(1);
            }
        } catch (SQLException e) {
            System.err.println("SQL error in countAttendance: " + e.getMessage());
            e.printStackTrace();
        }
        return 0;
    }

    public List<ReportItem> getAttendanceReportPaginated(String role, String currentEmpId, String targetEmpId, String fromDate, String toDate, int offset, int limit) {
        List<ReportItem> list = new ArrayList<>();
        StringBuilder sql = new StringBuilder(
            "SELECT a.employee_id, " +
            "COALESCE((SELECT name FROM employee WHERE employee_id = a.employee_id LIMIT 1), a.employee_id) AS emp_name, " +
            "a.attendance_date, " +
            "TIME_FORMAT(a.check_in_time, '%H:%i') AS in_time, " +
            "TIME_FORMAT(a.check_out_time, '%H:%i') AS out_time, a.status " +
            "FROM attendance a " +
            "LEFT JOIN team_members tm ON a.employee_id = tm.employee_id " +
            "LEFT JOIN teams t ON tm.team_id = t.id WHERE 1=1 "
        );
        List<Object> params = new ArrayList<>();

        String cleanRole = (role != null) ? role.trim().toUpperCase() : "EMPLOYEE";

        if ("EMPLOYEE".equals(cleanRole)) {
            sql.append("AND a.employee_id = ? ");
            params.add(currentEmpId);
        } else if ("MANAGER".equals(cleanRole)) {
            int numericMgrId = 0;
            try {
                numericMgrId = Integer.parseInt(currentEmpId.replaceAll("[^0-9]", ""));
            } catch (Exception ignored) {}
            sql.append("AND (t.manager_id = ? OR t.manager_id = ? OR a.employee_id = ?) ");
            params.add(numericMgrId);
            params.add(currentEmpId);
            params.add(currentEmpId);
        }

        if (targetEmpId != null && !targetEmpId.isBlank() && !"ALL".equalsIgnoreCase(targetEmpId)) {
            sql.append("AND a.employee_id = ? ");
            params.add(targetEmpId.trim());
        }
        if (fromDate != null && !fromDate.isBlank()) {
            sql.append("AND a.attendance_date >= ? ");
            params.add(java.sql.Date.valueOf(fromDate.trim()));
        }
        if (toDate != null && !toDate.isBlank()) {
            sql.append("AND a.attendance_date <= ? ");
            params.add(java.sql.Date.valueOf(toDate.trim()));
        }

        sql.append("GROUP BY a.employee_id, a.attendance_date ORDER BY a.attendance_date DESC LIMIT ? OFFSET ?");
        params.add(limit);
        params.add(offset);

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            for (int i = 0; i < params.size(); i++) ps.setObject(i + 1, params.get(i));
            try (ResultSet rs = ps.executeQuery()) {
                int rowIdx = offset + 1;
                while (rs.next()) {
                    ReportItem item = new ReportItem();
                    item.setId(String.valueOf(rowIdx++));
                    item.setEmployeeId(rs.getString("employee_id"));
                    item.setEmployeeName(rs.getString("emp_name"));
                    java.sql.Date d = rs.getDate("attendance_date");
                    if (d != null) item.setRecordDate(d.toLocalDate());
                    item.setDetails(rs.getString("in_time") + " - " + (rs.getString("out_time") != null ? rs.getString("out_time") : "--"));
                    item.setStatus(rs.getString("status") != null ? rs.getString("status").toUpperCase() : "ABSENT");
                    list.add(item);
                }
            }
        } catch (SQLException e) {
            System.err.println("SQL error in getAttendanceReportPaginated: " + e.getMessage());
            e.printStackTrace();
        }
        return list;
    }

    public List<ReportItem> getAttendanceReport(String role, String currentEmpId, String targetEmpId, String fromDate, String toDate, Map<String, Integer> summary) {
        List<ReportItem> list = getAttendanceReportPaginated(role, currentEmpId, targetEmpId, fromDate, toDate, 0, Integer.MAX_VALUE);
        int present = 0, absent = 0, late = 0;
        for (ReportItem item : list) {
            String st = (item.getStatus() != null) ? item.getStatus().toUpperCase() : "";
            if (st.contains("PRESENT") || st.contains("COMPLETED")) present++;
            else if (st.contains("LATE")) late++;
            else absent++;
        }
        if (summary != null) {
            summary.put("PRESENT", present);
            summary.put("ABSENT", absent);
            summary.put("LATE", late);
        }
        return list;
    }

    // ==========================================
    // 2. LEAVE REPORT (READS DIRECTLY FROM ATTENDANCE TABLE)
    // ==========================================
    public int countLeaves(String role, String currentEmpId, String targetEmpId, String status, String fromDate, String toDate) {
        StringBuilder sql = new StringBuilder(
            "SELECT COUNT(*) FROM attendance a " +
            "LEFT JOIN team_members tm ON a.employee_id = tm.employee_id " +
            "LEFT JOIN teams t ON tm.team_id = t.id " +
            "WHERE UPPER(a.status) LIKE '%LEAVE%' "
        );
        List<Object> params = new ArrayList<>();

        String cleanRole = (role != null) ? role.trim().toUpperCase() : "EMPLOYEE";

        if ("EMPLOYEE".equals(cleanRole)) {
            sql.append("AND a.employee_id = ? ");
            params.add(currentEmpId);
        } else if ("MANAGER".equals(cleanRole)) {
            int numericMgrId = 0;
            try {
                numericMgrId = Integer.parseInt(currentEmpId.replaceAll("[^0-9]", ""));
            } catch (Exception ignored) {}
            sql.append("AND (a.employee_id = ? OR a.employee_id IN (" +
                       "    SELECT tm.employee_id FROM team_members tm " +
                       "    JOIN teams t ON tm.team_id = t.id " +
                       "    WHERE t.manager_id = ? OR t.manager_id = ?)) ");
            params.add(currentEmpId);
            params.add(numericMgrId);
            params.add(currentEmpId);
        }

        if (targetEmpId != null && !targetEmpId.isBlank() && !"ALL".equalsIgnoreCase(targetEmpId)) {
            sql.append("AND a.employee_id = ? ");
            params.add(targetEmpId.trim());
        }

        if (status != null && !status.isBlank() && !"ALL".equalsIgnoreCase(status)) {
            if ("PENDING".equalsIgnoreCase(status.trim())) {
                sql.append("AND UPPER(a.status) = 'LEAVE' ");
            } else if ("APPROVED".equalsIgnoreCase(status.trim())) {
                sql.append("AND UPPER(a.status) LIKE '%APPROV%' ");
            } else if ("REJECTED".equalsIgnoreCase(status.trim())) {
                sql.append("AND UPPER(a.status) LIKE '%REJECT%' ");
            } else {
                sql.append("AND UPPER(a.status) = UPPER(?) ");
                params.add(status.trim());
            }
        }

        if (fromDate != null && !fromDate.isBlank()) {
            sql.append("AND a.attendance_date >= ? ");
            params.add(java.sql.Date.valueOf(fromDate.trim()));
        }
        if (toDate != null && !toDate.isBlank()) {
            sql.append("AND a.attendance_date <= ? ");
            params.add(java.sql.Date.valueOf(toDate.trim()));
        }

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            for (int i = 0; i < params.size(); i++) ps.setObject(i + 1, params.get(i));
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) return rs.getInt(1);
            }
        } catch (SQLException e) {
            System.err.println("SQL error in countLeaves: " + e.getMessage());
            e.printStackTrace();
        }
        return 0;
    }

    public List<ReportItem> getLeaveReportPaginated(String role, String currentEmpId, String targetEmpId, String status, String fromDate, String toDate, int offset, int limit) {
        List<ReportItem> list = new ArrayList<>();
        StringBuilder sql = new StringBuilder(
            "SELECT a.attendance_id, a.employee_id, a.attendance_date, a.status, " +
            "COALESCE((SELECT name FROM employee WHERE employee_id = a.employee_id LIMIT 1), a.employee_id) AS emp_name, " +
            "COALESCE(a.reason, 'Casual / Sick Leave') AS leave_reason " +
            "FROM attendance a " +
            "LEFT JOIN team_members tm ON a.employee_id = tm.employee_id " +
            "LEFT JOIN teams t ON tm.team_id = t.id " +
            "WHERE UPPER(a.status) LIKE '%LEAVE%' "
        );
        List<Object> params = new ArrayList<>();

        String cleanRole = (role != null) ? role.trim().toUpperCase() : "EMPLOYEE";

        if ("EMPLOYEE".equals(cleanRole)) {
            sql.append("AND a.employee_id = ? ");
            params.add(currentEmpId);
        } else if ("MANAGER".equals(cleanRole)) {
            int numericMgrId = 0;
            try {
                numericMgrId = Integer.parseInt(currentEmpId.replaceAll("[^0-9]", ""));
            } catch (Exception ignored) {}
            sql.append("AND (a.employee_id = ? OR a.employee_id IN (" +
                       "    SELECT tm.employee_id FROM team_members tm " +
                       "    JOIN teams t ON tm.team_id = t.id " +
                       "    WHERE t.manager_id = ? OR t.manager_id = ?)) ");
            params.add(currentEmpId);
            params.add(numericMgrId);
            params.add(currentEmpId);
        }

        if (targetEmpId != null && !targetEmpId.isBlank() && !"ALL".equalsIgnoreCase(targetEmpId)) {
            sql.append("AND a.employee_id = ? ");
            params.add(targetEmpId.trim());
        }

        if (status != null && !status.isBlank() && !"ALL".equalsIgnoreCase(status)) {
            if ("PENDING".equalsIgnoreCase(status.trim())) {
                sql.append("AND UPPER(a.status) = 'LEAVE' ");
            } else if ("APPROVED".equalsIgnoreCase(status.trim())) {
                sql.append("AND UPPER(a.status) LIKE '%APPROV%' ");
            } else if ("REJECTED".equalsIgnoreCase(status.trim())) {
                sql.append("AND UPPER(a.status) LIKE '%REJECT%' ");
            } else {
                sql.append("AND UPPER(a.status) = UPPER(?) ");
                params.add(status.trim());
            }
        }

        if (fromDate != null && !fromDate.isBlank()) {
            sql.append("AND a.attendance_date >= ? ");
            params.add(java.sql.Date.valueOf(fromDate.trim()));
        }
        if (toDate != null && !toDate.isBlank()) {
            sql.append("AND a.attendance_date <= ? ");
            params.add(java.sql.Date.valueOf(toDate.trim()));
        }

        sql.append("GROUP BY a.attendance_id ORDER BY a.attendance_date DESC LIMIT ? OFFSET ?");
        params.add(limit);
        params.add(offset);

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            for (int i = 0; i < params.size(); i++) ps.setObject(i + 1, params.get(i));
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    ReportItem item = new ReportItem();
                    item.setId(rs.getString("attendance_id"));
                    item.setEmployeeId(rs.getString("employee_id"));
                    item.setEmployeeName(rs.getString("emp_name"));
                    item.setTitle("Casual / Sick Leave");

                    java.sql.Date d = rs.getDate("attendance_date");
                    if (d != null) {
                        item.setStartDate(d.toLocalDate());
                        item.setEndDate(d.toLocalDate());
                    }

                    item.setDetails(rs.getString("leave_reason"));

                    String st = rs.getString("status");
                    if (st != null) {
                        st = st.toUpperCase().trim();
                        if ("LEAVE".equals(st)) item.setStatus("PENDING");
                        else if (st.contains("APPROV")) item.setStatus("APPROVED");
                        else if (st.contains("REJECT")) item.setStatus("REJECTED");
                        else item.setStatus(st);
                    } else {
                        item.setStatus("PENDING");
                    }

                    list.add(item);
                }
            }
        } catch (SQLException e) {
            System.err.println("SQL error in getLeaveReportPaginated: " + e.getMessage());
            e.printStackTrace();
        }
        return list;
    }

    public List<ReportItem> getLeaveReport(String role, String currentEmpId, String targetEmpId, String status, String fromDate, String toDate, Map<String, Integer> summary) {
        List<ReportItem> list = getLeaveReportPaginated(role, currentEmpId, targetEmpId, status, fromDate, toDate, 0, Integer.MAX_VALUE);
        int pending = 0, approved = 0, rejected = 0, cancelled = 0;
        for (ReportItem item : list) {
            String st = (item.getStatus() != null) ? item.getStatus().toUpperCase() : "";
            if ("APPROVED".equals(st)) approved++;
            else if ("REJECTED".equals(st)) rejected++;
            else if ("CANCELLED".equals(st)) cancelled++;
            else pending++;
        }
        if (summary != null) {
            summary.put("PENDING", pending);
            summary.put("APPROVED", approved);
            summary.put("REJECTED", rejected);
            summary.put("CANCELLED", cancelled);
        }
        return list;
    }

    // ==========================================
    // 3. TASK REPORT (TASK_ID, RATING & FEEDBACK ENABLED)
    // ==========================================
    public int countTasks(String role, String currentEmpId, String targetEmpId, String status, String fromDate, String toDate) {
        StringBuilder sql = new StringBuilder("SELECT COUNT(*) FROM tasks t WHERE 1=1 ");
        List<Object> params = new ArrayList<>();

        String cleanRole = (role != null) ? role.trim().toUpperCase() : "EMPLOYEE";

        if ("MANAGER".equals(cleanRole)) {
            int numericMgrId = 0;
            try {
                numericMgrId = Integer.parseInt(currentEmpId.replaceAll("[^0-9]", ""));
            } catch (Exception ignored) {}
            sql.append("AND (t.assigned_by = ? OR t.assigned_to = ? " +
                       "OR t.assigned_to IN (SELECT tm.employee_id FROM team_members tm " +
                       "                     JOIN teams tm_t ON tm.team_id = tm_t.id " +
                       "                     WHERE tm_t.manager_id = CAST(? AS UNSIGNED) OR tm_t.manager_id = ?)) ");
            params.add(currentEmpId);
            params.add(currentEmpId);
            params.add(numericMgrId);
            params.add(currentEmpId);
        }

        if (targetEmpId != null && !targetEmpId.isBlank() && !"ALL".equalsIgnoreCase(targetEmpId)) {
            sql.append("AND t.assigned_to = ? ");
            params.add(targetEmpId.trim());
        }
        if (status != null && !status.isBlank() && !"ALL".equalsIgnoreCase(status)) {
            sql.append("AND UPPER(t.status) = UPPER(?) ");
            params.add(status.trim());
        }
        if (fromDate != null && !fromDate.isBlank()) {
            sql.append("AND t.due_date >= ? ");
            params.add(java.sql.Date.valueOf(fromDate.trim()));
        }
        if (toDate != null && !toDate.isBlank()) {
            sql.append("AND t.due_date <= ? ");
            params.add(java.sql.Date.valueOf(toDate.trim()));
        }

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            for (int i = 0; i < params.size(); i++) ps.setObject(i + 1, params.get(i));
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) return rs.getInt(1);
            }
        } catch (SQLException e) {
            System.err.println("SQL Error in countTasks: " + e.getMessage());
        }
        return 0;
    }

    public List<ReportItem> getTaskReportPaginated(String role, String currentEmpId, String targetEmpId, String status, String fromDate, String toDate, int offset, int limit) {
        List<ReportItem> list = new ArrayList<>();
        
        StringBuilder sql = new StringBuilder(
            "SELECT t.task_id, t.title, t.assigned_to, t.assigned_by, t.start_date, t.due_date, " +
            "t.priority, t.status, t.rating, t.manager_feedback, " +
            "COALESCE((SELECT name FROM employee WHERE employee_id = t.assigned_to LIMIT 1), t.assigned_to) AS emp_name " +
            "FROM tasks t WHERE 1=1 "
        );
        List<Object> params = new ArrayList<>();

        String cleanRole = (role != null) ? role.trim().toUpperCase() : "EMPLOYEE";

        if ("MANAGER".equals(cleanRole)) {
            int numericMgrId = 0;
            try {
                numericMgrId = Integer.parseInt(currentEmpId.replaceAll("[^0-9]", ""));
            } catch (Exception ignored) {}
            sql.append("AND (t.assigned_by = ? OR t.assigned_to = ? " +
                       "OR t.assigned_to IN (SELECT tm.employee_id FROM team_members tm " +
                       "                     JOIN teams tm_t ON tm.team_id = tm_t.id " +
                       "                     WHERE tm_t.manager_id = CAST(? AS UNSIGNED) OR tm_t.manager_id = ?)) ");
            params.add(currentEmpId);
            params.add(currentEmpId);
            params.add(numericMgrId);
            params.add(currentEmpId);
        }

        if (targetEmpId != null && !targetEmpId.isBlank() && !"ALL".equalsIgnoreCase(targetEmpId)) {
            sql.append("AND t.assigned_to = ? ");
            params.add(targetEmpId.trim());
        }
        if (status != null && !status.isBlank() && !"ALL".equalsIgnoreCase(status)) {
            sql.append("AND UPPER(t.status) = UPPER(?) ");
            params.add(status.trim());
        }
        if (fromDate != null && !fromDate.isBlank()) {
            sql.append("AND t.due_date >= ? ");
            params.add(java.sql.Date.valueOf(fromDate.trim()));
        }
        if (toDate != null && !toDate.isBlank()) {
            sql.append("AND t.due_date <= ? ");
            params.add(java.sql.Date.valueOf(toDate.trim()));
        }

        sql.append("ORDER BY t.task_id DESC LIMIT ? OFFSET ?");
        params.add(limit);
        params.add(offset);

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            for (int i = 0; i < params.size(); i++) ps.setObject(i + 1, params.get(i));
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    ReportItem item = new ReportItem();
                    item.setId(String.valueOf(rs.getInt("task_id")));
                    item.setTitle(rs.getString("title"));
                    item.setEmployeeId(rs.getString("assigned_to"));
                    item.setEmployeeName(rs.getString("emp_name") != null ? rs.getString("emp_name") : rs.getString("assigned_to"));

                    java.sql.Date sd = rs.getDate("start_date");
                    if (sd != null) item.setStartDate(sd.toLocalDate());

                    java.sql.Date dd = rs.getDate("due_date");
                    if (dd != null) item.setEndDate(dd.toLocalDate());

                    item.setExtra(rs.getString("priority"));
                    item.setStatus(rs.getString("status") != null ? rs.getString("status").toUpperCase() : "ASSIGNED");

                    // Read Rating and Feedback from ResultSet
                    int rVal = rs.getInt("rating");
                    String fb = rs.getString("manager_feedback");

                    // Store both rating and feedback into 'details' safely using delimiter '::'
                    // Example format stored: "4::need improve" or "0::"
                    item.setDetails(rVal + "::" + (fb != null ? fb : ""));

                    list.add(item);
                }
            }
        } catch (SQLException e) {
            System.err.println("SQL Error in getTaskReportPaginated: " + e.getMessage());
            e.printStackTrace();
        }
        return list;
    }

    public List<ReportItem> getTaskReport(String role, String currentEmpId, String targetEmpId, String status, String fromDate, String toDate, Map<String, Integer> summary) {
        List<ReportItem> list = getTaskReportPaginated(role, currentEmpId, targetEmpId, status, fromDate, toDate, 0, Integer.MAX_VALUE);
        int assigned = 0, inProg = 0, onHold = 0, completed = 0, cancelled = 0;
        for (ReportItem item : list) {
            String st = (item.getStatus() != null) ? item.getStatus().toUpperCase() : "";
            if ("COMPLETED".equals(st)) {
                completed++;
            } else if ("IN_PROGRESS".equals(st)) {
                inProg++;
            } else if ("SUBMITTED_FOR_REVIEW".equals(st) || "ON_HOLD".equals(st)) {
                onHold++;
            } else if ("CANCELLED".equals(st)) {
                cancelled++;
            } else {
                assigned++;
            }
        }
        if (summary != null) {
            summary.put("ASSIGNED", assigned);
            summary.put("IN_PROGRESS", inProg);
            summary.put("ON_HOLD", onHold);
            summary.put("COMPLETED", completed);
            summary.put("CANCELLED", cancelled);
        }
        return list;
    }

    // ==========================================
    // 4. DRILL-DOWN HIERARCHY METHODS
    // ==========================================

    // Level 1: Fetch all managers for Admin view
    public List<Map<String, Object>> getAllManagers() {
        List<Map<String, Object>> list = new ArrayList<>();
        String sql = "SELECT e.employee_id, e.name, e.email, e.department, " +
                     "(SELECT COUNT(*) FROM teams t WHERE t.manager_id = e.employee_id " +
                     " OR t.manager_id = CAST(REPLACE(e.employee_id, 'MGR', '') AS UNSIGNED)) AS team_count " +
                     "FROM employee e WHERE UPPER(e.role) = 'MANAGER' ORDER BY e.name ASC";

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                Map<String, Object> map = new HashMap<>();
                map.put("employee_id", rs.getString("employee_id"));
                map.put("name", rs.getString("name"));
                map.put("email", rs.getString("email"));
                map.put("department", rs.getString("department"));
                map.put("team_count", rs.getInt("team_count"));
                list.add(map);
            }
        } catch (SQLException e) {
            System.err.println("Error in getAllManagers: " + e.getMessage());
        }
        return list;
    }

    // Level 2: Fetch teams under a specific manager
    public List<Map<String, Object>> getTeamsByManager(String managerId) {
        List<Map<String, Object>> list = new ArrayList<>();
        int numericMgrId = 0;
        try {
            numericMgrId = Integer.parseInt(managerId.replaceAll("[^0-9]", ""));
        } catch (Exception ignored) {}

        String sql = "SELECT t.id, t.team_name, " +
                     "(SELECT COUNT(*) FROM team_members tm WHERE tm.team_id = t.id) AS member_count, " +
                     "(SELECT COUNT(*) FROM tasks tk WHERE tk.team_id = t.id) AS task_count " +
                     "FROM teams t " +
                     "WHERE t.manager_id = ? OR t.manager_id = ? ORDER BY t.team_name ASC";

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, managerId.trim());
            ps.setInt(2, numericMgrId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> map = new HashMap<>();
                    map.put("id", rs.getInt("id"));
                    map.put("team_name", rs.getString("team_name"));
                    map.put("member_count", rs.getInt("member_count"));
                    map.put("task_count", rs.getInt("task_count"));
                    list.add(map);
                }
            }
        } catch (SQLException e) {
            System.err.println("Error in getTeamsByManager: " + e.getMessage());
        }
        return list;
    }

    // Level 3A: Fetch members of a team
    public List<Map<String, Object>> getTeamMembers(int teamId) {
        List<Map<String, Object>> list = new ArrayList<>();
        String sql = "SELECT e.employee_id, e.name, e.email, e.department " +
                     "FROM team_members tm " +
                     "JOIN employee e ON tm.employee_id = e.employee_id " +
                     "WHERE tm.team_id = ? ORDER BY e.name ASC";

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, teamId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> map = new HashMap<>();
                    map.put("employee_id", rs.getString("employee_id"));
                    map.put("name", rs.getString("name"));
                    map.put("email", rs.getString("email"));
                    map.put("department", rs.getString("department"));
                    list.add(map);
                }
            }
        } catch (SQLException e) {
            System.err.println("Error in getTeamMembers: " + e.getMessage());
        }
        return list;
    }

    // Level 3B: Fetch tasks assigned to a specific team with rating & feedback
    public List<Map<String, Object>> getTeamTasks(int teamId) {
        List<Map<String, Object>> list = new ArrayList<>();
        String sql = "SELECT t.task_id, t.title, t.assigned_to, t.due_date, t.priority, t.status, " +
                     "t.rating, t.manager_feedback, " +
                     "COALESCE((SELECT name FROM employee WHERE employee_id = t.assigned_to LIMIT 1), t.assigned_to) AS emp_name " +
                     "FROM tasks t WHERE t.team_id = ? ORDER BY t.task_id DESC";

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, teamId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> map = new HashMap<>();
                    map.put("task_id", rs.getInt("task_id"));
                    map.put("title", rs.getString("title"));
                    map.put("assigned_to", rs.getString("assigned_to"));
                    map.put("emp_name", rs.getString("emp_name"));
                    map.put("due_date", rs.getDate("due_date"));
                    map.put("priority", rs.getString("priority"));
                    map.put("status", rs.getString("status"));
                    map.put("rating", rs.getInt("rating"));
                    map.put("manager_feedback", rs.getString("manager_feedback"));
                    list.add(map);
                }
            }
        } catch (SQLException e) {
            System.err.println("Error in getTeamTasks: " + e.getMessage());
        }
        return list;
    }
// ==========================================
// 5. TEAMS CATALOG WITH FULL DETAILS
// ==========================================
public List<Map<String, Object>> getFullTeamsCatalog() {
    List<Map<String, Object>> list = new ArrayList<>();
    String sql = "SELECT t.id, t.team_name, " +
                 "COALESCE(t.status, 'ACTIVE') AS status, " +
                 "COALESCE(e.name, 'Unassigned') AS manager_name, " +
                 "COALESCE(e.employee_id, t.manager_id, 'None') AS manager_id, " +
                 "COALESCE(e.department, 'Engineering') AS department, " +
                 "(SELECT COUNT(*) FROM team_members tm WHERE tm.team_id = t.id) AS member_count " +
                 "FROM teams t " +
                 "LEFT JOIN employee e ON (e.employee_id = t.manager_id " +
                 "   OR e.employee_id = CONCAT('MGR', LPAD(t.manager_id, 2, '0')) " +
                 "   OR e.employee_id = CAST(t.manager_id AS CHAR)) " +
                 "ORDER BY t.id DESC";

    try (Connection conn = DBConnection.getConnection();
         PreparedStatement ps = conn.prepareStatement(sql);
         ResultSet rs = ps.executeQuery()) {
        while (rs.next()) {
            Map<String, Object> map = new HashMap<>();
            map.put("id", rs.getInt("id"));
            map.put("team_name", rs.getString("team_name"));
            map.put("status", rs.getString("status"));
            map.put("manager_name", rs.getString("manager_name"));
            map.put("manager_id", rs.getString("manager_id"));
            map.put("department", rs.getString("department"));
            map.put("member_count", rs.getInt("member_count"));
            list.add(map);
        }
    } catch (SQLException e) {
        System.err.println("Error in getFullTeamsCatalog: " + e.getMessage());
    }
    return list;
}
//==========================================
// HELPER: GET MANAGER ID FOR A SPECIFIC TEAM
// ==========================================
public String getManagerIdByTeam(int teamId) {
    String sql = "SELECT manager_id FROM teams WHERE id = ?";
    try (Connection conn = DBConnection.getConnection();
         PreparedStatement ps = conn.prepareStatement(sql)) {
        ps.setInt(1, teamId);
        try (ResultSet rs = ps.executeQuery()) {
            if (rs.next()) {
                return rs.getString("manager_id");
            }
        }
    } catch (SQLException e) {
        System.err.println("Error in getManagerIdByTeam: " + e.getMessage());
    }
    return null;
}}