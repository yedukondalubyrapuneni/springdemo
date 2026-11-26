package com.servlet;

import com.model.Employee;
import com.model.Payroll;
import com.model.SalaryStructure;
import com.dao.PayrollDAO;
import com.Util.PayrollCalculator;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

@WebServlet("/payroll/process")
public class PayrollProcessingServlet extends HttpServlet {
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
        boolean isAuthorized = "ADMIN".equals(role) || "HR".equals(role) || loggedIn.isHrDesignation();

        if (!isAuthorized) {
            response.sendRedirect(request.getContextPath() + "/dashboard.jsp");
            return;
        }

        // Always redirect GET requests directly to the in-page dashboard tab
        String month = request.getParameter("month");
        String year = request.getParameter("year");
        String empId = request.getParameter("employeeId");

        StringBuilder redirectUrl = new StringBuilder(request.getContextPath() + "/dashboard.jsp?tab=tab-processcycle");
        if (month != null && !month.isBlank()) redirectUrl.append("&month=").append(month.trim());
        if (year != null && !year.isBlank()) redirectUrl.append("&year=").append(year.trim());
        if (empId != null && !empId.isBlank()) redirectUrl.append("&employeeId=").append(URLEncoder.encode(empId.trim(), StandardCharsets.UTF_8));

        response.sendRedirect(redirectUrl.toString());
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        Employee loggedIn = (session != null) ? (Employee) session.getAttribute("loggedInEmployee") : null;

        if (loggedIn == null) {
            response.sendRedirect(request.getContextPath() + "/login.jsp");
            return;
        }

        String role = (loggedIn.getRole() != null) ? loggedIn.getRole().trim().toUpperCase() : "";
        boolean isAuthorized = "ADMIN".equals(role) || "HR".equals(role) || loggedIn.isHrDesignation();

        if (!isAuthorized) {
            response.sendError(HttpServletResponse.SC_FORBIDDEN, "Access Denied: Only Admin and HR can process payroll.");
            return;
        }

        String employeeId = request.getParameter("employeeId");
        String monthParam = request.getParameter("month");
        String yearParam = request.getParameter("year");

        if (employeeId == null || employeeId.isBlank() || monthParam == null || yearParam == null) {
            response.sendRedirect(request.getContextPath() + "/dashboard.jsp?tab=tab-processcycle&error=Missing%20required%20fields");
            return;
        }

        String cleanEmpId = employeeId.trim().toUpperCase();
        int month = Integer.parseInt(monthParam.trim());
        int year = Integer.parseInt(yearParam.trim());

        try {
            List<String> targetEmployeeIds = new ArrayList<>();

            // Support "ALL" vs single Employee ID
            if ("ALL".equals(cleanEmpId)) {
                List<Employee> allEmployees = payrollDAO.getAllActiveEmployees();
                for (Employee e : allEmployees) {
                    if (e.getEmployeeId() != null && !e.getEmployeeId().isBlank()) {
                        targetEmployeeIds.add(e.getEmployeeId().trim().toUpperCase());
                    }
                }
            } else {
                targetEmployeeIds.add(cleanEmpId);
            }

            int processedCount = 0;
            int skippedCount = 0;

            for (String empId : targetEmployeeIds) {
                SalaryStructure structure = payrollDAO.getActiveSalaryStructure(empId);
                
                // If single employee missing structure, notify HR directly
                if (structure == null) {
                    if (!"ALL".equals(cleanEmpId)) {
                        String errMsg = URLEncoder.encode("No active salary structure found for " + empId + " (Please setup structure first)", StandardCharsets.UTF_8);
                        response.sendRedirect(request.getContextPath() + "/dashboard.jsp?tab=tab-processcycle&month=" + month + "&year=" + year + "&employeeId=" + cleanEmpId + "&error=" + errMsg);
                        return;
                    }
                    skippedCount++;
                    continue;
                }

                // 2. Compute attendance (1 Sick + 1 Casual paid leave logic)
                int[] att = payrollDAO.computeAttendanceAndLOP(empId, month, year);

                // 3. Compute breakdown
                Payroll payroll = PayrollCalculator.compute(structure, month, year, att[0], att[1], att[2]);
                payroll.setProcessedBy(loggedIn.getEmployeeId());
                payroll.setStatus("PROCESSED");

                // 4. Save/Update record
                if (payrollDAO.savePayroll(payroll)) {
                    processedCount++;
                }
            }

            String successMsg;
            if ("ALL".equals(cleanEmpId)) {
                successMsg = "Payroll processed for " + processedCount + " employees for " + month + "/" + year;
                if (skippedCount > 0) {
                    successMsg += " (" + skippedCount + " skipped: missing salary structure)";
                }
            } else {
                successMsg = "Payroll processed successfully for " + cleanEmpId;
            }

            // REDIRECT DIRECTLY TO DASHBOARD PROCESS CYCLE TAB (NEVER GO TO EXTERNAL PAGE)
            response.sendRedirect(request.getContextPath() + "/dashboard.jsp?tab=tab-processcycle"
                    + "&month=" + month 
                    + "&year=" + year 
                    + "&employeeId=" + URLEncoder.encode(cleanEmpId, StandardCharsets.UTF_8)
                    + "&msg=" + URLEncoder.encode(successMsg, StandardCharsets.UTF_8));

        } catch (Exception e) {
            e.printStackTrace();
            response.sendRedirect(request.getContextPath() + "/dashboard.jsp?tab=tab-processcycle&month=" + month + "&year=" + year 
                    + "&error=" + URLEncoder.encode("Error: " + e.getMessage(), StandardCharsets.UTF_8));
        }
    }
}