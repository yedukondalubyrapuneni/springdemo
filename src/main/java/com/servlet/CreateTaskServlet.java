package com.servlet;

import com.dao.TaskDao;
import com.model.Employee;
import com.model.Task;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.MultipartConfig;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.*;

import java.io.File;
import java.io.IOException;
import java.nio.file.Paths;
import java.time.LocalDate;

@WebServlet("/createTask")
@MultipartConfig(
    maxFileSize = 10 * 1024 * 1024,      // 10 MB
    maxRequestSize = 12 * 1024 * 1024
)
public class CreateTaskServlet extends HttpServlet {
    private final TaskDao taskDAO = new TaskDao();

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        HttpSession session = request.getSession(false);
        Employee user = (session != null) ? (Employee) session.getAttribute("loggedInEmployee") : null;

        // Strict RBAC: Manager Only (Admin is view-only)
        if (user == null || !"MANAGER".equalsIgnoreCase(user.getRole())) {
            response.sendError(HttpServletResponse.SC_FORBIDDEN, "Access Denied: Managers only.");
            return;
        }

        String title = request.getParameter("taskTitle");
        String description = request.getParameter("description");
        int assignedTo = Integer.parseInt(request.getParameter("assignedTo"));
        String department = request.getParameter("department");
        String priority = request.getParameter("priority");
        LocalDate startDate = LocalDate.parse(request.getParameter("startDate"));
        LocalDate dueDate = LocalDate.parse(request.getParameter("dueDate"));

        if (dueDate.isBefore(startDate)) {
            session.setAttribute("toastErr", "Due date cannot be before start date.");
            response.sendRedirect(request.getContextPath() + "/manageTasks");
            return;
        }

        // Handle Manager File Attachment
        Part filePart = request.getPart("taskFile");
        String savedFileName = null;
        if (filePart != null && filePart.getSize() > 0) {
            String fileName = Paths.get(filePart.getSubmittedFileName()).getFileName().toString();
            String uploadDir = getServletContext().getRealPath("/uploads/tasks");
            File dir = new File(uploadDir);
            if (!dir.exists()) dir.mkdirs();

            savedFileName = System.currentTimeMillis() + "_" + fileName;
            filePart.write(uploadDir + File.separator + savedFileName);
        }

        Task task = new Task();
        task.setTaskTitle(title);
        task.setDescription(description);
        task.setTaskFilePath(savedFileName);
        task.setAssignedTo(assignedTo);
        task.setCreatedBy(Integer.parseInt(user.getEmployeeId()));
        task.setDepartment(department);
        task.setPriority(priority);
        task.setStartDate(startDate);
        task.setDueDate(dueDate);
        task.setStatus("ASSIGNED");

        taskDAO.createTask(task);
        session.setAttribute("toastMsg", "Task created with attachment successfully.");
        response.sendRedirect(request.getContextPath() + "/manageTasks");
    }
}