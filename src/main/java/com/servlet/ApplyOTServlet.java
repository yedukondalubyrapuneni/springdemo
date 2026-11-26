package com.servlet;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.*;
import java.io.IOException;
import java.sql.Date;
import com.dao.OvertimeDAO;
import com.model.OvertimeRequest;
import com.model.Employee;

@WebServlet("/overtime/apply")
public class ApplyOTServlet extends HttpServlet {
    private final OvertimeDAO otDAO = new OvertimeDAO();

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        
        HttpSession session = request.getSession();
        
        Employee emp = (Employee) session.getAttribute("loggedInEmployee");
        String employeeId = (emp != null) ? emp.getEmployeeId() : (String) session.getAttribute("loggedUserId");

        if (employeeId == null) {
            response.sendRedirect(request.getContextPath() + "/login.jsp");
            return;
        }

        try {
            Date requestDate = Date.valueOf(request.getParameter("requestDate"));
            double requestedHours = Double.parseDouble(request.getParameter("requestedHours"));
            String reason = request.getParameter("reason");

            OvertimeRequest req = new OvertimeRequest();
            req.setEmployeeId(employeeId);
            req.setRequestDate(requestDate);
            req.setRequestedHours(requestedHours);
            req.setReason(reason);

            otDAO.applyOvertime(req);

            session.setAttribute("toastMsg", "Overtime request submitted successfully!");
        } catch (Exception e) {
            e.printStackTrace();
            session.setAttribute("toastErr", "Failed to submit overtime request: " + e.getMessage());
        }

        // 1. If the request came from an existing page (Referer), send them back there
        String referer = request.getHeader("Referer");
        if (referer != null && !referer.isBlank()) {
            response.sendRedirect(referer);
            return;
        }

        // 2. Fallback based on user role
        String role = (emp != null && emp.getRole() != null) ? emp.getRole() : (String) session.getAttribute("role");
        if ("MANAGER".equalsIgnoreCase(role)) {
            response.sendRedirect(request.getContextPath() + "/manager-workspace.jsp?tab=tab-attendance");
        } else {
            // Adjust to your actual JSP name if different (e.g., /dashboard.jsp)
            response.sendRedirect(request.getContextPath() + "/dashboard.jsp?tab=tab-shift");
        }
    }
}