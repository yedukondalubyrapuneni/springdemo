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
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

@WebServlet("/manager/tasks")
@MultipartConfig(
    fileSizeThreshold = 1024 * 1024,        // 1 MB buffer
    maxFileSize = 10 * 1024 * 1024,         // 10 MB maximum file size
    maxRequestSize = 25 * 1024 * 1024       // 25 MB total request size for multiple files
)
public class ManagerTaskServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;
    private final TaskDao taskDao = new TaskDao();

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        HttpSession session = request.getSession(false);
        Employee mgr = (session != null) ? (Employee) session.getAttribute("loggedInEmployee") : null;

        // Strict RBAC: Only Managers can modify, review, or delete tasks
        if (mgr == null || !"MANAGER".equalsIgnoreCase(mgr.getRole())) {
            response.sendError(HttpServletResponse.SC_FORBIDDEN, "Access Denied: Managers only.");
            return;
        }

        String action = request.getParameter("action");
        int teamId = 0;
        try {
            String teamIdStr = request.getParameter("teamId");
            if (teamIdStr != null && !teamIdStr.isBlank()) {
                teamId = Integer.parseInt(teamIdStr);
            }

            // A. Update Task Details (Title, Description, Priority, Due Date, and Optional File Replacement)
            if ("UPDATE_TASK_DETAILS".equalsIgnoreCase(action)) {
                int taskId = Integer.parseInt(request.getParameter("taskId"));
                String title = request.getParameter("title");
                String description = request.getParameter("description");
                String priority = request.getParameter("priority");
                String dueDateStr = request.getParameter("dueDate");
                LocalDate dueDate = (dueDateStr != null && !dueDateStr.trim().isEmpty())
                        ? LocalDate.parse(dueDateStr.trim())
                        : null;

                // Process uploaded replacement files
                List<String> uploadedFileNames = new ArrayList<>();
                String uploadPath = getServletContext().getRealPath("/uploads/tasks");
                File uploadDir = new File(uploadPath);
                if (!uploadDir.exists()) {
                    uploadDir.mkdirs();
                }

                for (Part part : request.getParts()) {
                    if (("taskFiles".equals(part.getName()) || "taskFile".equals(part.getName())) && part.getSize() > 0) {
                        if (part.getSize() > 10 * 1024 * 1024) {
                            session.setAttribute("toastErr", "One of the uploaded files exceeds the 10 MB limit.");
                            response.sendRedirect(request.getContextPath() + "/manager/dashboard" + (teamId > 0 ? "?teamId=" + teamId : ""));
                            return;
                        }

                        String submittedName = Paths.get(part.getSubmittedFileName()).getFileName().toString();
                        String cleanName = submittedName.replaceAll("[^a-zA-Z0-9\\.\\-_]", "_");
                        String savedName = System.currentTimeMillis() + "_" + cleanName;

                        part.write(uploadPath + File.separator + savedName);
                        uploadedFileNames.add(savedName);
                    }
                }

                // If new files were supplied, purge previous files and update database mapping
                if (!uploadedFileNames.isEmpty()) {
                    String existingFilePaths = taskDao.getTaskFilePathById(taskId);
                    if (existingFilePaths != null && !existingFilePaths.isBlank()) {
                        for (String oldFileName : existingFilePaths.split(",")) {
                            File oldFile = new File(uploadPath + File.separator + oldFileName.trim());
                            if (oldFile.exists()) {
                                oldFile.delete();
                            }
                        }
                    }

                    String newCombinedPaths = String.join(",", uploadedFileNames);
                    taskDao.updateTaskDetailsWithFiles(taskId, title, description, priority, dueDate, newCombinedPaths);
                    session.setAttribute("toastMsg", "Task details and attached files updated successfully.");
                } else {
                    // Retain current files unchanged
                    taskDao.updateTaskDetails(taskId, title, description, priority, dueDate);
                    session.setAttribute("toastMsg", "Task details updated successfully.");
                }
            }

            // B. Manager sets final status, rating (1-5), and feedback
            else if ("UPDATE_STATUS".equalsIgnoreCase(action)) {
                int taskId = Integer.parseInt(request.getParameter("taskId"));
                String newStatus = request.getParameter("newStatus");
                String feedback = request.getParameter("managerFeedback");

                int rating = 0;
                String ratingStr = request.getParameter("rating");
                if (ratingStr != null && !ratingStr.trim().isEmpty()) {
                    try {
                        rating = Integer.parseInt(ratingStr.trim());
                    } catch (NumberFormatException ignored) {}
                }

                taskDao.reviewTaskByManager(taskId, newStatus, rating, feedback);
                session.setAttribute("toastMsg", "Task review, rating (" + rating + "★), and feedback saved successfully.");
            }

            // C. Manager assigns task (Handles both single and multi-file attachments)
            else if ("ASSIGN_TASK".equalsIgnoreCase(action)) {
                String title = request.getParameter("title");
                String description = request.getParameter("description");
                String assignmentType = request.getParameter("assignmentType");

                String startDateStr = request.getParameter("startDate");
                LocalDate startDate = (startDateStr != null && !startDateStr.trim().isEmpty()) 
                        ? LocalDate.parse(startDateStr.trim()) 
                        : LocalDate.now();

                String dueDateStr = request.getParameter("dueDate");
                LocalDate dueDate = (dueDateStr != null && !dueDateStr.trim().isEmpty()) 
                        ? LocalDate.parse(dueDateStr.trim()) 
                        : null;

                List<String> uploadedFileNames = new ArrayList<>();
                String uploadPath = getServletContext().getRealPath("/uploads/tasks");
                File uploadDir = new File(uploadPath);
                if (!uploadDir.exists()) {
                    uploadDir.mkdirs();
                }

                for (Part part : request.getParts()) {
                    if (("taskFiles".equals(part.getName()) || "taskFile".equals(part.getName())) && part.getSize() > 0) {
                        if (part.getSize() > 10 * 1024 * 1024) {
                            session.setAttribute("toastErr", "Uploaded task briefing file exceeds 10 MB limit.");
                            response.sendRedirect(request.getContextPath() + "/manager/dashboard" + (teamId > 0 ? "?teamId=" + teamId : ""));
                            return;
                        }

                        String submittedName = Paths.get(part.getSubmittedFileName()).getFileName().toString();
                        String cleanName = submittedName.replaceAll("[^a-zA-Z0-9\\.\\-_]", "_");
                        String savedName = System.currentTimeMillis() + "_" + cleanName;

                        part.write(uploadPath + File.separator + savedName);
                        uploadedFileNames.add(savedName);
                    }
                }

                String savedFileName = !uploadedFileNames.isEmpty() ? String.join(",", uploadedFileNames) : null;

                if ("TEAM".equalsIgnoreCase(assignmentType)) {
                    taskDao.assignTaskToEntireTeamWithFile(title, description, savedFileName, teamId, mgr.getEmployeeId(), startDate, dueDate);
                    session.setAttribute("toastMsg", "Task broadcasted to the entire team successfully.");
                } else {
                    String targetEmployeeId = request.getParameter("employeeId");
                    if (targetEmployeeId == null || targetEmployeeId.trim().isEmpty()) {
                        targetEmployeeId = request.getParameter("assigneeId");
                    }
                    taskDao.assignTaskToEmployeeWithFile(title, description, savedFileName, targetEmployeeId, mgr.getEmployeeId(), startDate, dueDate);
                    session.setAttribute("toastMsg", "Task assigned to employee " + targetEmployeeId + " successfully.");
                }
            }

            // D. Delete Task & Cleanup Server Files
            else if ("DELETE_TASK".equalsIgnoreCase(action)) {
                int taskId = Integer.parseInt(request.getParameter("taskId"));
                
                String existingFilePaths = taskDao.getTaskFilePathById(taskId);
                if (existingFilePaths != null && !existingFilePaths.isBlank()) {
                    String uploadPath = getServletContext().getRealPath("/uploads/tasks");
                    for (String fileName : existingFilePaths.split(",")) {
                        File f = new File(uploadPath + File.separator + fileName.trim());
                        if (f.exists()) {
                            f.delete();
                        }
                    }
                }

                taskDao.deleteTask(taskId);
                session.setAttribute("toastMsg", "Task and associated files removed successfully.");
            }

        } catch (IllegalStateException e) {
            System.err.println("Upload size exceeded: " + e.getMessage());
            session.setAttribute("toastErr", "File upload failed: Files exceed the allowable upload limit.");
        } catch (Exception e) {
            System.err.println("Manager action error: " + e.getMessage());
            e.printStackTrace();
            session.setAttribute("toastErr", "Action failed: " + e.getMessage());
        }

        response.sendRedirect(request.getContextPath() + "/manager/dashboard" + (teamId > 0 ? "?teamId=" + teamId : ""));
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        response.sendRedirect(request.getContextPath() + "/manager/dashboard");
    }
}