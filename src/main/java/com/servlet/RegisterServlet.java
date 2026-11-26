package com.servlet;

import com.dao.EmployeeDao;
import com.model.Employee;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;

@WebServlet("/register")
public class RegisterServlet extends HttpServlet {

    private EmployeeDao employeeDao;

    @Override
    public void init() {
        employeeDao = new EmployeeDao();
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        request.getRequestDispatcher("/register.jsp").forward(request, response);
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {

        String name = request.getParameter("name");
        String mobile = request.getParameter("mobile");
        String email = request.getParameter("email");
        String password = request.getParameter("password");
        String confirmPassword = request.getParameter("confirmPassword");

        try {
            if (name == null || name.trim().isEmpty() ||
                email == null || email.trim().isEmpty() ||
                mobile==null||
                password == null || password.trim().isEmpty() ||
                confirmPassword == null || confirmPassword.trim().isEmpty()) {
                throw new IllegalArgumentException("All fields are mandatory.");
            }

            if (!password.equals(confirmPassword)) {
                throw new IllegalArgumentException("Passwords do not match. Please re-enter.");
            }

            if (password.trim().length() < 6) {
                throw new IllegalArgumentException("Password must contain at least 6 characters.");
            }

            if (employeeDao.findByIdOrEmail(email.trim()) != null) {
                throw new IllegalArgumentException("An account with email '" + email.trim() + "' already exists.");
            }

           
            String autoEmployeeId = employeeDao.generateNextEmployeeId();

            
            Employee newEmp = new Employee(
                autoEmployeeId,
                name.trim(),
                "General",
                (mobile != null) ? mobile.trim() : "",
                email.trim(),
                "ACTIVE",
                "EMPLOYEE",
                password.trim()
            );

            employeeDao.register(newEmp);

            request.setAttribute("successMessage", 
                    "Registration successful! Your Employee ID is " + autoEmployeeId 
                    + ". You can log in using this ID or your Email address.");
            request.getRequestDispatcher("/login.jsp").forward(request, response);

        } catch (Exception e) {
            request.setAttribute("error", e.getMessage());
            request.getRequestDispatcher("/register.jsp").forward(request, response);
        }
    }
}