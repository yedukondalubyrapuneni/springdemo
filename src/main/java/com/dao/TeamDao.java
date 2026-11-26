package com.dao;

import com.model.Employee;
import com.model.Team;
import com.model.TeamMember;
import com.model.TeamMemberStatus;
import com.Util.DBConnection;

import java.sql.*;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public class TeamDao {

    // Helper: Map Department ID
    private String getDeptNameFromId(int id) {
        return switch (id) {
            case 1 -> "IT";
            case 2 -> "HR";
            case 3 -> "Finance";
            case 4 -> "Sales";
            default -> "General";
        };
    }

    private int getDeptIdFromName(String name) {
        if (name == null) return 0;
        return switch (name.toUpperCase().trim()) {
            case "IT" -> 1;
            case "HR" -> 2;
            case "FINANCE" -> 3;
            case "SALES" -> 4;
            default -> 0;
        };
    }

    // 1. Check active membership by String employee_id (e.g. "EMP101")
    public boolean isMemberAlreadyInTeam(int teamId, String employeeId) {
        String query = "SELECT COUNT(*) FROM team_members WHERE team_id = ? AND TRIM(REPLACE(employee_id, ' ', '')) = TRIM(REPLACE(?, ' ', '')) AND status = 'ACTIVE'";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query)) {
            ps.setInt(1, teamId);
            ps.setString(2, employeeId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) return rs.getInt(1) > 0;
            }
        } catch (SQLException e) {
            System.err.println("DB error checking team membership: " + e.getMessage());
        }
        return false;
    }

    // 2. Add or Reactivate Member by String employee_id
    public void addMember(int teamId, String employeeId) {
        String checkQuery = "SELECT id, status FROM team_members WHERE team_id = ? AND TRIM(REPLACE(employee_id, ' ', '')) = TRIM(REPLACE(?, ' ', ''))";
        String insertQuery = "INSERT INTO team_members (team_id, employee_id, joined_date, status) VALUES (?, ?, CURRENT_DATE, 'ACTIVE')";
        String reactivateQuery = "UPDATE team_members SET status = 'ACTIVE', joined_date = CURRENT_DATE WHERE team_id = ? AND TRIM(REPLACE(employee_id, ' ', '')) = TRIM(REPLACE(?, ' ', ''))";

        try (Connection conn = DBConnection.getConnection()) {
            boolean exists = false;
            try (PreparedStatement psCheck = conn.prepareStatement(checkQuery)) {
                psCheck.setInt(1, teamId);
                psCheck.setString(2, employeeId.trim());
                try (ResultSet rs = psCheck.executeQuery()) {
                    if (rs.next()) exists = true;
                }
            }

            if (exists) {
                try (PreparedStatement psUpdate = conn.prepareStatement(reactivateQuery)) {
                    psUpdate.setInt(1, teamId);
                    psUpdate.setString(2, employeeId.trim());
                    psUpdate.executeUpdate();
                }
            } else {
                try (PreparedStatement psInsert = conn.prepareStatement(insertQuery)) {
                    psInsert.setInt(1, teamId);
                    psInsert.setString(2, employeeId.trim());
                    psInsert.executeUpdate();
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException("Failed to add team member: " + e.getMessage());
        }
    }

    // 3. Remove/Deactivate Member (Sets status to INACTIVE)
    public void deactivateMember(int teamId, String employeeId) {
        String query = "UPDATE team_members SET status = 'INACTIVE' WHERE team_id = ? AND TRIM(REPLACE(employee_id, ' ', '')) = TRIM(REPLACE(?, ' ', ''))";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query)) {
            ps.setInt(1, teamId);
            ps.setString(2, employeeId.trim());
            ps.executeUpdate();
        } catch (SQLException e) {
            throw new RuntimeException("Failed to deactivate member: " + e.getMessage());
        }
    }

    // 3b. Delete Member Permanently (Direct remove)
    public boolean removeMember(int teamId, String employeeId) {
        String query = "DELETE FROM team_members WHERE team_id = ? AND (TRIM(REPLACE(employee_id, ' ', '')) = TRIM(REPLACE(?, ' ', '')) OR employee_id = ?)";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query)) {
            ps.setInt(1, teamId);
            ps.setString(2, employeeId.trim());
            ps.setString(3, employeeId.trim());
            return ps.executeUpdate() > 0;
        } catch (SQLException e) {
            System.err.println("DB error in removeMember: " + e.getMessage());
            return false;
        }
    }

    // 4. Fetch Members for viewTeam.jsp (FILTERS BY status = 'ACTIVE')
    public List<TeamMember> findMembersByTeam(int teamId) {
        List<TeamMember> list = new ArrayList<>();
        
        String sql = "SELECT tm.id AS tm_id, tm.team_id, tm.employee_id AS tm_emp_code, " +
                     "COALESCE(tm.status, 'ACTIVE') AS member_status, " +
                     "e.employee_id AS emp_code, e.name AS emp_name, " +
                     "COALESCE(e.role, 'EMPLOYEE') AS emp_role, " +
                     "COALESCE(e.department, 'IT Support') AS emp_dept " +
                     "FROM team_members tm " +
                     "LEFT JOIN employee e ON (TRIM(REPLACE(tm.employee_id, ' ', '')) = TRIM(REPLACE(e.employee_id, ' ', ''))) " +
                     "WHERE tm.team_id = ? AND (tm.status IS NULL OR UPPER(tm.status) = 'ACTIVE') " +
                     "ORDER BY tm.id ASC";

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            
            ps.setInt(1, teamId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    TeamMember m = new TeamMember();
                    m.setId(rs.getInt("tm_id"));
                    m.setTeamId(rs.getInt("team_id"));

                    String code = rs.getString("emp_code");
                    if (code == null || code.isBlank()) {
                        code = rs.getString("tm_emp_code");
                    }
                    m.setEmpCode(code);

                    try {
                        m.setEmployeeId(Integer.parseInt(code.replaceAll("[^0-9]", "")));
                    } catch (Throwable ignored) {}

                    String name = rs.getString("emp_name");
                    m.setEmployeeName((name != null && !name.isBlank()) ? name : code);

                    m.setRole(rs.getString("emp_role"));
                    m.setDepartment(rs.getString("emp_dept"));
                    m.setStatus(rs.getString("member_status"));

                    list.add(m);
                }
            }
        } catch (SQLException e) {
            System.err.println("Error in findMembersByTeam: " + e.getMessage());
            e.printStackTrace();
        }
        return list;
    }

    // 5. Fetch Members by Team ID (Employee model) - singular 'employee' table
    public List<Employee> getTeamMembers(int teamId) {
        List<Employee> members = new ArrayList<>();
        String query = "SELECT e.employee_id, e.name, e.role, e.department, e.email " +
                       "FROM team_members tm " +
                       "JOIN employee e ON TRIM(REPLACE(tm.employee_id, ' ', '')) = TRIM(REPLACE(e.employee_id, ' ', '')) " +
                       "WHERE tm.team_id = ? AND tm.status = 'ACTIVE' " +
                       "ORDER BY e.name ASC";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query)) {
            ps.setInt(1, teamId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Employee emp = new Employee();
                    emp.setEmployeeId(rs.getString("employee_id"));
                    emp.setName(rs.getString("name"));
                    emp.setRole(rs.getString("role"));
                    emp.setDepartment(rs.getString("department"));
                    emp.setEmail(rs.getString("email"));
                    members.add(emp);
                }
            }
        } catch (SQLException e) {
            System.err.println("DB error in getTeamMembers: " + e.getMessage());
        }
        return members;
    }

    // 6. Live shift attendance - singular 'employee' table
    public List<TeamMemberStatus> findTeamMembersWithTodayAttendance(int teamId) {
        List<TeamMemberStatus> list = new ArrayList<>();
        String query = "SELECT tm.employee_id, e.name, e.role, e.department, " +
                       "       COALESCE(a.status, 'NOT_CHECKED_IN') AS att_status, " +
                       "       DATE_FORMAT(a.check_in_time, '%h:%i %p') AS clock_in " +
                       "FROM team_members tm " +
                       "JOIN employee e ON TRIM(REPLACE(tm.employee_id, ' ', '')) = TRIM(REPLACE(e.employee_id, ' ', '')) " +
                       "LEFT JOIN attendance a ON tm.employee_id = a.employee_id AND a.attendance_date = CURRENT_DATE " +
                       "WHERE tm.team_id = ? AND tm.status = 'ACTIVE' " +
                       "ORDER BY e.name ASC";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query)) {
            ps.setInt(1, teamId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    TeamMemberStatus m = new TeamMemberStatus();
                    m.setEmployeeId(rs.getString("employee_id"));
                    m.setName(rs.getString("name"));
                    m.setRole(rs.getString("role"));
                    m.setDepartment(rs.getString("department"));
                    m.setTodayStatus(rs.getString("att_status"));
                    m.setCheckInTime(rs.getString("clock_in"));
                    list.add(m);
                }
            }
        } catch (SQLException e) {
            System.err.println("DB error in findTeamMembersWithTodayAttendance: " + e.getMessage());
        }
        return list;
    }

    // 7. Find Team by ID (Flexible Manager ID Match)
    public Team findById(int teamId) {
        String query = "SELECT t.*, " +
                       "       COALESCE(" +
                       "           (SELECT name FROM employee WHERE TRIM(REPLACE(employee_id, ' ', '')) = TRIM(REPLACE(t.manager_id, ' ', '')) LIMIT 1), " +
                       "           (SELECT name FROM employee WHERE TRIM(REPLACE(employee_id, ' ', '')) = CONCAT('EMP', TRIM(t.manager_id)) LIMIT 1), " +
                       "           (SELECT name FROM employee WHERE TRIM(REPLACE(employee_id, ' ', '')) = CONCAT('MGR', LPAD(TRIM(t.manager_id), 2, '0')) LIMIT 1), " +
                       "           'Unassigned'" +
                       "       ) AS manager_name " +
                       "FROM teams t " +
                       "WHERE t.id = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query)) {
            ps.setInt(1, teamId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) return mapTeam(rs);
            }
        } catch (SQLException e) {
            System.err.println("DB error in findById: " + e.getMessage());
        }
        return null;
    }

    // 8. Validate Duplicate Team Name
    public boolean teamNameExists(String teamName, int excludeTeamId) {
        String query = "SELECT COUNT(*) FROM teams WHERE LOWER(TRIM(team_name)) = LOWER(TRIM(?)) AND id != ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query)) {
            ps.setString(1, teamName.trim());
            ps.setInt(2, excludeTeamId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) return rs.getInt(1) > 0;
            }
        } catch (SQLException e) {
            System.err.println("Error checking team name: " + e.getMessage());
        }
        return false;
    }

    // 9. Create Team
    public int createTeam(Team team) {
        String query = "INSERT INTO teams (team_name, description, department, manager_id, status) VALUES (?, ?, ?, ?, ?)";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query, Statement.RETURN_GENERATED_KEYS)) {
            ps.setString(1, team.getTeamName().trim());
            ps.setString(2, team.getDescription() != null ? team.getDescription().trim() : "");
            
            String dept = team.getDepartmentName();
            if (dept == null || dept.isBlank()) {
                dept = (team.getDepartmentId() != null) ? getDeptNameFromId(team.getDepartmentId()) : "General";
            }
            ps.setString(3, dept);

            if (team.getManagerId() != null && team.getManagerId() > 0) {
                ps.setInt(4, team.getManagerId());
            } else {
                ps.setNull(4, Types.INTEGER);
            }

            ps.setString(5, (team.getStatus() != null && !team.getStatus().isBlank()) ? team.getStatus() : "ACTIVE");
            ps.executeUpdate();

            try (ResultSet rs = ps.getGeneratedKeys()) {
                if (rs.next()) return rs.getInt(1);
            }
        } catch (SQLException e) {
            throw new RuntimeException("Database error creating team: " + e.getMessage());
        }
        return -1;
    }

    // 10. Update Team
    public void updateTeam(Team team) {
        String query = "UPDATE teams SET team_name = ?, description = ?, department = ?, manager_id = ?, status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query)) {
            ps.setString(1, team.getTeamName().trim());
            ps.setString(2, team.getDescription() != null ? team.getDescription().trim() : "");
            
            String dept = team.getDepartmentName();
            if (dept == null || dept.isBlank()) {
                dept = (team.getDepartmentId() != null) ? getDeptNameFromId(team.getDepartmentId()) : "General";
            }
            ps.setString(3, dept);

            if (team.getManagerId() != null && team.getManagerId() > 0) {
                ps.setInt(4, team.getManagerId());
            } else {
                ps.setNull(4, Types.INTEGER);
            }

            ps.setString(5, team.getStatus());
            ps.setInt(6, team.getId());
            ps.executeUpdate();
        } catch (SQLException e) {
            throw new RuntimeException("Database error updating team: " + e.getMessage());
        }
    }

    // 11. Fetch All Teams
    public List<Team> findAllTeams() {
        List<Team> list = new ArrayList<>();
        String query = "SELECT t.*, " +
                       "       COALESCE(" +
                       "           (SELECT name FROM employee WHERE TRIM(REPLACE(employee_id, ' ', '')) = TRIM(REPLACE(t.manager_id, ' ', '')) LIMIT 1), " +
                       "           'Unassigned'" +
                       "       ) AS manager_name " +
                       "FROM teams t " +
                       "ORDER BY t.id ASC";
        try (Connection conn = DBConnection.getConnection();
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(query)) {
            while (rs.next()) {
                list.add(mapTeam(rs));
            }
        } catch (SQLException e) {
            System.err.println("DB error in findAllTeams: " + e.getMessage());
        }
        return list;
    }

    // 12. Search & Filter Teams
    public List<Team> searchAndFilterTeams(String keyword, Integer deptId, String status, Integer managerId) {
        List<Team> list = new ArrayList<>();
        StringBuilder sql = new StringBuilder(
            "SELECT t.*, " +
            "       COALESCE(" +
            "           (SELECT name FROM employee WHERE TRIM(REPLACE(employee_id, ' ', '')) = TRIM(REPLACE(t.manager_id, ' ', '')) LIMIT 1), " +
            "           'Unassigned'" +
            "       ) AS manager_name " +
            "FROM teams t " +
            "WHERE 1=1 "
        );

        List<Object> params = new ArrayList<>();

        if (keyword != null && !keyword.trim().isEmpty()) {
            sql.append("AND (LOWER(t.team_name) LIKE ? OR CAST(t.id AS CHAR) = ?) ");
            String kw = "%" + keyword.trim().toLowerCase() + "%";
            params.add(kw);
            params.add(keyword.trim());
        }

        if (deptId != null && deptId > 0) {
            sql.append("AND LOWER(t.department) = LOWER(?) ");
            params.add(getDeptNameFromId(deptId));
        }

        if (status != null && !status.trim().isEmpty() && !"ALL".equalsIgnoreCase(status)) {
            sql.append("AND t.status = ? ");
            params.add(status.trim());
        }

        if (managerId != null && managerId > 0) {
            sql.append("AND t.manager_id = ? ");
            params.add(managerId);
        }

        sql.append("ORDER BY t.id ASC");

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            for (int i = 0; i < params.size(); i++) {
                ps.setObject(i + 1, params.get(i));
            }
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapTeam(rs));
                }
            }
        } catch (SQLException e) {
            System.err.println("DB search error: " + e.getMessage());
            return findAllTeams();
        }
        return list;
    }

    public List<Team> getAllTeams() {
        return findAllTeams();
    }

    // 13. Fetch all teams assigned to this manager
    public List<Team> findTeamsByManager(String managerEmpId) {
        List<Team> list = new ArrayList<>();
        String sql = "SELECT t.*, " +
                     "       COALESCE((SELECT name FROM employee WHERE TRIM(REPLACE(employee_id, ' ', '')) = TRIM(REPLACE(?, ' ', '')) LIMIT 1), 'Unassigned') AS manager_name " +
                     "FROM teams t " +
                     "WHERE TRIM(REPLACE(t.manager_id, ' ', '')) = TRIM(REPLACE(?, ' ', '')) " +
                     "ORDER BY t.id ASC";

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, managerEmpId);
            ps.setString(2, managerEmpId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapTeam(rs));
                }
            }
        } catch (SQLException e) {
            System.err.println("DB error in findTeamsByManager: " + e.getMessage());
        }
        return list;
    }

    // 14. Fetch Employee's Active Team
    public Team findTeamForEmployee(String employeeId) {
        String query = "SELECT t.*, COALESCE(u.name, 'Unassigned') AS manager_name " +
                       "FROM teams t " +
                       "JOIN team_members tm ON t.id = tm.team_id " +
                       "LEFT JOIN employee u ON TRIM(REPLACE(t.manager_id, ' ', '')) = TRIM(REPLACE(u.employee_id, ' ', '')) " +
                       "WHERE TRIM(REPLACE(tm.employee_id, ' ', '')) = TRIM(REPLACE(?, ' ', '')) AND tm.status = 'ACTIVE' LIMIT 1";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query)) {
            ps.setString(1, employeeId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) return mapTeam(rs);
            }
        } catch (SQLException e) {
            System.err.println("DB error in findTeamForEmployee: " + e.getMessage());
        }
        return null;
    }

    // 15. Active Member Count
    public int getActiveMemberCount(int teamId) {
        String query = "SELECT COUNT(*) FROM team_members WHERE team_id = ? AND status = 'ACTIVE'";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query)) {
            ps.setInt(1, teamId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) return rs.getInt(1);
            }
        } catch (SQLException e) {
            System.err.println("Error counting active members: " + e.getMessage());
        }
        return 0;
    }

    // 16. Soft Delete / Deactivate Team
    public void deactivateTeam(int teamId) {
        String query = "UPDATE teams SET status = 'INACTIVE', updated_at = CURRENT_TIMESTAMP WHERE id = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query)) {
            ps.setInt(1, teamId);
            ps.executeUpdate();
        } catch (SQLException e) {
            throw new RuntimeException("Failed to deactivate team: " + e.getMessage());
        }
    }

    // 17. Hard Delete Team
    public void deleteTeamPermanently(int teamId) {
        try (Connection conn = DBConnection.getConnection()) {
            conn.setAutoCommit(false);
            try (PreparedStatement ps1 = conn.prepareStatement("DELETE FROM team_members WHERE team_id = ?");
                 PreparedStatement ps2 = conn.prepareStatement("DELETE FROM teams WHERE id = ?")) {
                ps1.setInt(1, teamId);
                ps1.executeUpdate();
                ps2.setInt(1, teamId);
                ps2.executeUpdate();
                conn.commit();
            } catch (SQLException e) {
                conn.rollback();
                throw e;
            }
        } catch (SQLException e) {
            throw new RuntimeException("Failed to delete team: " + e.getMessage());
        }
    }

    // 18. Dashboard Metrics
    public Map<String, Object> getDashboardMetrics() {
        Map<String, Object> metrics = new HashMap<>();
        try (Connection conn = DBConnection.getConnection()) {
            try (Statement s = conn.createStatement();
                 ResultSet rs = s.executeQuery("SELECT " +
                     "COUNT(*) AS total_teams, " +
                     "SUM(CASE WHEN status = 'ACTIVE' THEN 1 ELSE 0 END) AS active_teams, " +
                     "SUM(CASE WHEN status = 'INACTIVE' THEN 1 ELSE 0 END) AS inactive_teams " +
                     "FROM teams")) {
                if (rs.next()) {
                    metrics.put("totalTeams", rs.getInt("total_teams"));
                    metrics.put("activeTeams", rs.getInt("active_teams"));
                    metrics.put("inactiveTeams", rs.getInt("inactive_teams"));
                }
            }

            try (Statement s = conn.createStatement();
                 ResultSet rs = s.executeQuery("SELECT COUNT(*) FROM team_members WHERE status = 'ACTIVE'")) {
                if (rs.next()) {
                    metrics.put("totalMembers", rs.getInt(1));
                }
            }

            Map<String, Integer> deptCounts = new LinkedHashMap<>();
            try (Statement s = conn.createStatement();
                 ResultSet rs = s.executeQuery("SELECT department, COUNT(*) AS count FROM teams GROUP BY department")) {
                while (rs.next()) {
                    String dName = rs.getString("department");
                    if (dName == null || dName.isBlank()) dName = "General";
                    deptCounts.put(dName + " Department", rs.getInt("count"));
                }
            }
            metrics.put("deptCounts", deptCounts);
        } catch (SQLException e) {
            System.err.println("Error fetching dashboard metrics: " + e.getMessage());
        }
        return metrics;
    }

    private Team mapTeam(ResultSet rs) throws SQLException {
        Team t = new Team();
        t.setId(rs.getInt("id"));
        t.setTeamName(rs.getString("team_name"));
        t.setDescription(rs.getString("description"));

        String dept = null;
        try {
            dept = rs.getString("department");
        } catch (SQLException ignored) {
            try { dept = rs.getString("dept_name"); } catch (SQLException e) {}
        }
        if (dept == null || dept.isBlank()) {
            int dId = 0;
            try { dId = rs.getInt("department_id"); } catch (SQLException ignored) {}
            dept = getDeptNameFromId(dId);
        }
        t.setDepartmentName((dept != null && !dept.isBlank()) ? dept : "General");
        t.setDepartmentId(getDeptIdFromName(dept));

        String rawMgrId = null;
        try {
            rawMgrId = rs.getString("manager_id");
        } catch (SQLException ignored) {}

        String mgrName = null;
        try {
            mgrName = rs.getString("manager_name");
        } catch (SQLException ignored) {}

        if (mgrName != null && !mgrName.isBlank() && !"Unassigned".equalsIgnoreCase(mgrName.trim())) {
            t.setManagerName(mgrName.trim());
        } else if (rawMgrId != null && !rawMgrId.isBlank()) {
            t.setManagerName(rawMgrId.trim());
        } else {
            t.setManagerName("Unassigned");
        }

        if (rawMgrId != null && !rawMgrId.isBlank()) {
            try {
                t.setManagerId(Integer.parseInt(rawMgrId.replaceAll("[^0-9]", "")));
            } catch (Exception ignored) {}
        }

        t.setStatus(rs.getString("status"));
        
        Timestamp ca = rs.getTimestamp("created_at");
        if (ca != null) t.setCreatedAt(ca.toLocalDateTime());
        Timestamp ua = rs.getTimestamp("updated_at");
        if (ua != null) t.setUpdatedAt(ua.toLocalDateTime());
        
        return t;
    }
}