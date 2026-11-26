package com.dao;

import com.model.AuditLog;
import com.Util.DBConnection;

import java.sql.*;
import java.util.ArrayList;
import java.util.List;

public class AuditLogDAO {

    public boolean insertAuditLog(AuditLog log) {
        String sql = "INSERT INTO audit_logs (user_id, module_name, action_type, record_id, " +
                     "description, old_values, new_values, ip_address) VALUES (?, ?, ?, ?, ?, ?, ?, ?)";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            
            if (log.getUserId() != null) {
                ps.setInt(1, log.getUserId());
            } else {
                ps.setNull(1, Types.INTEGER);
            }
            ps.setString(2, log.getModuleName());
            ps.setString(3, log.getActionType());
            ps.setString(4, log.getRecordId());
            ps.setString(5, log.getDescription());
            ps.setString(6, log.getOldValues());
            ps.setString(7, log.getNewValues());
            ps.setString(8, log.getIpAddress());

            return ps.executeUpdate() > 0;
        } catch (SQLException e) {
            System.err.println("AuditLog insert error: " + e.getMessage());
            return false;
        }
    }

    public List<AuditLog> getAllAuditLogs(int limit, int offset) {
        List<AuditLog> list = new ArrayList<>();
        String sql = "SELECT * FROM audit_logs ORDER BY created_at DESC LIMIT ? OFFSET ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, limit);
            ps.setInt(2, offset);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return list;
    }

    public List<AuditLog> getAuditLogsByUser(int userId) {
        List<AuditLog> list = new ArrayList<>();
        String sql = "SELECT * FROM audit_logs WHERE user_id = ? ORDER BY created_at DESC";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return list;
    }

    public List<AuditLog> getAuditLogsByModule(String moduleName) {
        List<AuditLog> list = new ArrayList<>();
        String sql = "SELECT * FROM audit_logs WHERE module_name = ? ORDER BY created_at DESC";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, moduleName);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return list;
    }

    public List<AuditLog> getAuditLogsByDateRange(Timestamp start, Timestamp end) {
        List<AuditLog> list = new ArrayList<>();
        String sql = "SELECT * FROM audit_logs WHERE created_at BETWEEN ? AND ? ORDER BY created_at DESC";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setTimestamp(1, start);
            ps.setTimestamp(2, end);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return list;
    }

    private AuditLog mapRow(ResultSet rs) throws SQLException {
        AuditLog log = new AuditLog();
        log.setId(rs.getLong("id"));
        int uid = rs.getInt("user_id");
        if (!rs.wasNull()) log.setUserId(uid);
        log.setModuleName(rs.getString("module_name"));
        log.setActionType(rs.getString("action_type"));
        log.setRecordId(rs.getString("record_id"));
        log.setDescription(rs.getString("description"));
        log.setOldValues(rs.getString("old_values"));
        log.setNewValues(rs.getString("new_values"));
        log.setIpAddress(rs.getString("ip_address"));
        log.setCreatedAt(rs.getTimestamp("created_at"));
        return log;
    }
    
}