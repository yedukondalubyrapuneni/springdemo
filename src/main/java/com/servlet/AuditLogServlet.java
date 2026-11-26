package com.servlet;

import com.dao.AuditLogDAO;
import com.model.AuditLog;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;
import java.util.List;

@WebServlet("/admin/audit-logs")
public class AuditLogServlet extends HttpServlet {
    private final AuditLogDAO auditDAO = new AuditLogDAO();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        
        HttpSession session = request.getSession(false);
        String role = (session != null) ? (String) session.getAttribute("role") : null;

        // Strict Admin Check: Disallow unauthorized employees or missing sessions
        if (role == null || (!role.equalsIgnoreCase("ADMIN") && !role.equalsIgnoreCase("SUPER ADMIN") && !role.equalsIgnoreCase("HR"))) {
            response.sendError(HttpServletResponse.SC_FORBIDDEN, "Access Denied: Only authorized administrators can view audit logs.");
            return;
        }

        // Pagination parameters
        int page = 1;
        int pageSize = 20;
        try {
            if (request.getParameter("page") != null) {
                page = Integer.parseInt(request.getParameter("page"));
            }
        } catch (NumberFormatException ignored) {}

        int offset = (page - 1) * pageSize;
        List<AuditLog> auditList = auditDAO.getAllAuditLogs(pageSize, offset);

        request.setAttribute("auditList", auditList);
        request.setAttribute("currentPage", page);
        request.getRequestDispatcher("/admin/audit-logs.jsp").forward(request, response);
    }
}