package com.servlet;

import com.dao.EmployeeDao;
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

@WebServlet("/teams/member/add")
public class AddTeamMemberServlet extends HttpServlet {

    private final TeamDao teamDao = new TeamDao();
    private final EmployeeDao employeeDao = new EmployeeDao();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        Employee loggedIn = (session != null) ? (Employee) session.getAttribute("loggedInEmployee") : null;

        if (loggedIn == null || !"ADMIN".equalsIgnoreCase(loggedIn.getRole())) {
            response.sendRedirect(request.getContextPath() + "/teams/search");
            return;
        }

        String teamIdStr = request.getParameter("teamId");
        if (teamIdStr == null || teamIdStr.isBlank()) {
            response.sendRedirect(request.getContextPath() + "/teams/search");
            return;
        }

        try {
            int teamId = Integer.parseInt(teamIdStr.trim());
            Team team = teamDao.findById(teamId);

            if (team == null) {
                response.sendRedirect(request.getContextPath() + "/teams/search");
                return;
            }

            request.setAttribute("team", team);
            request.setAttribute("allEmployees", employeeDao.getAllEmployees());
            request.getRequestDispatcher("/addTeamMember.jsp").forward(request, response);

        } catch (NumberFormatException e) {
            response.sendRedirect(request.getContextPath() + "/teams/search");
        }
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        Employee loggedIn = (session != null) ? (Employee) session.getAttribute("loggedInEmployee") : null;

        if (loggedIn == null || !"ADMIN".equalsIgnoreCase(loggedIn.getRole())) {
            response.sendError(HttpServletResponse.SC_FORBIDDEN, "Access Denied: Only Administrators can add team members.");
            return;
        }

        String teamIdStr = request.getParameter("teamId");
        String empId = request.getParameter("employeeId"); // String (varchar)

        if (teamIdStr == null || empId == null || teamIdStr.isBlank() || empId.isBlank()) {
            response.sendRedirect(request.getContextPath() + "/teams/search");
            return;
        }

        int teamId;
        try {
            teamId = Integer.parseInt(teamIdStr.trim());
        } catch (NumberFormatException e) {
            response.sendRedirect(request.getContextPath() + "/teams/search");
            return;
        }

        try {
            empId = empId.trim();

            // 1. Check if employee is already an ACTIVE member of this team
            if (teamDao.isMemberAlreadyInTeam(teamId, empId)) {
                request.setAttribute("error", "Employee (" + empId + ") is already an active member of this team.");
                request.setAttribute("team", teamDao.findById(teamId));
                request.setAttribute("allEmployees", employeeDao.getAllEmployees());
                request.getRequestDispatcher("/addTeamMember.jsp").forward(request, response);
                return;
            }

            // 2. Add or reactivate membership
            teamDao.addMember(teamId, empId);

            // 3. Redirect back to view page
            response.sendRedirect(request.getContextPath() + "/teams/view?id=" + teamId + "&msg=Employee " + empId + " assigned successfully.");

        } catch (Exception e) {
            request.setAttribute("error", "Failed to add member: " + e.getMessage());
            request.setAttribute("team", teamDao.findById(teamId));
            request.setAttribute("allEmployees", employeeDao.getAllEmployees());
            request.getRequestDispatcher("/addTeamMember.jsp").forward(request, response);
        }
    }
}