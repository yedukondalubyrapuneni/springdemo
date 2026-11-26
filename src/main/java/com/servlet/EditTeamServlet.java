package com.servlet;

import com.dao.EmployeeDao;
import com.dao.TeamDao;
import com.model.Employee;
import com.model.Team;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.*;
import java.io.IOException;

@WebServlet("/teams/edit")
public class EditTeamServlet extends HttpServlet {
    private final TeamDao teamDao = new TeamDao();
    private final EmployeeDao employeeDao = new EmployeeDao();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        HttpSession session = request.getSession(false);
        Employee user = (session != null) ? (Employee) session.getAttribute("loggedInEmployee") : null;

        // Strictly restrict team editing to ADMIN
        if (user == null || !"ADMIN".equalsIgnoreCase(user.getRole())) {
            response.sendRedirect(request.getContextPath() + "/teams/search");
            return;
        }

        String idParam = request.getParameter("id");
        if (idParam == null || idParam.isBlank()) {
            response.sendRedirect(request.getContextPath() + "/teams/search");
            return;
        }

        try {
            int id = Integer.parseInt(idParam.trim());
            Team team = teamDao.findById(id);
            if (team == null) {
                response.sendRedirect(request.getContextPath() + "/teams/search");
                return;
            }
            request.setAttribute("team", team);
            request.setAttribute("allEmployees", employeeDao.getAllEmployees());
            request.getRequestDispatcher("/editTeam.jsp").forward(request, response);
        } catch (NumberFormatException e) {
            response.sendRedirect(request.getContextPath() + "/teams/search");
        }
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        HttpSession session = request.getSession(false);
        Employee user = (session != null) ? (Employee) session.getAttribute("loggedInEmployee") : null;

        // Block unauthorized roles (HR, Manager, Staff) from modifying team data
        if (user == null || !"ADMIN".equalsIgnoreCase(user.getRole())) {
            response.sendError(HttpServletResponse.SC_FORBIDDEN, "Access Denied: Only Administrators can edit teams.");
            return;
        }

        String idParam = request.getParameter("id");
        String teamName = request.getParameter("teamName");
        String description = request.getParameter("description");
        String departmentId = request.getParameter("departmentId");
        String managerId = request.getParameter("managerId");
        String status = request.getParameter("status");

        int id;
        try {
            id = Integer.parseInt(idParam.trim());
        } catch (Exception e) {
            response.sendRedirect(request.getContextPath() + "/teams/search");
            return;
        }

        if (teamDao.teamNameExists(teamName, id)) {
            request.setAttribute("error", "Team name already taken by another team.");
            request.setAttribute("team", teamDao.findById(id));
            request.setAttribute("allEmployees", employeeDao.getAllEmployees());
            request.getRequestDispatcher("/editTeam.jsp").forward(request, response);
            return;
        }

        Team t = new Team();
        t.setId(id);
        t.setTeamName(teamName != null ? teamName.trim() : "");
        t.setDescription(description != null ? description.trim() : "");

        // Department mapping
        if (departmentId != null && !departmentId.isBlank()) {
            try {
                t.setDepartmentId(Integer.parseInt(departmentId.trim()));
            } catch (NumberFormatException ignored) {}
        }

        // Manager mapping (handles unassigned managers safely)
        if (managerId != null && !managerId.isBlank()) {
            try {
                t.setManagerId(Integer.parseInt(managerId.trim()));
            } catch (NumberFormatException ignored) {
                t.setManagerId(null);
            }
        } else {
            t.setManagerId(null);
        }

        t.setStatus(status != null ? status.trim() : "ACTIVE");

        teamDao.updateTeam(t);
        response.sendRedirect(request.getContextPath() + "/teams/view?id=" + id + "&msg=Team updated successfully.");
    }
}