package com.servlet;

import com.dao.TeamDao;
import com.model.Employee;
import com.model.Team;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;

@WebServlet("/teams/create")
public class CreateTeamServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;
    private final TeamDao teamDao = new TeamDao();

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        Employee loggedIn = (session != null) ? (Employee) session.getAttribute("loggedInEmployee") : null;
        if (loggedIn == null) {
            response.sendRedirect(request.getContextPath() + "/login.jsp");
            return;
        }

        String teamName = request.getParameter("teamName");
        String description = request.getParameter("description");
        String departmentIdStr = request.getParameter("departmentId");
        String managerIdRaw = request.getParameter("managerId");
        String status = request.getParameter("status");

        // Basic validation
        if (teamName == null || teamName.trim().isEmpty()) {
            request.setAttribute("error", "Team name is required.");
            request.getRequestDispatcher("/createTeam.jsp").forward(request, response);
            return;
        }

        // Check for duplicate team name
        if (teamDao.teamNameExists(teamName.trim(), -1)) {
            request.setAttribute("error", "A team with this name already exists.");
            request.getRequestDispatcher("/createTeam.jsp").forward(request, response);
            return;
        }

        Team team = new Team();
        team.setTeamName(teamName.trim());
        team.setDescription(description != null ? description.trim() : "");
        team.setStatus((status != null && !status.isBlank()) ? status : "ACTIVE");

        // Parse Department ID & map department name
        int deptId = 0;
        try {
            if (departmentIdStr != null && !departmentIdStr.isBlank()) {
                deptId = Integer.parseInt(departmentIdStr.trim());
                team.setDepartmentId(deptId);
                team.setDepartmentName(getDeptName(deptId));
            }
        } catch (NumberFormatException e) {
            team.setDepartmentName("General");
        }

        // Parse Manager ID (handles raw numeric like "3" or "EMP03" / "MGR03")
        if (managerIdRaw != null && !managerIdRaw.isBlank()) {
            try {
                int numericMgrId = Integer.parseInt(managerIdRaw.replaceAll("[^0-9]", ""));
                team.setManagerId(numericMgrId);
            } catch (Exception e) {
                team.setManagerId(null);
            }
        }

        try {
            int newTeamId = teamDao.createTeam(team);
            if (newTeamId > 0) {
                session.setAttribute("toastMsg", "Team '" + team.getTeamName() + "' created successfully!");
                response.sendRedirect(request.getContextPath() + "/manageTeams.jsp");
            } else {
                request.setAttribute("error", "Database failed to generate team record.");
                request.getRequestDispatcher("/createTeam.jsp").forward(request, response);
            }
        } catch (Exception e) {
            e.printStackTrace();
            request.setAttribute("error", "Failed to create team: " + e.getMessage());
            request.getRequestDispatcher("/createTeam.jsp").forward(request, response);
        }
    }

    private String getDeptName(int id) {
        return switch (id) {
            case 1 -> "Engineering / IT";
            case 2 -> "Human Resources";
            case 3 -> "Operations";
            case 4 -> "Finance";
            case 5 -> "Sales & Marketing";
            default -> "General";
        };
    }
}