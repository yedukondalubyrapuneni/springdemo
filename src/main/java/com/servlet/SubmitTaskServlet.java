package com.servlet;

import com.dao.TaskDao;
import com.model.Employee;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.MultipartConfig;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.*;

import java.io.File;
import java.io.IOException;
import java.nio.file.Paths;

@WebServlet("/submitTask")
@MultipartConfig(
    maxFileSize = 10 * 1024 * 1024,      // 10 MB strict limit
    maxRequestSize = 12 * 1024 * 1024
)
public class SubmitTaskServlet extends HttpServlet {
    private final TaskDao taskDAO = new TaskDao();

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        HttpSession session = request.getSession(false);
        Employee emp = (session != null) ? (Employee) session.getAttribute("loggedInEmployee") : null;

        if (emp == null) {
            response.sendRedirect(request.getContextPath() + "/login.jsp");
            return;
        }

        int taskId = Integer.parseInt(request.getParameter("taskId"));
        String comment = request.getParameter("employeeComment");

        Part filePart = request.getPart("submissionDoc");
        String savedFileName = null;

        if (filePart != null && filePart.getSize() > 0) {
            if (filePart.getSize() > 10 * 1024 * 1024) {
                session.setAttribute("toastErr", "File size exceeds the 10MB limit.");
                response.sendRedirect(request.getContextPath() + "/myTasks");
                return;
            }

            String fileName = Paths.get(filePart.getSubmittedFileName()).getFileName().toString();
            String uploadDir = getServletContext().getRealPath("/uploads/submissions");
            File dir = new File(uploadDir);
            if (!dir.exists()) dir.mkdirs();

            savedFileName = System.currentTimeMillis() + "_" + fileName;
            filePart.write(uploadDir + File.separator + savedFileName);
        }

        taskDAO.submitEmployeeTask(taskId, comment, savedFileName, Integer.parseInt(emp.getEmployeeId()));
        session.setAttribute("toastMsg", "Proof document and comment submitted to Manager!");
        response.sendRedirect(request.getContextPath() + "/myTasks");
    }
}