package com.servlet;

import com.dao.TaskDao;
import com.dao.TeamDao;
import com.model.Employee;
import com.model.Task;
import com.model.Team;
import com.model.TeamMemberStatus;
import com.Util.DBConnection;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@WebServlet("/manager/dashboard")
public class ManagerDashboardServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;
    private final TeamDao teamDao = new TeamDao();
    private final TaskDao taskDao = new TaskDao();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        Employee loggedIn = (session != null) ? (Employee) session.getAttribute("loggedInEmployee") : null;

        if (loggedIn == null) {
            response.sendRedirect(request.getContextPath() + "/login.jsp");
            return;
        }

        // Strict RBAC: Only Managers can access this console
        if (!"MANAGER".equalsIgnoreCase(loggedIn.getRole())) {
            response.setStatus(HttpServletResponse.SC_FORBIDDEN);
            request.setAttribute("error", "Access Denied: Managers only.");
            request.getRequestDispatcher("/accessDenied.jsp").forward(request, response);
            return;
        }

        // 1. Manager Punch State for Today
        Map<String, Object> managerAttendance = new HashMap<>();
        String attSql = "SELECT check_in_time, status FROM attendance " +
                        "WHERE employee_id = ? AND attendance_date = CURRENT_DATE LIMIT 1";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(attSql)) {
            ps.setString(1, loggedIn.getEmployeeId());
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    managerAttendance.put("clockIn", rs.getString("check_in_time"));
                    managerAttendance.put("status", rs.getString("status"));
                }
            }
        } catch (Exception e) {
            System.err.println("Attendance query log: " + e.getMessage());
        }
        request.setAttribute("managerAttendance", managerAttendance);

        // 2. Supervised Teams
        List<Team> managedTeams = teamDao.findTeamsByManager(loggedIn.getEmployeeId());
        request.setAttribute("managedTeams", managedTeams);

        // 3. Selected Team
        int selectedTeamId = 0;
        String teamIdParam = request.getParameter("teamId");
        if (teamIdParam != null && !teamIdParam.isBlank()) {
            try {
                selectedTeamId = Integer.parseInt(teamIdParam.trim());
            } catch (Exception ignored) {}
        } else if (managedTeams != null && !managedTeams.isEmpty()) {
            selectedTeamId = managedTeams.get(0).getId();
        }

        // 4. Team Attendance Roster & Delegated Task Statuses
        if (selectedTeamId > 0) {
            request.setAttribute("selectedTeam", teamDao.findById(selectedTeamId));
            
            // Attendance Roster
            List<TeamMemberStatus> roster = teamDao.findTeamMembersWithTodayAttendance(selectedTeamId);
            request.setAttribute("teamRoster", roster);

            // Team Tasks Tracking
            List<Task> teamTasks = taskDao.findTasksByTeam(selectedTeamId);
            request.setAttribute("teamTasks", teamTasks);
        }

        request.getRequestDispatcher("/managerDashboard.jsp").forward(request, response);
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        doGet(request, response);
    }
}