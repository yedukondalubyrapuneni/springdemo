package com.servlet;


import com.model.Employee;
import com.model.Payroll;
import com.model.SalaryStructure;
import com.dao.PayrollDAO;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;

@WebServlet("/payroll/salary-slip")
public class SalarySlipServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;
    private final PayrollDAO payrollDAO = new PayrollDAO();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        Employee loggedIn = (session != null) ? (Employee) session.getAttribute("loggedInEmployee") : null;

        if (loggedIn == null) {
            response.sendRedirect(request.getContextPath() + "/login.jsp");
            return;
        }

        String idParam = request.getParameter("id");
        if (idParam == null || idParam.isBlank()) {
            response.sendRedirect(request.getContextPath() + "/payroll/history");
            return;
        }

        int payrollId;
        try {
            payrollId = Integer.parseInt(idParam.trim());
        } catch (NumberFormatException e) {
            response.sendRedirect(request.getContextPath() + "/payroll/history");
            return;
        }

        Payroll payroll = payrollDAO.getPayrollById(payrollId);
        if (payroll == null) {
            response.sendError(HttpServletResponse.SC_NOT_FOUND, "Payroll record not found.");
            return;
        }

        String role = (loggedIn.getRole() != null) ? loggedIn.getRole().trim().toUpperCase() : "";
        boolean isAdmin = "ADMIN".equals(role);
        boolean isHr = "HR".equals(role) || loggedIn.isHrDesignation();

        // SECURITY CHECK:
        // If not Admin or HR, employeeId on the record must match logged-in employeeId
        String recordEmp = payroll.getEmployeeId().replaceAll("\\s+", "").toUpperCase();
        String currentEmp = loggedIn.getEmployeeId().replaceAll("\\s+", "").toUpperCase();

        if (!isAdmin && !isHr && !recordEmp.equals(currentEmp)) {
            response.sendError(HttpServletResponse.SC_FORBIDDEN, "Access Denied: You cannot view salary slips of other employees.");
            return;
        }

        SalaryStructure struct = payrollDAO.getActiveSalaryStructure(payroll.getEmployeeId());

        request.setAttribute("payroll", payroll);
        request.setAttribute("structure", struct);
     // Change from: request.getRequestDispatcher("/payroll/salary-slip.jsp").forward(request, response);
     // To:
     request.getRequestDispatcher("/salary-slip.jsp").forward(request, response);
    }
}