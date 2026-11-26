package com.servlet;

import com.model.Employee;
import com.model.Payroll;
import com.dao.PayrollDAO;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;
import java.time.LocalDate;
import java.util.List;

@WebServlet("/payroll/history")
public class PayrollHistoryServlet extends HttpServlet {
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

        String role = (loggedIn.getRole() != null) ? loggedIn.getRole().trim().toUpperCase() : "";
        boolean isAdmin = "ADMIN".equals(role);
        boolean isHr = "HR".equals(role) || loggedIn.isHrDesignation();

        String requestedEmpId = request.getParameter("employeeId");
        String monthParam = request.getParameter("month");
        String yearParam = request.getParameter("year");

        Integer month = (monthParam != null && !monthParam.isBlank() && !"-1".equals(monthParam)) 
                        ? Integer.parseInt(monthParam.trim()) : null;
        Integer year = (yearParam != null && !yearParam.isBlank() && !"-1".equals(yearParam)) 
                       ? Integer.parseInt(yearParam.trim()) : null;

        // ROLE ACCESS ENFORCEMENT:
        // - Admin & HR: Can view all employees or filter by requested employeeId.
        // - Managers & Employees: Strictly scoped to their own self employee ID.
        String targetEmpId;
        if (isAdmin || isHr) {
            targetEmpId = (requestedEmpId != null && !requestedEmpId.isBlank()) ? requestedEmpId.trim() : null;
        } else {
            targetEmpId = loggedIn.getEmployeeId();
        }

        List<Payroll> history = payrollDAO.getPayrollHistory(targetEmpId, month, year);

        request.setAttribute("historyList", history);
        request.setAttribute("selectedMonth", month != null ? month : -1);
        request.setAttribute("selectedYear", year != null ? year : LocalDate.now().getYear());
        request.setAttribute("targetEmpId", targetEmpId != null ? targetEmpId : "");
        request.setAttribute("canViewAll", isAdmin || isHr);

        // Dispatches to flat webapp path
        request.getRequestDispatcher("/payroll-history.jsp").forward(request, response);
    }
}