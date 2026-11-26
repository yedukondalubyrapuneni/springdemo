package com.servlet;

import com.Util.EmailService;
import com.dao.PayrollDAO;
import com.dao.PayrollPaymentDAO;
import com.model.Employee;
import com.model.Payroll;
import com.model.PayrollPayment;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;
import java.math.BigDecimal;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;

@WebServlet("/payroll/payment")
public class PayrollPaymentServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;

    private final PayrollDAO payrollDAO = new PayrollDAO();
    private final PayrollPaymentDAO paymentDAO = new PayrollPaymentDAO();

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

        String idParam = request.getParameter("payrollId");
        if (idParam == null || idParam.isBlank()) {
            response.sendRedirect(request.getContextPath() + "/dashboard.jsp?tab=tab-processcycle");
            return;
        }

        try {
            int payrollId = Integer.parseInt(idParam.trim());
            Payroll payroll = payrollDAO.getPayrollById(payrollId);

            if (payroll == null) {
                response.sendRedirect(request.getContextPath() + "/dashboard.jsp?tab=tab-processcycle&error=Payroll%20record%20not%20found");
                return;
            }

            List<PayrollPayment> payments = paymentDAO.getPaymentsByPayrollId(payrollId);

            request.setAttribute("payroll", payroll);
            request.setAttribute("payments", payments);

            request.getRequestDispatcher("/payroll-payment.jsp").forward(request, response);
        } catch (Exception e) {
            e.printStackTrace();
            response.sendRedirect(request.getContextPath() + "/dashboard.jsp?tab=tab-processcycle&error=" 
                    + URLEncoder.encode("Invalid ID: " + e.getMessage(), StandardCharsets.UTF_8));
        }
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
            response.sendError(HttpServletResponse.SC_FORBIDDEN, "Access Denied: Only Admin or HR can record disbursements.");
            return;
        }

        String referer = request.getHeader("Referer");
        boolean fromDashboard = (referer != null && referer.contains("dashboard.jsp"));

        try {
            int payrollId = Integer.parseInt(request.getParameter("payrollId").trim());
            
            // Payment Date
            String dateParam = request.getParameter("paymentDate");
            LocalDate paymentDate = (dateParam != null && !dateParam.isBlank()) 
                    ? LocalDate.parse(dateParam.trim()) 
                    : LocalDate.now();

            // Payment Method
            String methodParam = request.getParameter("paymentMethod");
            String paymentMethod = (methodParam != null && !methodParam.isBlank()) 
                    ? methodParam.trim() 
                    : "Direct Bank Transfer";

            // Reference Number / Transaction ID
            String refParam = request.getParameter("referenceNumber");
            if (refParam == null || refParam.isBlank()) {
                refParam = request.getParameter("transactionId");
            }
            String referenceNumber = (refParam != null && !refParam.isBlank()) ? refParam.trim() : "N/A";

            // Amount Paid (Default to payroll Net Salary if not provided)
            Payroll payroll = payrollDAO.getPayrollById(payrollId);
            if (payroll == null) {
                response.sendRedirect(request.getContextPath() + "/dashboard.jsp?tab=tab-processcycle&error=Payroll%20record%20not%20found");
                return;
            }

            BigDecimal amountPaid;
            String amountParam = request.getParameter("amountPaid");
            if (amountParam != null && !amountParam.isBlank()) {
                amountPaid = new BigDecimal(amountParam.trim());
            } else {
                amountPaid = (payroll.getNetSalary() != null) ? payroll.getNetSalary() : BigDecimal.ZERO;
            }

            // 1. Record the Payment
            PayrollPayment payment = new PayrollPayment(payrollId, paymentDate, paymentMethod, referenceNumber, amountPaid);
            boolean success = paymentDAO.recordPayment(payment);

            if (success) {
                // 2. Fetch Employee Profile with Email and dispatch payslip automatically in background
                Map<String, String> empProfile = payrollDAO.getEmployeeProfileForSalary(payroll.getEmployeeId());
                EmailService.sendPayslipAsync(payroll, empProfile, referenceNumber, paymentMethod);

                // 3. Return cleanly to the caller
                String successMsg = URLEncoder.encode("Disbursement recorded and payslip emailed successfully to employee", StandardCharsets.UTF_8);
                if (fromDashboard) {
                    response.sendRedirect(request.getContextPath() + "/dashboard.jsp?tab=tab-processcycle&msg=" + successMsg);
                } else {
                    response.sendRedirect(request.getContextPath() + "/payroll/payment?payrollId=" + payrollId + "&msg=" + successMsg);
                }
            } else {
                String errMsg = URLEncoder.encode("Failed to record disbursement in payment records", StandardCharsets.UTF_8);
                if (fromDashboard) {
                    response.sendRedirect(request.getContextPath() + "/dashboard.jsp?tab=tab-processcycle&error=" + errMsg);
                } else {
                    response.sendRedirect(request.getContextPath() + "/payroll/payment?payrollId=" + payrollId + "&error=" + errMsg);
                }
            }

        } catch (Exception e) {
            e.printStackTrace();
            String errorMsg = URLEncoder.encode("Disbursement error: " + e.getMessage(), StandardCharsets.UTF_8);
            if (fromDashboard) {
                response.sendRedirect(request.getContextPath() + "/dashboard.jsp?tab=tab-processcycle&error=" + errorMsg);
            } else {
                response.sendRedirect(request.getContextPath() + "/payroll/process?error=" + errorMsg);
            }
        }
    }
}