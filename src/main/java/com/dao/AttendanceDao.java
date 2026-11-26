package com.dao;

import com.model.Attendance;
import com.Util.DBConnection;

import java.sql.*;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.List;

public class AttendanceDao {

    private static final String SELECT_COLUMNS = 
            "attendance_id, employee_id, attendance_date, check_in_time, " +
            "break1_start_time, break1_end_time, break2_start_time, break2_end_time, " +
            "check_out_time, status, reason, leave_status, rejection_reason, net_working_minutes, approved_ot_hours ";

    public Attendance findRecord(String employeeId, LocalDate date) {
        String query = "SELECT " + SELECT_COLUMNS + 
                       "FROM attendance " +
                       "WHERE TRIM(REPLACE(employee_id, ' ', '')) = TRIM(REPLACE(?, ' ', '')) " +
                       "  AND attendance_date = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query)) {
            ps.setString(1, employeeId);
            ps.setDate(2, Date.valueOf(date));
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return mapRow(rs);
                }
            }
        } catch (SQLException e) {
            System.err.println("DB Error in findRecord: " + e.getMessage());
        }
        return null;
    }

    public void save(Attendance attendance) {
        String query = "INSERT INTO attendance (attendance_id, employee_id, attendance_date, check_in_time, " +
                       "break1_start_time, break1_end_time, break2_start_time, break2_end_time, " +
                       "check_out_time, status, reason, leave_status, rejection_reason, net_working_minutes, approved_ot_hours) " +
                       "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query)) {
            ps.setString(1, attendance.getAttendanceId());
            ps.setString(2, attendance.getEmployeeId());
            ps.setDate(3, Date.valueOf(attendance.getAttendanceDate()));
            ps.setTime(4, attendance.getCheckInTime() != null ? Time.valueOf(attendance.getCheckInTime()) : null);
            ps.setTime(5, attendance.getBreak1StartTime() != null ? Time.valueOf(attendance.getBreak1StartTime()) : null);
            ps.setTime(6, attendance.getBreak1EndTime() != null ? Time.valueOf(attendance.getBreak1EndTime()) : null);
            ps.setTime(7, attendance.getBreak2StartTime() != null ? Time.valueOf(attendance.getBreak2StartTime()) : null);
            ps.setTime(8, attendance.getBreak2EndTime() != null ? Time.valueOf(attendance.getBreak2EndTime()) : null);
            ps.setTime(9, attendance.getCheckOutTime() != null ? Time.valueOf(attendance.getCheckOutTime()) : null);
            ps.setString(10, attendance.getStatus());
            ps.setString(11, attendance.getReason());
            ps.setString(12, attendance.getLeaveStatus() != null ? attendance.getLeaveStatus() : "NONE");
            ps.setString(13, attendance.getRejectionReason());
            ps.setInt(14, attendance.getNetWorkingMinutes());
            ps.setDouble(15, attendance.getApprovedOtHours());
            ps.executeUpdate();
        } catch (SQLException e) {
            throw new RuntimeException("Failed to save attendance record: " + e.getMessage());
        }
    }

    // --- Break 1 Management ---
    public void updateBreak1Start(String attendanceId, LocalTime breakStart) {
        String query = "UPDATE attendance SET break1_start_time = ? WHERE attendance_id = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query)) {
            ps.setTime(1, Time.valueOf(breakStart));
            ps.setString(2, attendanceId);
            ps.executeUpdate();
        } catch (SQLException e) {
            throw new RuntimeException("Failed to update Break 1 start: " + e.getMessage());
        }
    }

    public void updateBreak1End(String attendanceId, LocalTime breakEnd) {
        String query = "UPDATE attendance SET break1_end_time = ? WHERE attendance_id = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query)) {
            ps.setTime(1, Time.valueOf(breakEnd));
            ps.setString(2, attendanceId);
            ps.executeUpdate();
        } catch (SQLException e) {
            throw new RuntimeException("Failed to update Break 1 end: " + e.getMessage());
        }
    }

    // --- Break 2 Management ---
    public void updateBreak2Start(String attendanceId, LocalTime breakStart) {
        String query = "UPDATE attendance SET break2_start_time = ? WHERE attendance_id = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query)) {
            ps.setTime(1, Time.valueOf(breakStart));
            ps.setString(2, attendanceId);
            ps.executeUpdate();
        } catch (SQLException e) {
            throw new RuntimeException("Failed to update Break 2 start: " + e.getMessage());
        }
    }

    public void updateBreak2End(String attendanceId, LocalTime breakEnd) {
        String query = "UPDATE attendance SET break2_end_time = ? WHERE attendance_id = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query)) {
            ps.setTime(1, Time.valueOf(breakEnd));
            ps.setString(2, attendanceId);
            ps.executeUpdate();
        } catch (SQLException e) {
            throw new RuntimeException("Failed to update Break 2 end: " + e.getMessage());
        }
    }

    // --- Check Out Management ---
    public void updateCheckOutWithMetrics(String attendanceId, LocalTime checkOutTime, String status, int netMinutes) {
        String query = "UPDATE attendance SET check_out_time = ?, status = ?, net_working_minutes = ? WHERE attendance_id = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query)) {
            ps.setTime(1, Time.valueOf(checkOutTime));
            ps.setString(2, status);
            ps.setInt(3, netMinutes);
            ps.setString(4, attendanceId);
            ps.executeUpdate();
        } catch (SQLException e) {
            throw new RuntimeException("Failed to complete check-out: " + e.getMessage());
        }
    }

    public void updateCheckOut(String attendanceId, LocalTime checkOutTime, String status) {
        String query = "UPDATE attendance SET check_out_time = ?, status = ? WHERE attendance_id = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query)) {
            ps.setTime(1, Time.valueOf(checkOutTime));
            ps.setString(2, status);
            ps.setString(3, attendanceId);
            ps.executeUpdate();
        } catch (SQLException e) {
            throw new RuntimeException("Failed to update check-out: " + e.getMessage());
        }
    }

    // --- Leave Workflow Management ---
    public void recordLeave(String employeeId, LocalDate date, String reason) {
        int nextSeq = getNextAttendanceSequence();
        String attendanceId = String.format("ATT%03d", nextSeq);

        String query = "INSERT INTO attendance (attendance_id, employee_id, attendance_date, status, reason, leave_status) " +
                       "VALUES (?, ?, ?, 'LEAVE', ?, 'PENDING') " +
                       "ON DUPLICATE KEY UPDATE status = 'LEAVE', reason = VALUES(reason), leave_status = 'PENDING'";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query)) {
            ps.setString(1, attendanceId);
            ps.setString(2, employeeId);
            ps.setDate(3, Date.valueOf(date));
            ps.setString(4, (reason != null && !reason.isBlank()) ? reason.trim() : "Personal Leave");
            ps.executeUpdate();
        } catch (SQLException e) {
            throw new RuntimeException("Failed to record leave: " + e.getMessage());
        }
    }

    public boolean updateLeaveStatus(String attendanceId, String decision, String rejectionReason) {
        String sql = "UPDATE attendance SET leave_status = ?, rejection_reason = ?, " +
                     "status = CASE WHEN UPPER(?) = 'APPROVED' THEN 'LEAVE' WHEN UPPER(?) = 'REJECTED' THEN 'ABSENT' ELSE status END " +
                     "WHERE TRIM(attendance_id) = TRIM(?)";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {

            String dec = decision.trim().toUpperCase();
            ps.setString(1, dec);
            ps.setString(2, (rejectionReason != null && !rejectionReason.isBlank()) ? rejectionReason.trim() : null);
            ps.setString(3, dec);
            ps.setString(4, dec);
            ps.setString(5, attendanceId.trim());

            return ps.executeUpdate() > 0;
        } catch (SQLException e) {
            System.err.println("Error updating leave decision: " + e.getMessage());
            return false;
        }
    }

    public void updateLeaveStatusWithRemarks(String attendanceId, String newStatus, String remarks) {
        updateLeaveStatus(attendanceId, newStatus, remarks);
    }

    public List<Attendance> findPendingLeavesByRole(String targetRole) {
        List<Attendance> list = new ArrayList<>();
        String query = "SELECT a.*, e.name AS emp_name " +
                       "FROM attendance a " +
                       "JOIN employee e ON LOWER(TRIM(a.employee_id)) = LOWER(TRIM(e.employee_id)) " +
                       "WHERE (UPPER(TRIM(a.leave_status)) IN ('PENDING', 'PENDING_APPROVAL') " +
                       "       OR (UPPER(TRIM(a.status)) = 'PENDING' AND (a.leave_status IS NULL OR UPPER(TRIM(a.leave_status)) != 'APPROVED'))) " +
                       "  AND UPPER(TRIM(e.role)) = UPPER(TRIM(?)) " +
                       "ORDER BY a.attendance_date ASC";

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query)) {

            ps.setString(1, targetRole.trim().toUpperCase());

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Attendance att = mapRow(rs);
                    try {
                        att.setEmployeeName(rs.getString("emp_name"));
                    } catch (SQLException ignored) {}
                    list.add(att);
                }
            }
        } catch (SQLException e) {
            System.err.println("DB Error in findPendingLeavesByRole: " + e.getMessage());
        }
        return list;
    }

    public List<Attendance> findPendingLeaveRequests() {
        List<Attendance> list = new ArrayList<>();
        String query = "SELECT a.*, e.name AS emp_name " +
                       "FROM attendance a " +
                       "LEFT JOIN employee e ON LOWER(TRIM(a.employee_id)) = LOWER(TRIM(e.employee_id)) " +
                       "WHERE UPPER(TRIM(a.leave_status)) IN ('PENDING', 'PENDING_APPROVAL') " +
                       "   OR (UPPER(TRIM(a.status)) = 'PENDING' AND (a.leave_status IS NULL OR UPPER(TRIM(a.leave_status)) != 'APPROVED')) " +
                       "ORDER BY a.attendance_date ASC";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                Attendance att = mapRow(rs);
                try {
                    att.setEmployeeName(rs.getString("emp_name"));
                } catch (SQLException ignored) {}
                list.add(att);
            }
        } catch (SQLException e) {
            System.err.println("DB Error in findPendingLeaveRequests: " + e.getMessage());
        }
        return list;
    }

    // --- Dynamic Auto Check-Out Rule (6:15 PM + approved_ot_hours) ---
    public void autoCheckOutUnclosedShifts() {
        // Effective checkout target time: 18:15:00 plus any approved OT minutes
        String query = 
            "UPDATE attendance " +
            "SET check_out_time = ADDTIME(TIMESTAMP(attendance_date, '18:15:00'), SEC_TO_TIME(IFNULL(approved_ot_hours, 0) * 3600)), " +
            "    net_working_minutes = GREATEST(0, " +
            "        TIMESTAMPDIFF(MINUTE, " +
            "            IF(check_in_time > ADDTIME('18:15:00', SEC_TO_TIME(IFNULL(approved_ot_hours, 0) * 3600)), " +
            "               ADDTIME(TIMESTAMP(attendance_date, '18:15:00'), SEC_TO_TIME(IFNULL(approved_ot_hours, 0) * 3600)), " +
            "               IF(LENGTH(check_in_time) <= 8, TIMESTAMP(attendance_date, check_in_time), check_in_time)), " +
            "            ADDTIME(TIMESTAMP(attendance_date, '18:15:00'), SEC_TO_TIME(IFNULL(approved_ot_hours, 0) * 3600))" +
            "        ) - " +
            "        (IFNULL(TIMESTAMPDIFF(MINUTE, " +
            "             IF(LENGTH(break1_start_time) <= 8, TIMESTAMP(attendance_date, break1_start_time), break1_start_time), " +
            "             IFNULL(IF(LENGTH(break1_end_time) <= 8, TIMESTAMP(attendance_date, break1_end_time), break1_end_time), ADDTIME(TIMESTAMP(attendance_date, '18:15:00'), SEC_TO_TIME(IFNULL(approved_ot_hours, 0) * 3600)))" +
            "         ), 0) + " +
            "         IFNULL(TIMESTAMPDIFF(MINUTE, " +
            "             IF(LENGTH(break2_start_time) <= 8, TIMESTAMP(attendance_date, break2_start_time), break2_start_time), " +
            "             IFNULL(IF(LENGTH(break2_end_time) <= 8, TIMESTAMP(attendance_date, break2_end_time), break2_end_time), ADDTIME(TIMESTAMP(attendance_date, '18:15:00'), SEC_TO_TIME(IFNULL(approved_ot_hours, 0) * 3600)))" +
            "         ), 0))" +
            "    ), " +
            "    status = CASE " +
            "        WHEN (TIMESTAMPDIFF(MINUTE, " +
            "                IF(check_in_time > ADDTIME('18:15:00', SEC_TO_TIME(IFNULL(approved_ot_hours, 0) * 3600)), " +
            "                   ADDTIME(TIMESTAMP(attendance_date, '18:15:00'), SEC_TO_TIME(IFNULL(approved_ot_hours, 0) * 3600)), " +
            "                   IF(LENGTH(check_in_time) <= 8, TIMESTAMP(attendance_date, check_in_time), check_in_time)), " +
            "                ADDTIME(TIMESTAMP(attendance_date, '18:15:00'), SEC_TO_TIME(IFNULL(approved_ot_hours, 0) * 3600))) - " +
            "             (IFNULL(TIMESTAMPDIFF(MINUTE, " +
            "                  IF(LENGTH(break1_start_time) <= 8, TIMESTAMP(attendance_date, break1_start_time), break1_start_time), " +
            "                  IFNULL(IF(LENGTH(break1_end_time) <= 8, TIMESTAMP(attendance_date, break1_end_time), break1_end_time), ADDTIME(TIMESTAMP(attendance_date, '18:15:00'), SEC_TO_TIME(IFNULL(approved_ot_hours, 0) * 3600)))), 0) + " +
            "              IFNULL(TIMESTAMPDIFF(MINUTE, " +
            "                  IF(LENGTH(break2_start_time) <= 8, TIMESTAMP(attendance_date, break2_start_time), break2_start_time), " +
            "                  IFNULL(IF(LENGTH(break2_end_time) <= 8, TIMESTAMP(attendance_date, break2_end_time), break2_end_time), ADDTIME(TIMESTAMP(attendance_date, '18:15:00'), SEC_TO_TIME(IFNULL(approved_ot_hours, 0) * 3600)))), 0))" +
            "        ) >= 480 THEN 'PRESENT' " +
            "        WHEN (TIMESTAMPDIFF(MINUTE, " +
            "                IF(check_in_time > ADDTIME('18:15:00', SEC_TO_TIME(IFNULL(approved_ot_hours, 0) * 3600)), " +
            "                   ADDTIME(TIMESTAMP(attendance_date, '18:15:00'), SEC_TO_TIME(IFNULL(approved_ot_hours, 0) * 3600)), " +
            "                   IF(LENGTH(check_in_time) <= 8, TIMESTAMP(attendance_date, check_in_time), check_in_time)), " +
            "                ADDTIME(TIMESTAMP(attendance_date, '18:15:00'), SEC_TO_TIME(IFNULL(approved_ot_hours, 0) * 3600))) - " +
            "             (IFNULL(TIMESTAMPDIFF(MINUTE, " +
            "                  IF(LENGTH(break1_start_time) <= 8, TIMESTAMP(attendance_date, break1_start_time), break1_start_time), " +
            "                  IFNULL(IF(LENGTH(break1_end_time) <= 8, TIMESTAMP(attendance_date, break1_end_time), break1_end_time), ADDTIME(TIMESTAMP(attendance_date, '18:15:00'), SEC_TO_TIME(IFNULL(approved_ot_hours, 0) * 3600)))), 0) + " +
            "              IFNULL(TIMESTAMPDIFF(MINUTE, " +
            "                  IF(LENGTH(break2_start_time) <= 8, TIMESTAMP(attendance_date, break2_start_time), break2_start_time), " +
            "                  IFNULL(IF(LENGTH(break2_end_time) <= 8, TIMESTAMP(attendance_date, break2_end_time), break2_end_time), ADDTIME(TIMESTAMP(attendance_date, '18:15:00'), SEC_TO_TIME(IFNULL(approved_ot_hours, 0) * 3600)))), 0))" +
            "        ) >= 240 THEN 'HALF_DAY' " +
            "        ELSE 'ABSENT' " +
            "    END " +
            "WHERE check_in_time IS NOT NULL " +
            "  AND (check_out_time IS NULL OR check_out_time = '00:00:00') " +
            "  AND ((attendance_date = CURDATE() AND CURTIME() >= ADDTIME('18:15:00', SEC_TO_TIME(IFNULL(approved_ot_hours, 0) * 3600))) " +
            "       OR attendance_date < CURDATE())";

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query)) {
            int rows = ps.executeUpdate();
            if (rows > 0) {
                System.out.println("Auto checked out " + rows + " shift(s) (including OT adjustments).");
            }
        } catch (SQLException e) {
            System.err.println("Auto check-out error: " + e.getMessage());
        }
    }

    public List<Attendance> findByEmployeeId(String employeeId) {
        List<Attendance> list = new ArrayList<>();
        String query = "SELECT " + SELECT_COLUMNS + 
                       "FROM attendance " +
                       "WHERE TRIM(REPLACE(employee_id, ' ', '')) = TRIM(REPLACE(?, ' ', '')) " +
                       "ORDER BY attendance_date DESC";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query)) {
            ps.setString(1, employeeId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        } catch (SQLException e) {
            System.err.println("DB Error in findByEmployeeId: " + e.getMessage());
        }
        return list;
    }

    public List<Attendance> findByDate(LocalDate date) {
        List<Attendance> list = new ArrayList<>();
        String query = "SELECT " + SELECT_COLUMNS + "FROM attendance WHERE attendance_date = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query)) {
            ps.setDate(1, Date.valueOf(date));
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        } catch (SQLException e) {
            System.err.println("DB Error in findByDate: " + e.getMessage());
        }
        return list;
    }

    public List<Attendance> findByEmployeeAndMonth(String employeeId, YearMonth ym) {
        List<Attendance> list = new ArrayList<>();
        String query = "SELECT " + SELECT_COLUMNS +
                       "FROM attendance " +
                       "WHERE TRIM(REPLACE(employee_id, ' ', '')) = TRIM(REPLACE(?, ' ', '')) " +
                       "  AND YEAR(attendance_date) = ? AND MONTH(attendance_date) = ? " +
                       "ORDER BY attendance_date DESC";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query)) {
            ps.setString(1, employeeId);
            ps.setInt(2, ym.getYear());
            ps.setInt(3, ym.getMonthValue());
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        } catch (SQLException e) {
            System.err.println("DB Error in findByEmployeeAndMonth: " + e.getMessage());
        }
        return list;
    }

    // --- Compute Monthly Approved Overtime for Payroll ---
    public double getMonthlyApprovedOtHours(String employeeId, int month, int year) {
        String query = "SELECT COALESCE(SUM(approved_ot_hours), 0.0) AS total_ot " +
                       "FROM attendance " +
                       "WHERE TRIM(REPLACE(employee_id, ' ', '')) = TRIM(REPLACE(?, ' ', '')) " +
                       "  AND MONTH(attendance_date) = ? AND YEAR(attendance_date) = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query)) {
            ps.setString(1, employeeId);
            ps.setInt(2, month);
            ps.setInt(3, year);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return rs.getDouble("total_ot");
                }
            }
        } catch (SQLException e) {
            System.err.println("DB Error in getMonthlyApprovedOtHours: " + e.getMessage());
        }
        return 0.0;
    }

    public void resolvePastPendingRecords() {
        autoCheckOutUnclosedShifts();

        String query = "UPDATE attendance " +
                       "SET status = 'ABSENT' " +
                       "WHERE attendance_date < CURDATE() " +
                       "  AND check_in_time IS NULL " +
                       "  AND status = 'PENDING'";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query)) {
            ps.executeUpdate();
        } catch (SQLException e) {
            System.err.println("DB Error resolving pending shifts: " + e.getMessage());
        }
    }

    public int getNextAttendanceSequence() {
        String query = "SELECT COALESCE(MAX(CAST(SUBSTRING(attendance_id, 4) AS UNSIGNED)), 0) FROM attendance WHERE attendance_id LIKE 'ATT%'";
        try (Connection conn = DBConnection.getConnection();
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(query)) {
            if (rs.next()) {
                return rs.getInt(1) + 1;
            }
        } catch (SQLException e) {
            System.err.println("DB Error in sequence: " + e.getMessage());
        }
        return 1;
    }

    private Attendance mapRow(ResultSet rs) throws SQLException {
        Attendance att = new Attendance();
        att.setAttendanceId(rs.getString("attendance_id"));
        att.setEmployeeId(rs.getString("employee_id"));

        Date attDate = rs.getDate("attendance_date");
        LocalDate recordDate = (attDate != null) ? attDate.toLocalDate() : LocalDate.now();
        att.setAttendanceDate(recordDate);

        Time inTime = rs.getTime("check_in_time");
        if (inTime != null) att.setCheckInTime(inTime.toLocalTime());

        Time b1Start = rs.getTime("break1_start_time");
        if (b1Start != null) att.setBreak1StartTime(b1Start.toLocalTime());

        Time b1End = rs.getTime("break1_end_time");
        if (b1End != null) att.setBreak1EndTime(b1End.toLocalTime());

        Time b2Start = rs.getTime("break2_start_time");
        if (b2Start != null) att.setBreak2StartTime(b2Start.toLocalTime());

        Time b2End = rs.getTime("break2_end_time");
        if (b2End != null) att.setBreak2EndTime(b2End.toLocalTime());

        Time outTime = rs.getTime("check_out_time");
        if (outTime != null) att.setCheckOutTime(outTime.toLocalTime());

        att.setStatus(rs.getString("status"));

        try {
            att.setNetWorkingMinutes(rs.getInt("net_working_minutes"));
        } catch (SQLException ignored) {}

        try {
            att.setReason(rs.getString("reason"));
        } catch (SQLException ignored) {}

        try {
            att.setLeaveStatus(rs.getString("leave_status"));
        } catch (SQLException ignored) {}

        try {
            att.setRejectionReason(rs.getString("rejection_reason"));
        } catch (SQLException ignored) {}

        try {
            att.setApprovedOtHours(rs.getDouble("approved_ot_hours"));
        } catch (SQLException ignored) {}

        return att;
    }
}