package com.servlet;

import com.dao.TeamDao;
import com.model.Employee;
import com.model.Team;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.*;
import java.io.IOException;

@WebServlet("/teams/delete")
public class DeleteTeamServlet extends HttpServlet {
    private final TeamDao teamDao = new TeamDao();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        HttpSession session = request.getSession(false);
        Employee user = (session != null) ? (Employee) session.getAttribute("loggedInEmployee") : null;
        if (user == null || !"ADMIN".equalsIgnoreCase(user.getRole())) {
            response.sendRedirect(request.getContextPath() + "/teams/search");
            return;
        }

        String idParam = request.getParameter("id");
        if (idParam == null || idParam.isBlank()) {
            response.sendRedirect(request.getContextPath() + "/teams/search");
            return;
        }

        int teamId;
        try {
            teamId = Integer.parseInt(idParam.trim());
        } catch (NumberFormatException e) {
            response.sendRedirect(request.getContextPath() + "/teams/search");
            return;
        }

        Team team = teamDao.findById(teamId);
        if (team == null) {
            response.sendRedirect(request.getContextPath() + "/teams/search?msg=Team not found.");
            return;
        }

        int activeMembers = teamDao.getActiveMemberCount(teamId);

        request.setAttribute("team", team);
        request.setAttribute("activeMemberCount", activeMembers);
        request.getRequestDispatcher("/deleteTeam.jsp").forward(request, response);
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        HttpSession session = request.getSession(false);
        Employee user = (session != null) ? (Employee) session.getAttribute("loggedInEmployee") : null;
        if (user == null || !"ADMIN".equalsIgnoreCase(user.getRole())) {
            response.sendRedirect(request.getContextPath() + "/teams/search");
            return;
        }

        String idParam = request.getParameter("id");
        if (idParam == null || idParam.isBlank()) {
            idParam = request.getParameter("teamId");
        }

        int teamId;
        try {
            teamId = Integer.parseInt(idParam.trim());
        } catch (Exception e) {
            response.sendRedirect(request.getContextPath() + "/teams/search?msg=Invalid team ID.");
            return;
        }

        String actionType = request.getParameter("actionType");

        if ("HARD_DELETE".equalsIgnoreCase(actionType)) {
            teamDao.deleteTeamPermanently(teamId);
            response.sendRedirect(request.getContextPath() + "/teams/search?msg=Team permanently deleted.");
        } else {
            teamDao.deactivateTeam(teamId);
            response.sendRedirect(request.getContextPath() + "/teams/search?msg=Team marked as INACTIVE.");
        }
    }
}