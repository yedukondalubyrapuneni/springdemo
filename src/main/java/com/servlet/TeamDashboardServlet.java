package com.servlet;

import com.dao.TeamDao;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.*;
import java.io.IOException;
import java.util.Map;

@WebServlet("/teams/dashboard")
public class TeamDashboardServlet extends HttpServlet {
    private final TeamDao teamDao = new TeamDao();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        Map<String, Object> metrics = teamDao.getDashboardMetrics();
        request.setAttribute("metrics", metrics);
        request.getRequestDispatcher("/teamDashboard.jsp").forward(request, response);
    }
}