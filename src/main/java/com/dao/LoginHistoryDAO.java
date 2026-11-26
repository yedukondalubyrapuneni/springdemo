package com.dao;

import com.model.LoginHistory;
import com.	Util.DBConnection;

import java.sql.*;
import java.util.ArrayList;
import java.util.List;

public class LoginHistoryDAO {

    public boolean recordActivity(LoginHistory history) {
        String sql = "INSERT INTO login_history (user_id, email, activity_type, ip_address, user_agent) VALUES (?, ?, ?, ?, ?)";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {

            if (history.getUserId() != null) {
                ps.setInt(1, history.getUserId());
            } else {
                ps.setNull(1, Types.INTEGER);
            }
            ps.setString(2, history.getEmail());
            ps.setString(3, history.getActivityType());
            ps.setString(4, history.getIpAddress());
            ps.setString(5, history.getUserAgent());

            return ps.executeUpdate() > 0;
        } catch (SQLException e) {
            System.err.println("LoginHistory insert error: " + e.getMessage());
            return false;
        }
    }

    public boolean recordLoginActivity(int userId, String email, String ip, String userAgent) {
        return recordActivity(new LoginHistory(userId, email, "LOGIN", ip, userAgent));
    }

    public boolean recordLogoutActivity(int userId, String email, String ip, String userAgent) {
        return recordActivity(new LoginHistory(userId, email, "LOGOUT", ip, userAgent));
    }

    public boolean recordFailedLogin(String email, String ip, String userAgent) {
        return recordActivity(new LoginHistory(null, email, "FAILED_LOGIN", ip, userAgent));
    }

    public List<LoginHistory> getFilteredHistory(String email, String activityType, int limit, int offset) {
        List<LoginHistory> list = new ArrayList<>();
        StringBuilder sql = new StringBuilder("SELECT * FROM login_history WHERE 1=1 ");

        if (email != null && !email.trim().isEmpty()) {
            sql.append("AND email LIKE ? ");
        }
        if (activityType != null && !activityType.trim().isEmpty()) {
            sql.append("AND activity_type = ? ");
        }
        sql.append("ORDER BY created_at DESC LIMIT ? OFFSET ?");

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {

            int paramIndex = 1;
            if (email != null && !email.trim().isEmpty()) {
                ps.setString(paramIndex++, "%" + email.trim() + "%");
            }
            if (activityType != null && !activityType.trim().isEmpty()) {
                ps.setString(paramIndex++, activityType.trim());
            }
            ps.setInt(paramIndex++, limit);
            ps.setInt(paramIndex, offset);

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    LoginHistory lh = new LoginHistory();
                    lh.setId(rs.getLong("id"));
                    int uid = rs.getInt("user_id");
                    if (!rs.wasNull()) lh.setUserId(uid);
                    lh.setEmail(rs.getString("email"));
                    lh.setActivityType(rs.getString("activity_type"));
                    lh.setIpAddress(rs.getString("ip_address"));
                    lh.setUserAgent(rs.getString("user_agent"));
                    lh.setCreatedAt(rs.getTimestamp("created_at"));
                    list.add(lh);
                }
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return list;
    }
}