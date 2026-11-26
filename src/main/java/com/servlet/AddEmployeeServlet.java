package com.servlet;

import com.model.Employee;
import com.service.EmployeeService;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;

@WebServlet("/employee/add")
public class AddEmployeeServlet extends HttpServlet {

    private EmployeeService employeeService;

    @Override
    public void init() {
        employeeService = (EmployeeService) getServletContext().getAttribute("employeeService");
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {

       
        HttpSession session = request.getSession(false);
        Employee loggedInUser = (session != null) ? (Employee) session.getAttribute("loggedInEmployee") : null;

        if (loggedInUser == null) {
            response.sendRedirect(request.getContextPath() + "/login");
            return;
        }

        if (!"ADMIN".equalsIgnoreCase(loggedInUser.getRole())) {
            response.sendError(HttpServletResponse.SC_FORBIDDEN, "Access Denied: Only Admins can register new employees.");
            return;
        }

        request.getRequestDispatcher("/add-employee.jsp").forward(request, response);
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {

        
        HttpSession session = request.getSession(false);
        Employee loggedInUser = (session != null) ? (Employee) session.getAttribute("loggedInEmployee") : null;

        if (loggedInUser == null) {
            response.sendRedirect(request.getContextPath() + "/login");
            return;
        }

        if (!"ADMIN".equalsIgnoreCase(loggedInUser.getRole())) {
            response.sendError(HttpServletResponse.SC_FORBIDDEN, "Access Denied: Only Admins can register new employees.");
            return;
        }

        String employeeId = request.getParameter("employeeId");
        String name = request.getParameter("name");
        String department = request.getParameter("department");
        String role = request.getParameter("role");
        String password = request.getParameter("password");

        try {
            if (employeeId == null || employeeId.isBlank()) {
                throw new IllegalArgumentException("Employee ID is required.");
            }
            if (name == null || name.isBlank()) {
                throw new IllegalArgumentException("Name is required.");
            }
            if (department == null || department.isBlank()) {
                throw new IllegalArgumentException("Department is required.");
            }
            if (password == null || password.isBlank()) {
                password = "123456"; // Default fallback password
            }
            if (role == null || role.isBlank()) {
                role = "EMPLOYEE";
            }
         // Create employee using standard setters
            Employee emp = new Employee();
            emp.setEmployeeId(employeeId.trim());
            emp.setName(name.trim());
            emp.setDepartment(department.trim());
            emp.setStatus("ACTIVE");
            emp.setRole(role.trim().toUpperCase());
            emp.setPassword(password.trim());
            employeeService.addEmployee(emp);
            request.setAttribute("message", "Employee (" + emp.getEmployeeId() + ") registered successfully as " + emp.getRole() + "!");

        } catch (Exception e) {
            request.setAttribute("error", e.getMessage());
        }

        request.getRequestDispatcher("/add-employee.jsp").forward(request, response);
    }
}