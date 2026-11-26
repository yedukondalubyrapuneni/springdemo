package com.servlet;

import com.dao.AttendanceDao;
import com.dao.TaskDao;
import com.dao.TeamDao;
import com.model.Attendance;
import com.model.Employee;
import com.model.Task;
import com.model.Team;
import com.Util.DBConnection;

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
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@WebServlet("/employee/workspace")
@MultipartConfig(
    fileSizeThreshold = 1024 * 1024,        // 1 MB buffer
    maxFileSize = 10 * 1024 * 1024,         // 10 MB per proof document
    maxRequestSize = 25 * 1024 * 1024       // 25 MB request limit
)
public class EmployeeWorkspaceServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;
    private final TeamDao teamDao = new TeamDao();
    private final TaskDao taskDao = new TaskDao();
    private final AttendanceDao attendanceDao = new AttendanceDao();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        Employee loggedIn = (session != null) ? (Employee) session.getAttribute("loggedInEmployee") : null;

        if (loggedIn == null) {
            response.sendRedirect(request.getContextPath() + "/login.jsp");
            return;
        }

        // 1. Fetch Today's Shift Attendance Punch for Employee
        Map<String, Object> empAttendance = new HashMap<>();
        String attSql = "SELECT check_in_time, status FROM attendance " +
                        "WHERE employee_id = ? AND attendance_date = CURRENT_DATE LIMIT 1";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(attSql)) {
            ps.setString(1, loggedIn.getEmployeeId());
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    empAttendance.put("clockIn", rs.getString("check_in_time"));
                    empAttendance.put("status", rs.getString("status"));
                }
            }
        } catch (Exception e) {
            System.err.println("Attendance query log: " + e.getMessage());
        }
        request.setAttribute("empAttendance", empAttendance);

        // 2. Fetch Employee's Complete Attendance History
        List<Attendance> attendanceHistory = attendanceDao.findByEmployeeId(loggedIn.getEmployeeId());
        request.setAttribute("attendanceHistory", attendanceHistory);

        // 3. Fetch Employee's Assigned Team and Members
        Team myTeam = teamDao.findTeamForEmployee(loggedIn.getEmployeeId());
        request.setAttribute("myTeam", myTeam);

        List<Employee> teamMembers = new ArrayList<>();
        if (myTeam != null) {
            teamMembers = teamDao.getTeamMembers(myTeam.getId());
        }
        request.setAttribute("teamMembers", teamMembers);

        // 4. Fetch Assigned Tasks (Synchronized with TaskDao.getTasksByEmployee)
        List<Task> myTasks = taskDao.getTasksByEmployee(loggedIn.getEmployeeId());
        request.setAttribute("myTasks", myTasks);

        request.getRequestDispatcher("/employeeWorkspace.jsp").forward(request, response);
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        
        HttpSession session = request.getSession(false);
        Employee loggedIn = (session != null) ? (Employee) session.getAttribute("loggedInEmployee") : null;

        if (loggedIn == null) {
            response.sendRedirect(request.getContextPath() + "/login.jsp");
            return;
        }

        String path = request.getServletPath();

        // Handle Task Submission / Progress Update from Employee
        if ("/employee/task/update".equals(path)) {
            try {
                String taskIdStr = request.getParameter("taskId");
                if (taskIdStr == null || taskIdStr.isBlank()) {
                    response.sendRedirect(request.getContextPath() + "/employee/workspace");
                    return;
                }
                int taskId = Integer.parseInt(taskIdStr);
                String comment = request.getParameter("comment");
                if (comment == null) comment = request.getParameter("note");
                String newStatus = request.getParameter("status");
                if (newStatus == null || newStatus.isBlank()) {
                    newStatus = "SUBMITTED_FOR_REVIEW";
                }

                // Handle Employee Submission Proof File Upload (<= 10MB)
                Part filePart = null;
                try {
                    filePart = request.getPart("submissionFile");
                    if (filePart == null) {
                        filePart = request.getPart("file");
                    }
                } catch (Exception ignored) {}

                String savedProofName = null;
                if (filePart != null && filePart.getSize() > 0) {
                    if (filePart.getSize() > 10 * 1024 * 1024) {
                        session.setAttribute("toastErr", "Uploaded proof document exceeds 10 MB limit.");
                        response.sendRedirect(request.getContextPath() + "/employee/workspace");
                        return;
                    }

                    String submittedName = Paths.get(filePart.getSubmittedFileName()).getFileName().toString();
                    String cleanName = submittedName.replaceAll("[^a-zA-Z0-9\\.\\-_]", "_");
                    savedProofName = System.currentTimeMillis() + "_" + cleanName;

                    String uploadPath = getServletContext().getRealPath("/uploads/submissions");
                    File uploadDir = new File(uploadPath);
                    if (!uploadDir.exists()) {
                        uploadDir.mkdirs();
                    }
                    filePart.write(uploadPath + File.separator + savedProofName);
                }

                // Update database through TaskDao
                taskDao.submitEmployeeTaskWithProof(taskId, loggedIn.getEmployeeId(), comment, savedProofName, newStatus);
                session.setAttribute("toastMsg", "Deliverable submitted for review successfully.");

            } catch (IllegalStateException e) {
                session.setAttribute("toastErr", "Uploaded file exceeds maximum allowable size.");
            } catch (Exception e) {
                System.err.println("Error updating employee task: " + e.getMessage());
                e.printStackTrace();
                session.setAttribute("toastErr", "Failed to update task: " + e.getMessage());
            }

            response.sendRedirect(request.getContextPath() + "/employee/workspace");
            return;
        }

        doGet(request, response);
    }
}