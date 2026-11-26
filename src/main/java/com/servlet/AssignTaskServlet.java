package com.servlet;

import com.dao.TaskDao;
import com.dao.TeamDao;
import com.model.Employee;
import com.model.Task;
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

@WebServlet("/manager/tasks/assign")
@MultipartConfig(
    fileSizeThreshold = 1024 * 1024,        // 1 MB buffer
    maxFileSize = 10 * 1024 * 1024,         // 10 MB per individual file
    maxRequestSize = 25 * 1024 * 1024       // 25 MB total request limit for multiple PDFs
)
public class AssignTaskServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;
    private final TaskDao taskDao = new TaskDao();
    private final TeamDao teamDao = new TeamDao();

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        
        HttpSession session = request.getSession(false);
        Employee user = (session != null) ? (Employee) session.getAttribute("loggedInEmployee") : null;

        if (user == null || !"MANAGER".equalsIgnoreCase(user.getRole())) {
            response.sendError(HttpServletResponse.SC_FORBIDDEN, "Access Denied: Only managers can assign tasks.");
            return;
        }

        int teamId = 0;
        try {
            String teamIdStr = request.getParameter("teamId");
            if (teamIdStr != null && !teamIdStr.isBlank()) {
                teamId = Integer.parseInt(teamIdStr);
            }

            String assignmentType = request.getParameter("assignmentType"); // "INDIVIDUAL", "MULTIPLE", or "TEAM"
            String assignedTo = request.getParameter("assignedTo");
            if (assignedTo == null || assignedTo.isBlank()) {
                assignedTo = request.getParameter("employeeId");
            }

            String title = request.getParameter("title");
            String description = request.getParameter("description");
            String priority = request.getParameter("priority");
            if (priority == null || priority.isBlank()) {
                priority = "MEDIUM";
            }

            // Start Date
            String startDateStr = request.getParameter("startDate");
            LocalDate startDate = (startDateStr != null && !startDateStr.isBlank())
                    ? LocalDate.parse(startDateStr.trim())
                    : LocalDate.now();

            // Due Date
            String dueDateStr = request.getParameter("dueDate");
            LocalDate dueDate = (dueDateStr != null && !dueDateStr.isBlank()) 
                    ? LocalDate.parse(dueDateStr.trim()) 
                    : null;

            // Date validation
            if (dueDate != null && dueDate.isBefore(startDate)) {
                session.setAttribute("toastErr", "Due date cannot be before start date.");
                response.sendRedirect(request.getContextPath() + "/manager/dashboard" + (teamId > 0 ? "?teamId=" + teamId : ""));
                return;
            }

            // --- Multiple File Attachments Handling ---
            List<String> uploadedFileNames = new ArrayList<>();
            String uploadPath = getServletContext().getRealPath("/uploads/tasks");
            File uploadDir = new File(uploadPath);
            if (!uploadDir.exists()) {
                uploadDir.mkdirs();
            }

            for (Part part : request.getParts()) {
                if (("taskFiles".equals(part.getName()) || "taskFile".equals(part.getName())) && part.getSize() > 0) {
                    if (part.getSize() > 10 * 1024 * 1024) {
                        session.setAttribute("toastErr", "One of your attachments exceeds the 10 MB limit.");
                        response.sendRedirect(request.getContextPath() + "/manager/dashboard" + (teamId > 0 ? "?teamId=" + teamId : ""));
                        return;
                    }

                    String submittedName = Paths.get(part.getSubmittedFileName()).getFileName().toString();
                    String cleanName = submittedName.replaceAll("[^a-zA-Z0-9\\.\\-_]", "_");
                    String savedFileName = System.currentTimeMillis() + "_" + cleanName;

                    part.write(uploadPath + File.separator + savedFileName);
                    uploadedFileNames.add(savedFileName);
                }
            }

            // Store files as comma-separated values (or null if no file was uploaded)
            String savedFileName = !uploadedFileNames.isEmpty() ? String.join(",", uploadedFileNames) : null;

            // --- CASE 1: MULTIPLE EMPLOYEES CHECKED ---
            if ("MULTIPLE".equalsIgnoreCase(assignmentType)) {
                String[] selectedEmployees = request.getParameterValues("selectedEmployees");
                if (selectedEmployees == null || selectedEmployees.length == 0) {
                    session.setAttribute("toastErr", "Please check at least one employee from the list.");
                    response.sendRedirect(request.getContextPath() + "/manager/dashboard?teamId=" + teamId);
                    return;
                }

                for (String empId : selectedEmployees) {
                    if (empId == null || empId.isBlank()) continue;
                    Task t = new Task();
                    t.setTaskTitle(title);
                    t.setTitle(title);
                    t.setDescription(description);
                    t.setTaskFilePath(savedFileName);
                    t.setAssignedToName(empId.trim());
                    t.setCreatedByName(user.getEmployeeId());
                    t.setTeamId(teamId);
                    t.setPriority(priority);
                    t.setStartDate(startDate);
                    t.setDueDate(dueDate);
                    t.setStatus("ASSIGNED");

                    taskDao.createTask(t);
                }

                session.setAttribute("toastMsg", "Task assigned to " + selectedEmployees.length + " selected employees successfully.");

            // --- CASE 2: WHOLE TEAM BROADCAST ---
            } else if ("TEAM".equalsIgnoreCase(assignmentType) || "ALL".equalsIgnoreCase(assignedTo)) {
                List<Employee> members = teamDao.getTeamMembers(teamId);
                
                if (members == null || members.isEmpty()) {
                    session.setAttribute("toastErr", "No active members found in this team.");
                    response.sendRedirect(request.getContextPath() + "/manager/dashboard?teamId=" + teamId);
                    return;
                }

                for (Employee member : members) {
                    Task t = new Task();
                    t.setTaskTitle(title + " [Team Task]");
                    t.setTitle(title + " [Team Task]");
                    t.setDescription(description);
                    t.setTaskFilePath(savedFileName);
                    t.setAssignedToName(member.getEmployeeId());
                    t.setCreatedByName(user.getEmployeeId());
                    t.setTeamId(teamId);
                    t.setPriority(priority);
                    t.setStartDate(startDate);
                    t.setDueDate(dueDate);
                    t.setStatus("ASSIGNED");

                    taskDao.createTask(t);
                }

                session.setAttribute("toastMsg", "Team task broadcasted to all " + members.size() + " team members successfully.");

            // --- CASE 3: SINGLE EMPLOYEE SELECTED ---
            } else {
                if (assignedTo == null || assignedTo.isBlank()) {
                    session.setAttribute("toastErr", "Please select an employee for individual assignment.");
                    response.sendRedirect(request.getContextPath() + "/manager/dashboard?teamId=" + teamId);
                    return;
                }

                Task t = new Task();
                t.setTaskTitle(title);
                t.setTitle(title);
                t.setDescription(description);
                t.setTaskFilePath(savedFileName);
                t.setAssignedToName(assignedTo.trim());
                t.setCreatedByName(user.getEmployeeId());
                t.setTeamId(teamId);
                t.setPriority(priority);
                t.setStartDate(startDate);
                t.setDueDate(dueDate);
                t.setStatus("ASSIGNED");

                taskDao.createTask(t);
                session.setAttribute("toastMsg", "Task assigned successfully to " + assignedTo.trim() + ".");
            }

            response.sendRedirect(request.getContextPath() + "/manager/dashboard?teamId=" + teamId);

        } catch (IllegalStateException e) {
            session.setAttribute("toastErr", "Upload failed: Files exceed maximum allowed size.");
            response.sendRedirect(request.getContextPath() + "/manager/dashboard" + (teamId > 0 ? "?teamId=" + teamId : ""));
        } catch (Exception e) {
            System.err.println("Error assigning task: " + e.getMessage());
            e.printStackTrace();
            session.setAttribute("toastErr", "Failed to assign task: " + e.getMessage());
            response.sendRedirect(request.getContextPath() + "/manager/dashboard" + (teamId > 0 ? "?teamId=" + teamId : ""));
        }
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        response.sendRedirect(request.getContextPath() + "/manager/dashboard");
    }
}