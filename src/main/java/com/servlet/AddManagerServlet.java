package com.servlet;

import com.dao.EmployeeDao;
import com.model.Employee;
import com.Util.EmailUtil;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;
import java.security.SecureRandom;

@WebServlet("/admin/add-manager")
public class AddManagerServlet extends HttpServlet {

    private EmployeeDao employeeDao;

    @Override
    public void init() {
        employeeDao = new EmployeeDao();
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        HttpSession session = request.getSession(false);
        Employee user = (session != null) ? (Employee) session.getAttribute("loggedInEmployee") : null;

        if (user == null || !"ADMIN".equalsIgnoreCase(user.getRole())) {
            response.sendRedirect(request.getContextPath() + "/login");
            return;
        }

        request.getRequestDispatcher("/add-manager.jsp").forward(request, response);
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        HttpSession session = request.getSession(false);
        Employee user = (session != null) ? (Employee) session.getAttribute("loggedInEmployee") : null;

        if (user == null || !"ADMIN".equalsIgnoreCase(user.getRole())) {
            response.sendError(HttpServletResponse.SC_FORBIDDEN, "Only System Administrators can provision managers.");
            return;
        }

        String name = request.getParameter("name");
        String email = request.getParameter("email");
        String department = request.getParameter("department");
        String plainPassword = request.getParameter("password");

        try {
            if (name == null || name.isBlank() || email == null || email.isBlank()) {
                throw new IllegalArgumentException("Full Name and Email address are mandatory.");
            }

            // 1. Auto-generate the Manager ID sequentially (MGR01, MGR02, ...)
            String autoManagerId = employeeDao.generateNextManagerId();

            // 2. Fallback temporary password if none entered by Admin
            if (plainPassword == null || plainPassword.isBlank()) {
                int randomPin = 1000 + new SecureRandom().nextInt(9000);
                plainPassword = "Mgr@" + randomPin;
            }

            Employee mgr = new Employee();
            mgr.setEmployeeId(autoManagerId);
            mgr.setName(name.trim());
            mgr.setEmail(email.trim());
            mgr.setDepartment((department != null && !department.isBlank()) ? department.trim() : "General");
            mgr.setRole("MANAGER");
            mgr.setStatus("ACTIVE");
            mgr.setPassword(plainPassword.trim());

            // 3. Persist manager record
            employeeDao.save(mgr);

            // 4. Send credentials email with the auto-generated ID & Password
            EmailUtil.sendManagerCredentials(mgr.getEmail(), mgr.getName(), autoManagerId, plainPassword.trim());

            request.setAttribute("message", "Manager " + mgr.getName() + " provisioned with ID " 
                    + autoManagerId + "! Credentials dispatched to " + mgr.getEmail());

        } catch (Exception e) {
            request.setAttribute("error", e.getMessage());
        }

        request.getRequestDispatcher("/add-manager.jsp").forward(request, response);
    }
}