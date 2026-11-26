package com.servlet;

import com.dao.AttendanceDao;
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
import java.time.format.DateTimeFormatter;
import java.util.List;

@WebServlet("/attendance/dashboard")
public class AttendanceDashboardServlet extends HttpServlet {

    private EmployeeService employeeService;
    private AttendanceService attendanceService;
    private AttendanceDao attendanceDao;

    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter.ofPattern("dd-MM-yyyy");

    @Override
    public void init() {
        employeeService = (EmployeeService) getServletContext().getAttribute("employeeService");
        attendanceService = (AttendanceService) getServletContext().getAttribute("attendanceService");
        attendanceDao = (AttendanceDao) getServletContext().getAttribute("attendanceDao");

        if (employeeService == null) employeeService = new EmployeeService();
        if (attendanceDao == null) attendanceDao = new AttendanceDao();
        if (attendanceService == null) attendanceService = new AttendanceService(attendanceDao, employeeService);
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

        if (!loggedInUser.isHrDesignation()) {
            response.sendRedirect(request.getContextPath() + "/attendance/action");
            return;
        }

       
        attendanceDao.autoCheckOutUnclosedShifts();
        attendanceDao.resolvePastPendingRecords();

        LocalDate today = LocalDate.now();

      
        List<Attendance> records = attendanceService.getDailyAttendance(today);

        long present = records.stream().filter(a -> "PRESENT".equalsIgnoreCase(a.getStatus())).count();
        long pending = records.stream().filter(a -> "PENDING".equalsIgnoreCase(a.getStatus())).count();
        long halfDay = records.stream().filter(a -> "HALF_DAY".equalsIgnoreCase(a.getStatus())).count();
        long absent = records.stream().filter(a -> "ABSENT".equalsIgnoreCase(a.getStatus())).count();
        long leave = records.stream().filter(a -> "LEAVE".equalsIgnoreCase(a.getStatus())).count();

       
        List<Employee> allEmployees = employeeService.getAllEmployees();
        long operationalEmployeeCount = 0;
        if (allEmployees != null) {
            operationalEmployeeCount = allEmployees.stream().filter(e -> !e.isHrDesignation()).count();
        }

        
        List<Attendance> pendingLeaves = attendanceDao.findPendingLeaveRequests();

        request.setAttribute("todayDate", today.format(DATE_FMT));
        request.setAttribute("employees", allEmployees);
        request.setAttribute("totalEmployees", operationalEmployeeCount);
        request.setAttribute("presentCount", present);
        request.setAttribute("pendingCount", pending);
        request.setAttribute("halfDayCount", halfDay);
        request.setAttribute("absentCount", absent);
        request.setAttribute("onLeaveCount", leave);
        request.setAttribute("pendingLeaves", pendingLeaves);

        request.getRequestDispatcher("/dashboard.jsp").forward(request, response);
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        Employee loggedInUser = (session != null) ? (Employee) session.getAttribute("loggedInEmployee") : null;

        if (loggedInUser == null || !loggedInUser.isHrDesignation()) {
            response.sendRedirect(request.getContextPath() + "/attendance/action");
            return;
        }

        String attendanceId = request.getParameter("attendanceId");
        String decision = request.getParameter("decision"); // "APPROVED" or "REJECTED"
        String rejectionReason = request.getParameter("rejectionReason");

        if (attendanceId != null && decision != null) {
            if ("REJECTED".equalsIgnoreCase(decision)) {
                if (rejectionReason == null || rejectionReason.isBlank()) {
                    rejectionReason = "Application rejected by HR";
                }
                attendanceDao.updateLeaveStatusWithRemarks(attendanceId.trim(), "REJECTED", rejectionReason.trim());
            } else if ("APPROVED".equalsIgnoreCase(decision)) {
                attendanceDao.updateLeaveStatusWithRemarks(attendanceId.trim(), "APPROVED", null);
            }
        }

        response.sendRedirect(request.getContextPath() + "/attendance/dashboard");
    }
}