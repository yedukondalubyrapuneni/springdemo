package com.dao;

import java.sql.*;
import java.util.ArrayList;
import java.util.List;
import com.model.OvertimeRequest;
import com.Util.DBConnection;

public class OvertimeDAO {

    // 1. Employee / Manager submits an OT request
    public boolean applyOvertime(OvertimeRequest req) {
        String sql = "INSERT INTO overtime_requests (employee_id, request_date, requested_hours, reason, status) " +
                     "VALUES (?, ?, ?, ?, 'PENDING')";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, req.getEmployeeId());
            ps.setDate(2, req.getRequestDate());
            ps.setDouble(3, req.getRequestedHours());
            ps.setString(4, req.getReason());
            return ps.executeUpdate() > 0;
        } catch (SQLException e) {
            e.printStackTrace();
            return false;
        }
    }

    // 2. FOR MANAGERS: Strictly fetch requests from regular EMPLOYEES only
    public List<OvertimeRequest> getEmployeeRequestsForManager() {
        List<OvertimeRequest> list = new ArrayList<>();
        String sql = "SELECT o.*, e.role, e.name " +
                     "FROM overtime_requests o " +
                     "JOIN employee e ON LOWER(TRIM(REPLACE(o.employee_id, ' ', ''))) = LOWER(TRIM(REPLACE(e.employee_id, ' ', ''))) " +
                     "WHERE UPPER(TRIM(o.status)) = 'PENDING' AND LOWER(TRIM(e.role)) = 'employee' " +
                     "ORDER BY o.request_date DESC";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                OvertimeRequest r = new OvertimeRequest();
                r.setId(rs.getInt("id"));
                r.setEmployeeId(rs.getString("employee_id"));
                r.setRequestDate(rs.getDate("request_date"));
                r.setRequestedHours(rs.getDouble("requested_hours"));
                r.setReason(rs.getString("reason"));
                r.setStatus(rs.getString("status"));
                list.add(r);
            }
        } catch (SQLException e) {
            System.err.println("DB Error in getEmployeeRequestsForManager: " + e.getMessage());
            e.printStackTrace();
        }
        return list;
    }

    // 3. FOR ADMIN: Strictly fetch requests from MANAGERS (and HR staff if they apply)
    public List<OvertimeRequest> getManagerRequestsForAdmin() {
        List<OvertimeRequest> list = new ArrayList<>();
        String sql = "SELECT o.*, e.role, e.name " +
                     "FROM overtime_requests o " +
                     "JOIN employee e ON LOWER(TRIM(REPLACE(o.employee_id, ' ', ''))) = LOWER(TRIM(REPLACE(e.employee_id, ' ', ''))) " +
                     "WHERE UPPER(TRIM(o.status)) = 'PENDING' AND LOWER(TRIM(e.role)) IN ('manager', 'hr') " +
                     "ORDER BY o.request_date DESC";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                OvertimeRequest r = new OvertimeRequest();
                r.setId(rs.getInt("id"));
                r.setEmployeeId(rs.getString("employee_id"));
                r.setRequestDate(rs.getDate("request_date"));
                r.setRequestedHours(rs.getDouble("requested_hours"));
                r.setReason(rs.getString("reason"));
                r.setStatus(rs.getString("status"));
                list.add(r);
            }
        } catch (SQLException e) {
            System.err.println("DB Error in getManagerRequestsForAdmin: " + e.getMessage());
            e.printStackTrace();
        }
        return list;
    }

    // 4. Approve Request: Updates status and extends attendance checkout time
    public boolean approveRequest(int requestId, String employeeId, Date requestDate, double otHours, String approverId) {
        String updateOtSql = "UPDATE overtime_requests SET status = 'APPROVED', approved_by = ? WHERE id = ?";
        
        int extraMinutes = (int) Math.round(otHours * 60);
        int totalNetMinutes = 480 + extraMinutes;

        String updateAttendanceSql = 
            "UPDATE attendance SET " +
            "check_out_time = ADDTIME('18:15:00', SEC_TO_TIME(? * 60)), " +
            "net_working_minutes = ?, " +
            "approved_ot_hours = ? " +
            "WHERE LOWER(TRIM(REPLACE(employee_id, ' ', ''))) = LOWER(TRIM(REPLACE(?, ' ', ''))) " +
            "  AND attendance_date = ?";

        Connection conn = null;
        try {
            conn = DBConnection.getConnection();
            conn.setAutoCommit(false);

            try (PreparedStatement ps1 = conn.prepareStatement(updateOtSql);
                 PreparedStatement ps2 = conn.prepareStatement(updateAttendanceSql)) {
                
                ps1.setString(1, approverId);
                ps1.setInt(2, requestId);
                ps1.executeUpdate();

                ps2.setInt(1, extraMinutes);
                ps2.setInt(2, totalNetMinutes);
                ps2.setDouble(3, otHours);
                ps2.setString(4, employeeId);
                ps2.setDate(5, requestDate);
                ps2.executeUpdate();

                conn.commit();
                return true;
            } catch (SQLException ex) {
                if (conn != null) conn.rollback();
                ex.printStackTrace();
                return false;
            }
        } catch (SQLException e) {
            e.printStackTrace();
            return false;
        } finally {
            if (conn != null) {
                try { conn.setAutoCommit(true); conn.close(); } catch (SQLException ignored) {}
            }
        }
    }
}