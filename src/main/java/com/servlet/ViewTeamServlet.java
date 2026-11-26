package com.servlet;

import com.dao.TeamDao;
import com.model.Employee;
import com.model.Team;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.*;
import java.io.IOException;

@WebServlet("/teams/view")
public class ViewTeamServlet extends HttpServlet {
    private final TeamDao teamDao = new TeamDao();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        HttpSession session = request.getSession(false);
        if (session == null || session.getAttribute("loggedInEmployee") == null) {
            response.sendRedirect(request.getContextPath() + "/login");
            return;
        }
        int id = Integer.parseInt(request.getParameter("id"));
        Team team = teamDao.findById(id);
        request.setAttribute("team", team);
        request.setAttribute("members", teamDao.findMembersByTeam(id));
        request.getRequestDispatcher("/viewTeam.jsp").forward(request, response);
    }
}