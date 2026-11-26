package com.servlet;

import com.dao.TaskDao;
import com.model.Employee;
import com.model.Task;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;
import java.util.List;

@WebServlet("/admin/tasks")
public class AdminTaskMonitorServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;
    private final TaskDao taskDao = new TaskDao();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        Employee loggedIn = (session != null) ? (Employee) session.getAttribute("loggedInEmployee") : null;

        if (loggedIn == null) {
            response.sendRedirect(request.getContextPath() + "/login.jsp");
            return;
        }

        // Strict RBAC: Admin only
        if (!"ADMIN".equalsIgnoreCase(loggedIn.getRole())) {
            response.setStatus(HttpServletResponse.SC_FORBIDDEN);
            request.setAttribute("error", "Access Denied: Admins only.");
            request.getRequestDispatcher("/accessDenied.jsp").forward(request, response);
            return;
        }

        // Fetch all company tasks across all employees and managers
        List<Task> allTasks = taskDao.getAllTasks();
        request.setAttribute("allTasks", allTasks);

        request.getRequestDispatcher("/adminTasks.jsp").forward(request, response);
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        // Enforce Read-Only constraint: Admin cannot submit updates or mutations
        response.sendError(HttpServletResponse.SC_METHOD_NOT_ALLOWED, "Admin has read-only monitoring access.");
    }
}