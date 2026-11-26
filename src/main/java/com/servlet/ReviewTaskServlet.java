package com.servlet;

import com.dao.TaskDao;
import com.model.Employee;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.*;

import java.io.IOException;

@WebServlet("/reviewTask")
public class ReviewTaskServlet extends HttpServlet {
    private final TaskDao taskDao = new TaskDao();

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        HttpSession session = request.getSession(false);
        Employee user = (session != null) ? (Employee) session.getAttribute("loggedInEmployee") : null;

        if (user == null || !"MANAGER".equalsIgnoreCase(user.getRole())) {
            response.sendError(HttpServletResponse.SC_FORBIDDEN, "Access Denied: Managers only.");
            return;
        }

        int taskId = Integer.parseInt(request.getParameter("taskId"));
        String status = request.getParameter("status"); // COMPLETED or REVISION_NEEDED
        String feedback = request.getParameter("managerFeedback");
        
        int rating = 0;
        try {
            rating = Integer.parseInt(request.getParameter("rating"));
        } catch (Exception ignored) {}

        taskDao.reviewTaskByManager(taskId, status, rating, feedback);
        session.setAttribute("toastMsg", "Task graded and marked " + status);
        response.sendRedirect(request.getContextPath() + "/manageTasks");
    }
}