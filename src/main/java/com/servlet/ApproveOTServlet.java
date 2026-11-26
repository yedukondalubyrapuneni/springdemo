package com.servlet;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.*;
import java.io.IOException;
import java.sql.Connection;
import java.sql.Date;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import com.dao.OvertimeDAO;
import com.Util.DBConnection;
import com.model.Employee;

@WebServlet("/overtime/approve")
public class ApproveOTServlet extends HttpServlet {
    private final OvertimeDAO otDAO = new OvertimeDAO();

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        
        HttpSession session = request.getSession(false);
        if (session == null) {
            response.sendRedirect(request.getContextPath() + "/login.jsp");
            return;
        }

        // 1. Identify approver from session
        Employee loggedEmp = (Employee) session.getAttribute("loggedInEmployee");
        String approverId = (loggedEmp != null) ? loggedEmp.getEmployeeId() : (String) session.getAttribute("loggedUserId");
        String approverRole = (loggedEmp != null && loggedEmp.getRole() != null) 
                              ? loggedEmp.getRole() 
                              : (String) session.getAttribute("role");

        if (approverId == null) {
            response.sendRedirect(request.getContextPath() + "/login.jsp");
            return;
        }

        if (approverRole == null) {
            approverRole = "";
        }

        // Determine fallback return URL (stay on Manager Workspace)
        String referer = request.getHeader("Referer");
        String returnUrl = (referer != null && !referer.isBlank()) 
                           ? referer 
                           : (request.getContextPath() + "/manager-workspace.jsp");

        // 2. Strict Check: Block HR and regular Employees from approving OT
        if ("HR".equalsIgnoreCase(approverRole) || "EMPLOYEE".equalsIgnoreCase(approverRole)) {
            session.setAttribute("toastErr", "Access Denied: Only Managers and Admins can approve Overtime.");
            response.sendRedirect(returnUrl);
            return;
        }

        int requestId = Integer.parseInt(request.getParameter("requestId"));
        String applicantEmployeeId = request.getParameter("employeeId");
        Date requestDate = Date.valueOf(request.getParameter("requestDate"));
        double requestedHours = Double.parseDouble(request.getParameter("requestedHours"));

        // 3. Prevent self-approval
        if (applicantEmployeeId != null && applicantEmployeeId.trim().equalsIgnoreCase(approverId.trim())) {
            session.setAttribute("toastErr", "Self-approval is not permitted.");
            response.sendRedirect(returnUrl);
            return;
        }

        // 4. Verify applicant role from database
        String applicantRole = "EMPLOYEE";
        String checkRoleSql = "SELECT role FROM employee WHERE LOWER(TRIM(REPLACE(employee_id, ' ', ''))) = LOWER(TRIM(REPLACE(?, ' ', '')))";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement psRole = conn.prepareStatement(checkRoleSql)) {
            psRole.setString(1, applicantEmployeeId);
            try (ResultSet rsRole = psRole.executeQuery()) {
                if (rsRole.next()) {
                    applicantRole = rsRole.getString("role");
                }
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }

        // 5. Hierarchy checks
        if ("MANAGER".equalsIgnoreCase(applicantRole) && !"ADMIN".equalsIgnoreCase(approverRole)) {
            session.setAttribute("toastErr", "Manager OT requests require Admin approval.");
            response.sendRedirect(returnUrl);
            return;
        }

        if ("MANAGER".equalsIgnoreCase(approverRole) && !"EMPLOYEE".equalsIgnoreCase(applicantRole)) {
            session.setAttribute("toastErr", "Managers can only approve regular employee requests.");
            response.sendRedirect(returnUrl);
            return;
        }

        // 6. Execute approval
        boolean success = otDAO.approveRequest(requestId, applicantEmployeeId, requestDate, requestedHours, approverId);

        if (success) {
            session.setAttribute("toastMsg", "Overtime approved successfully! Shift auto-checkout updated.");
        } else {
            session.setAttribute("toastErr", "Failed to update attendance record for overtime.");
        }

        // 7. Stay on the same page (Referer) or redirect to manager workspace
        response.sendRedirect(returnUrl);
    }
}