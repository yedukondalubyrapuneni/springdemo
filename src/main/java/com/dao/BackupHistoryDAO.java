package com.dao;

import com.model.BackupHistory;
import com.Util.DBConnection;

import java.sql.*;
import java.util.ArrayList;
import java.util.List;

public class BackupHistoryDAO {

    public boolean recordBackup(BackupHistory backup) {
        String sql = "INSERT INTO backup_history (backup_file, backup_type, status, file_size, created_by, remarks) VALUES (?, ?, ?, ?, ?, ?)";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, backup.getBackupFile());
            ps.setString(2, backup.getBackupType());
            ps.setString(3, backup.getStatus());
            ps.setLong(4, backup.getFileSize() != null ? backup.getFileSize() : 0L);
            if (backup.getCreatedBy() != null) {
                ps.setInt(5, backup.getCreatedBy());
            } else {
                ps.setNull(5, Types.INTEGER);
            }
            ps.setString(6, backup.getRemarks());
            return ps.executeUpdate() > 0;
        } catch (SQLException e) {
            e.printStackTrace();
            return false;
        }
    }

    public List<BackupHistory> getAllBackups(int limit) {
        List<BackupHistory> list = new ArrayList<>();
        String sql = "SELECT * FROM backup_history ORDER BY created_at DESC LIMIT ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, limit);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    BackupHistory b = new BackupHistory();
                    b.setId(rs.getLong("id"));
                    b.setBackupFile(rs.getString("backup_file"));
                    b.setBackupType(rs.getString("backup_type"));
                    b.setStatus(rs.getString("status"));
                    b.setFileSize(rs.getLong("file_size"));
                    int uid = rs.getInt("created_by");
                    if (!rs.wasNull()) b.setCreatedBy(uid);
                    b.setCreatedAt(rs.getTimestamp("created_at"));
                    b.setRemarks(rs.getString("remarks"));
                    list.add(b);
                }
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return list;
    }
}