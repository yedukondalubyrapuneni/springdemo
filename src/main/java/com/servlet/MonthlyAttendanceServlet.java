package com.servlet;

import com.dao.AttendanceDao;
import com.dao.EmployeeDao;
import com.model.Employee;
import com.service.AttendanceService;
import com.service.AttendanceService.MonthlySummary;
import com.service.EmployeeService;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.YearMonth;

@WebServlet("/attendance/monthly")
public class MonthlyAttendanceServlet extends HttpServlet {

    private AttendanceService attendanceService;
    private AttendanceDao attendanceDao;
    private EmployeeDao employeeDao;

    @Override
    public void init() {
        attendanceDao = (AttendanceDao) getServletContext().getAttribute("attendanceDao");
        if (attendanceDao == null) {
            attendanceDao = new AttendanceDao();
        }

        employeeDao = (EmployeeDao) getServletContext().getAttribute("employeeDao");
        if (employeeDao == null) {
            employeeDao = new EmployeeDao();
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

        // Support both "employeeId" and "empId" parameter inputs
        String employeeId = request.getParameter("employeeId");
        if (employeeId == null || employeeId.isBlank()) {
            employeeId = request.getParameter("empId");
        }

        String monthParam = request.getParameter("month"); // Expected format: "YYYY-MM"

        YearMonth yearMonth;
        if (monthParam != null && !monthParam.isBlank()) {
            yearMonth = YearMonth.parse(monthParam);
        } else {
            yearMonth = YearMonth.now();
            monthParam = yearMonth.toString();
        }

        request.setAttribute("queriedMonth", monthParam);

        if (employeeId != null && !employeeId.trim().isEmpty()) {
            employeeId = employeeId.trim().toUpperCase();
            request.setAttribute("queriedEmpId", employeeId);

            // Verify employee existence
            Employee emp = employeeDao.findByIdOrEmail(employeeId);
            if (emp != null) {
                // Calculate working days in the month (Monday to Friday)
                int workingDays = calculateWorkingDays(yearMonth);

                MonthlySummary summary = attendanceService.getMonthlySummary(employeeId, yearMonth, workingDays);
                request.setAttribute("monthlySummary", summary);
                request.setAttribute("targetEmployee", emp);
            } else {
                request.setAttribute("error", "No employee found with ID: " + employeeId);
            }
        }

        request.getRequestDispatcher("/monthly-attendance.jsp").forward(request, response);
    }

    private int calculateWorkingDays(YearMonth ym) {
        int count = 0;
        int daysInMonth = ym.lengthOfMonth();
        for (int day = 1; day <= daysInMonth; day++) {
            LocalDate date = ym.atDay(day);
            DayOfWeek dow = date.getDayOfWeek();
            if (dow != DayOfWeek.SATURDAY && dow != DayOfWeek.SUNDAY) {
                count++;
            }
        }
        return count > 0 ? count : 22; // default fallback
    }
}