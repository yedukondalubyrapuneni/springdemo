package com.servlet;

import com.dao.TaskDao;
import com.model.Employee;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.MultipartConfig;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import jakarta.servlet.http.Part;

import java.io.File;
import java.io.IOException;
import java.nio.file.Paths;

@WebServlet("/employee/task/update")
@MultipartConfig(
    fileSizeThreshold = 1024 * 1024,        // 1 MB buffer
    maxFileSize = 10 * 1024 * 1024,         // 10 MB strict file size limit
    maxRequestSize = 25 * 1024 * 1024       // 25 MB max total request size
)
public class UpdateTaskStatusServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;
    private final TaskDao taskDao = new TaskDao();

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        Employee loggedIn = (session != null) ? (Employee) session.getAttribute("loggedInEmployee") : null;

        if (loggedIn == null) {
            response.sendRedirect(request.getContextPath() + "/login.jsp");
            return;
        }

        try {
            int taskId = Integer.parseInt(request.getParameter("taskId"));
            String note = request.getParameter("employeeSubmissionNote");
            if (note == null || note.trim().isEmpty()) {
                note = request.getParameter("employeeComment");
            }
            if (note == null || note.trim().isEmpty()) {
                note = request.getParameter("comment");
            }

            // Default to review status
            String newStatus = request.getParameter("status");
            if (newStatus == null || newStatus.trim().isEmpty()) {
                newStatus = "SUBMITTED_FOR_REVIEW";
            }

            // 1. Check all commonly used file parameter names
            Part filePart = request.getPart("submissionFile");
            if (filePart == null || filePart.getSize() == 0) {
                filePart = request.getPart("submissionDoc");
            }
            if (filePart == null || filePart.getSize() == 0) {
                filePart = request.getPart("proofFile");
            }
            if (filePart == null || filePart.getSize() == 0) {
                filePart = request.getPart("proofDoc");
            }
            if (filePart == null || filePart.getSize() == 0) {
                filePart = request.getPart("taskFile");
            }
            if (filePart == null || filePart.getSize() == 0) {
                filePart = request.getPart("file");
            }

            // Fallback: iterate over parts if named dynamically
            if (filePart == null || filePart.getSize() == 0) {
                for (Part p : request.getParts()) {
                    if (p.getSubmittedFileName() != null && !p.getSubmittedFileName().isBlank() && p.getSize() > 0) {
                        filePart = p;
                        break;
                    }
                }
            }

            String savedFileName = null;
            if (filePart != null && filePart.getSize() > 0) {
                if (filePart.getSize() > 10 * 1024 * 1024) {
                    session.setAttribute("toastErr", "File upload failed: Document exceeds the 10 MB limit.");
                    response.sendRedirect(request.getContextPath() + "/employee/workspace");
                    return;
                }

                String submittedName = Paths.get(filePart.getSubmittedFileName()).getFileName().toString();
                String cleanName = submittedName.replaceAll("[^a-zA-Z0-9\\.\\-_]", "_");
                savedFileName = System.currentTimeMillis() + "_" + cleanName;

                String uploadPath = getServletContext().getRealPath("/uploads/submissions");
                File uploadDir = new File(uploadPath);
                if (!uploadDir.exists()) {
                    uploadDir.mkdirs();
                }

                filePart.write(uploadPath + File.separator + savedFileName);
                System.out.println(">>> File written successfully: " + uploadPath + File.separator + savedFileName);
            } else {
                System.out.println(">>> No file detected in request for Task ID: " + taskId);
            }

            // 2. Persist note and uploaded document in DAO
            taskDao.submitEmployeeTaskWithProof(taskId, loggedIn.getEmployeeId(), note, savedFileName, newStatus);
            session.setAttribute("toastMsg", "Task submission and proof document submitted to Manager for review!");

        } catch (IllegalStateException e) {
            System.err.println("Upload size exceeded: " + e.getMessage());
            session.setAttribute("toastErr", "Upload failed: Document must be under 10MB.");
        } catch (Exception e) {
            System.err.println("Task status update failure: " + e.getMessage());
            e.printStackTrace();
            session.setAttribute("toastErr", "Submission error: " + e.getMessage());
        }

        response.sendRedirect(request.getContextPath() + "/employee/workspace");
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        response.sendRedirect(request.getContextPath() + "/employee/workspace");
    }
}