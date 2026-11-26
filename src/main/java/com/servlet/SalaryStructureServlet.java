package com.servlet;

import com.Util.DBConnection;
import com.dao.PayrollDAO;
import com.dao.SalaryStructureDao;
import com.model.Employee;
import com.model.SalaryComponent;
import com.model.SalaryStructure;

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
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

@WebServlet("/payroll/salary-structure")
public class SalaryStructureServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;
    private final SalaryStructureDao structureDao = new SalaryStructureDao();
    private final PayrollDAO payrollDao = new PayrollDAO();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        request.getRequestDispatcher("/salary-structure.jsp").forward(request, response);
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        Employee user = (session != null) ? (Employee) session.getAttribute("loggedInEmployee") : null;

        String role = (user != null && user.getRole() != null) ? user.getRole().trim().toUpperCase() : "";
        boolean isHr = "HR".equals(role) || (user != null && user.isHrDesignation());

        if (!isHr) {
            response.sendError(HttpServletResponse.SC_FORBIDDEN, "Access Denied: Only HR can configure salaries.");
            return;
        }

        // Determine destination return URL based on submitter
        String referer = request.getHeader("Referer");
        String returnBase = (referer != null && referer.contains("dashboard.jsp"))
                ? request.getContextPath() + "/dashboard.jsp"
                : request.getContextPath() + "/salary-structure.jsp";

        try {
            String employeeId = request.getParameter("employeeId");
            String bankName = request.getParameter("bankName");
            String bankAccount = request.getParameter("bankAccount");
            String basicStr = request.getParameter("basic");

            if (employeeId == null || employeeId.isBlank() || basicStr == null || basicStr.isBlank()) {
                response.sendRedirect(returnBase + "?error=" + URLEncoder.encode("Employee ID and Basic are required", StandardCharsets.UTF_8));
                return;
            }

            String cleanEmpId = employeeId.trim();
            String cleanAcc = (bankAccount != null) ? bankAccount.trim() : "";
            String cleanBank = (bankName != null) ? bankName.trim() : "";

            // 1. Prevent duplicate account numbers across different employees
            if (!cleanAcc.isEmpty()) {
                if (payrollDao.isAccountNumberAlreadyAssigned(cleanAcc, cleanEmpId)) {
                    response.sendRedirect(returnBase + "?error=" + URLEncoder.encode("Account number (" + cleanAcc + ") already belongs to another employee.", StandardCharsets.UTF_8));
                    return;
                }
            }

            // 2. Persist Bank Name & Account Number directly into 'employee' (singular)
            if (!cleanBank.isEmpty() && !cleanAcc.isEmpty()) {
                String updateBankSql = "UPDATE employee SET bank_name = ?, account_number = ? WHERE LOWER(TRIM(employee_id)) = LOWER(TRIM(?))";
                try (Connection conn = DBConnection.getConnection();
                     PreparedStatement ps = conn.prepareStatement(updateBankSql)) {
                    ps.setString(1, cleanBank);
                    ps.setString(2, cleanAcc);
                    ps.setString(3, cleanEmpId);
                    ps.executeUpdate();
                } catch (Exception ex) {
                    System.err.println("Note on updating bank info in employee table: " + ex.getMessage());
                }
            }

            // 3. Persist Salary Structure (Dao handles insert vs update)
            BigDecimal basicSalary = new BigDecimal(basicStr.trim());
            SalaryStructure struct = new SalaryStructure();
            struct.setEmployeeId(cleanEmpId);
            struct.setBasicSalary(basicSalary);
            struct.setEffectiveFrom(LocalDate.now());

            List<SalaryComponent> components = new ArrayList<>();
            addExplicitComponent(components, "DA", "EARNING", request.getParameter("da"));
            addExplicitComponent(components, "HRA", "EARNING", request.getParameter("hra"));
            addExplicitComponent(components, "CONVEYANCE", "EARNING", request.getParameter("conveyance"));
            addExplicitComponent(components, "MEDICAL ALLOWANCE", "EARNING", request.getParameter("medical"));
            addExplicitComponent(components, "SPECIAL ALLOWANCE", "EARNING", request.getParameter("special"));
            addExplicitComponent(components, "PROF TAX", "DEDUCTION", request.getParameter("profTax"));
            addExplicitComponent(components, "PF", "DEDUCTION", request.getParameter("pf"));

            struct.setComponents(components);

            int resultId = structureDao.saveSalaryStructure(struct);
            if (resultId > 0) {
                response.sendRedirect(returnBase + "?msg=" + URLEncoder.encode("Salary Structure and Bank Details saved for " + cleanEmpId, StandardCharsets.UTF_8));
            } else {
                response.sendRedirect(returnBase + "?error=" + URLEncoder.encode("Failed to save structure", StandardCharsets.UTF_8));
            }

        } catch (Exception e) {
            e.printStackTrace();
            response.sendRedirect(returnBase + "?error=" + URLEncoder.encode(e.getMessage(), StandardCharsets.UTF_8));
        }
    }

    private void addExplicitComponent(List<SalaryComponent> list, String name, String type, String val) {
        if (val != null && !val.isBlank()) {
            try {
                BigDecimal amt = new BigDecimal(val.trim());
                if (amt.compareTo(BigDecimal.ZERO) >= 0) {
                    SalaryComponent c = new SalaryComponent();
                    c.setComponentName(name);
                    c.setComponentType(type);
                    c.setCalculationType("FIXED");
                    c.setAmount(amt);
                    list.add(c);
                }
            } catch (Exception ignored) {}
        }
    }
}