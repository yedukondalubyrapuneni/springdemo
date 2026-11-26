package com.servlet;


import com.model.Attendance;
import com.model.Employee;
import com.service.AttendanceService;
import com.service.EmployeeService;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.util.List;

@WebServlet("/attendance/history")
public class AttendanceHistoryServlet extends HttpServlet {

    private AttendanceService attendanceService;
    private EmployeeService employeeService;

    @Override
    public void init() {

        attendanceService =
                (AttendanceService)
                        getServletContext()
                                .getAttribute("attendanceService");

        employeeService =
                (EmployeeService)
                        getServletContext()
                                .getAttribute("employeeService");
    }

    @Override
    protected void doGet(
            HttpServletRequest req,
            HttpServletResponse resp)
            throws ServletException, IOException {

        String empId =
                req.getParameter("employeeId");

        if (empId != null && !empId.isBlank()) {
        	// CORRECT:
        	Employee emp = employeeService.getEmployeeById(empId.trim());

            if (emp != null) {

                List<Attendance> history =
                        attendanceService
                                .getEmployeeAttendance(
                                        empId.trim()
                                );

                long present =
                        history.stream()
                                .filter(a ->
                                        "PRESENT".equalsIgnoreCase(
                                                a.getStatus()))
                                .count();

                long absent =
                        history.stream()
                                .filter(a ->
                                        "ABSENT".equalsIgnoreCase(
                                                a.getStatus()))
                                .count();

                long leave =
                        history.stream()
                                .filter(a ->
                                        "LEAVE".equalsIgnoreCase(
                                                a.getStatus()))
                                .count();

                req.setAttribute(
                        "employee",
                        emp
                );

                req.setAttribute(
                        "history",
                        history
                );

                req.setAttribute(
                        "presentCount",
                        present
                );

                req.setAttribute(
                        "absentCount",
                        absent
                );

                req.setAttribute(
                        "leaveCount",
                        leave
                );

            } else {

                req.setAttribute(
                        "error",
                        "Employee not found with ID: "
                                + empId
                );
            }
        }

        req.getRequestDispatcher(
                "/history.jsp"
        ).forward(req, resp);
    }
}
