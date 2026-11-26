package com.servlet;

import com.dao.AttendanceDao;
import com.dao.EmployeeDao;
import com.model.Attendance;
import com.model.Employee;
import com.service.AttendanceService;
import com.service.EmployeeService;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.List;

@WebServlet("/attendance/action")
public class AttendanceActionServlet extends HttpServlet {

    private AttendanceService attendanceService;
    private AttendanceDao attendanceDao;
    private EmployeeDao employeeDao;

    private static final DateTimeFormatter TIME_FMT = DateTimeFormatter.ofPattern("hh:mm a");
    private static final int MAX_BREAK_LIMIT_MINUTES = 15;

    @Override
    public void init() {
        attendanceService = (AttendanceService) getServletContext().getAttribute("attendanceService");
        attendanceDao = (AttendanceDao) getServletContext().getAttribute("attendanceDao");
        employeeDao = new EmployeeDao();
        
        if (attendanceDao == null) {
            attendanceDao = new AttendanceDao();
        }
        if (attendanceService == null) {
            EmployeeService empService = (EmployeeService) getServletContext().getAttribute("employeeService");
            if (empService == null) {
                empService = new EmployeeService();
            }
            attendanceService = new AttendanceService(attendanceDao, empService);
        }
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

        // Routing redirect based on role
        if ("MANAGER".equalsIgnoreCase(loggedInUser.getRole())) {
            response.sendRedirect(request.getContextPath() + "/manager/dashboard");
        } else {
            response.sendRedirect(request.getContextPath() + "/employee/workspace");
        }
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

        String employeeId = loggedInUser.getEmployeeId();
        String action = request.getParameter("action");
        String redirectTarget = request.getParameter("redirect");
        LocalTime now = LocalTime.now();

        try {
            if ("CHECK_IN".equalsIgnoreCase(action)) {
                Attendance attendance = attendanceService.checkIn(employeeId, now);
                session.setAttribute("toastMsg", "Check-in registered at " + now.format(TIME_FMT) + "! Status is PENDING until shift completion.");

            } else if ("START_BREAK".equalsIgnoreCase(action) || "START_BREAK_1".equalsIgnoreCase(action)) {
                Attendance attendance = attendanceService.startSmartBreak(employeeId, now);
                String breakNumber = (attendance.getBreak2StartTime() != null && attendance.getBreak2EndTime() == null) ? "Break 2" : "Break 1";
                session.setAttribute("toastMsg", breakNumber + " started at " + now.format(TIME_FMT) + ". (Allowed duration: 15 mins)");

            } else if ("END_BREAK".equalsIgnoreCase(action) || "END_BREAK_1".equalsIgnoreCase(action) || "END_BREAK_2".equalsIgnoreCase(action)) {
                Attendance attendance = attendanceService.endSmartBreak(employeeId, now);

                long duration = (attendance.getBreak2EndTime() != null && attendance.getBreak2EndTime().equals(now))
                                ? attendance.getBreak2DurationMinutes()
                                : attendance.getBreak1DurationMinutes();

                if (duration > MAX_BREAK_LIMIT_MINUTES) {
                    long exceeded = duration - MAX_BREAK_LIMIT_MINUTES;
                    session.setAttribute("toastWarn", "ALERT: Break exceeded limit! You took " + duration 
                            + " minutes (Exceeded by " + exceeded + " mins). Maximum allowed is 15 minutes.");
                } else {
                    session.setAttribute("toastMsg", "Break ended at " + now.format(TIME_FMT) + ". Duration: " + duration + " mins.");
                }

            } else if ("CHECK_OUT".equalsIgnoreCase(action)) {
                Attendance attendance = attendanceService.checkOut(employeeId, now);
                String netHoursFormatted = attendanceService.formatNetWorkingHours(attendance.getNetWorkingMinutes());
                session.setAttribute("toastMsg", "Check-out recorded at " + now.format(TIME_FMT) 
                        + "! Net Working Time: " + netHoursFormatted + " (Shift Status: " + attendance.getStatus() + ")");

            } else if ("APPLY_LEAVE".equalsIgnoreCase(action)) {
                String reason = request.getParameter("reason");
                String dateStr = request.getParameter("effectiveDate");
                if (dateStr == null || dateStr.isBlank()) {
                    dateStr = request.getParameter("leaveDate");
                }
                LocalDate leaveDate = (dateStr != null && !dateStr.isBlank()) 
                                      ? LocalDate.parse(dateStr) 
                                      : LocalDate.now();

                if (reason == null || reason.trim().isEmpty()) {
                    throw new IllegalArgumentException("Reason is required when applying for leave.");
                }

                attendanceDao.recordLeave(employeeId, leaveDate, reason.trim());
                session.setAttribute("toastMsg", "Leave application submitted for " + leaveDate + ". Pending HR approval.");
            }
        } catch (Exception e) {
            session.setAttribute("toastErr", e.getMessage());
        }

        // Return to whichever dashboard made the call
        if ("manager".equalsIgnoreCase(redirectTarget)) {
            response.sendRedirect(request.getContextPath() + "/manager/dashboard");
        } else {
            response.sendRedirect(request.getContextPath() + "/employee/workspace");
        }
    }
}