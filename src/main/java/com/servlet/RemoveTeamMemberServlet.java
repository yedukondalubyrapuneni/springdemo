package com.servlet;

import com.dao.EmployeeDao;
import com.dao.TeamDao;
import com.model.Employee;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.*;
import java.io.IOException;

@WebServlet("/teams/member/remove")
public class RemoveTeamMemberServlet extends HttpServlet {
    private final TeamDao teamDao = new TeamDao();
    private final EmployeeDao employeeDao = new EmployeeDao();

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        HttpSession session = request.getSession(false);
        Employee user = (session != null) ? (Employee) session.getAttribute("loggedInEmployee") : null;

        if (user == null || !"ADMIN".equalsIgnoreCase(user.getRole())) {
            response.sendError(HttpServletResponse.SC_FORBIDDEN, "Access Denied: Only Administrators can modify team members.");
            return;
        }

        String teamIdParam = request.getParameter("teamId");
        String empId = request.getParameter("employeeId");

        if (teamIdParam == null || empId == null || teamIdParam.isBlank() || empId.isBlank()) {
            response.sendRedirect(request.getContextPath() + "/teams/search");
            return;
        }

        try {
            int teamId = Integer.parseInt(teamIdParam.trim());
            
            // Delete directly from team_members table so it immediately disappears
            boolean deleted = teamDao.removeMember(teamId, empId.trim());
            if (!deleted) {
                // Fallback to deactivation if delete affected 0 rows
                teamDao.deactivateMember(teamId, empId.trim());
            }

            response.sendRedirect(request.getContextPath() + "/teams/view?id=" + teamId + "&msg=Employee%20removed%20successfully.");
        } catch (Exception e) {
            response.sendRedirect(request.getContextPath() + "/teams/view?id=" + teamIdParam + "&error=" + e.getMessage());
        }
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        doPost(request, response);
    }
}