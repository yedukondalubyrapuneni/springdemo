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
import java.util.List;

@WebServlet("/attendance/daily")
public class DailyAttendanceServlet extends HttpServlet {

    private AttendanceService attendanceService;
    private AttendanceDao attendanceDao;

    @Override
    public void init() {
        attendanceDao = (AttendanceDao) getServletContext().getAttribute("attendanceDao");
        if (attendanceDao == null) {
            attendanceDao = new AttendanceDao();
        }

        attendanceService = (AttendanceService) getServletContext().getAttribute("attendanceService");
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
        Employee loggedIn = (session != null) ? (Employee) session.getAttribute("loggedInEmployee") : null;

        if (loggedIn == null || !loggedIn.isHrDesignation()) {
            response.sendRedirect(request.getContextPath() + "/login");
            return;
        }

        // Auto check-out unclosed shifts before retrieving daily records
        attendanceDao.autoCheckOutUnclosedShifts();

        String dateParam = request.getParameter("date");
        LocalDate targetDate = (dateParam != null && !dateParam.isBlank())
                ? LocalDate.parse(dateParam)
                : LocalDate.now();

        // Optional filter by employee ID if supplied
        String searchEmpId = request.getParameter("employeeId");
        if (searchEmpId == null) {
            searchEmpId = request.getParameter("empId");
        }

        List<Attendance> records;
        if (searchEmpId != null && !searchEmpId.trim().isEmpty()) {
            searchEmpId = searchEmpId.trim().toUpperCase();
            Attendance rec = attendanceDao.findRecord(searchEmpId, targetDate);
            records = (rec != null) ? List.of(rec) : List.of();
            request.setAttribute("searchEmpId", searchEmpId);
        } else {
            records = attendanceService.getDailyAttendance(targetDate);
        }

        request.setAttribute("selectedDate", targetDate.toString());
        request.setAttribute("records", records);
        request.getRequestDispatcher("/daily-attendance.jsp").forward(request, response);
    }
}