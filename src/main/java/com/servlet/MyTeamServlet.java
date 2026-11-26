package com.servlet;

import com.dao.TeamDao;
import com.model.Employee;
import com.model.Team;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.*;
import java.io.IOException;
import java.util.List;

@WebServlet("/teams/myTeam")
public class MyTeamServlet extends HttpServlet {
    private final TeamDao teamDao = new TeamDao();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        HttpSession session = request.getSession(false);
        Employee user = (session != null) ? (Employee) session.getAttribute("loggedInEmployee") : null;
        if (user == null) {
            response.sendRedirect(request.getContextPath() + "/login");
            return;
        }

        if ("MANAGER".equalsIgnoreCase(user.getRole())) {
            // Use getEmployeeId() which passes "MGR01"
            List<Team> managedTeams = teamDao.findTeamsByManager(user.getEmployeeId());
            request.setAttribute("managedTeams", managedTeams);
            request.setAttribute("isManager", true);
        } else {
            Team empTeam = teamDao.findTeamForEmployee(user.getEmployeeId());
            if (empTeam != null) {
                request.setAttribute("team", empTeam);
                request.setAttribute("members", teamDao.findMembersByTeam(empTeam.getId()));
            }
            request.setAttribute("isManager", false);
        }

        request.getRequestDispatcher("/myTeam.jsp").forward(request, response);
    }
}