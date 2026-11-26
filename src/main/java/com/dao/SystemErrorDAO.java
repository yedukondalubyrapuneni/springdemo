package com.dao;

import com.model.SystemError;
import com.Util.DBConnection;

import java.sql.*;
import java.util.ArrayList;
import java.util.List;

public class SystemErrorDAO {

    public boolean recordSystemError(SystemError err) {
        String sql = "INSERT INTO system_errors (module_name, error_type, error_message, severity, user_id) VALUES (?, ?, ?, ?, ?)";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, err.getModuleName());
            ps.setString(2, err.getErrorType());
            ps.setString(3, err.getErrorMessage());
            ps.setString(4, err.getSeverity());
            if (err.getUserId() != null) {
                ps.setInt(5, err.getUserId());
            } else {
                ps.setNull(5, Types.INTEGER);
            }
            return ps.executeUpdate() > 0;
        } catch (SQLException e) {
            System.err.println("Failed to insert system error: " + e.getMessage());
            return false;
        }
    }

    public List<SystemError> getFilteredErrors(String severity, String moduleName, int limit) {
        List<SystemError> list = new ArrayList<>();
        StringBuilder sql = new StringBuilder("SELECT * FROM system_errors WHERE 1=1 ");

        if (severity != null && !severity.isBlank()) {
            sql.append("AND severity = ? ");
        }
        if (moduleName != null && !moduleName.isBlank()) {
            sql.append("AND module_name LIKE ? ");
        }
        sql.append("ORDER BY created_at DESC LIMIT ?");

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            int pIndex = 1;
            if (severity != null && !severity.isBlank()) {
                ps.setString(pIndex++, severity.trim());
            }
            if (moduleName != null && !moduleName.isBlank()) {
                ps.setString(pIndex++, "%" + moduleName.trim() + "%");
            }
            ps.setInt(pIndex, limit);

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    SystemError se = new SystemError();
                    se.setId(rs.getLong("id"));
                    se.setModuleName(rs.getString("module_name"));
                    se.setErrorType(rs.getString("error_type"));
                    se.setErrorMessage(rs.getString("error_message"));
                    se.setSeverity(rs.getString("severity"));
                    int uid = rs.getInt("user_id");
                    if (!rs.wasNull()) se.setUserId(uid);
                    se.setCreatedAt(rs.getTimestamp("created_at"));
                    list.add(se);
                }
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return list;
    }
}