package com.servlet;

import com.dao.DashboardDAO;
import com.model.DashboardSummaryDTO;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;

@WebServlet("/admin/system-dashboard")
public class SystemDashboardServlet extends HttpServlet {
    private final DashboardDAO dashboardDAO = new DashboardDAO();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        HttpSession session = request.getSession(false);
        String role = (session != null) ? (String) session.getAttribute("role") : null;

        // Security Requirement: Super Admin and Admin access only
        if (role == null || (!role.equalsIgnoreCase("ADMIN") && !role.equalsIgnoreCase("SUPER ADMIN") && !role.equalsIgnoreCase("HR"))) {
            response.sendError(HttpServletResponse.SC_FORBIDDEN, "Access Denied: Administrative authority required.");
            return;
        }

        DashboardSummaryDTO summary = dashboardDAO.getDashboardMetrics();
        request.setAttribute("summary", summary);
        request.getRequestDispatcher("/system-dashboard.jsp").forward(request, response);
    }
}