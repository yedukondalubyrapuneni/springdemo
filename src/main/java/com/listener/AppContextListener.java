package com.listener;

import com.dao.AttendanceDao;
import com.dao.EmployeeDao;
import com.service.AttendanceService;
import com.service.EmployeeService;

import jakarta.servlet.ServletContext;
import jakarta.servlet.ServletContextEvent;
import jakarta.servlet.ServletContextListener;
import jakarta.servlet.annotation.WebListener;

@WebListener
public class AppContextListener implements ServletContextListener {

    @Override
    public void contextInitialized(ServletContextEvent event) {

        ServletContext context = event.getServletContext();

        // 1. Initialize DAOs
        EmployeeDao employeeDao = new EmployeeDao();
        AttendanceDao attendanceDao = new AttendanceDao();

        // 2. Initialize Services with their dependencies
        EmployeeService employeeService = new EmployeeService(employeeDao);
        AttendanceService attendanceService = new AttendanceService(employeeService);

        // 3. Bind to Application Scope
        context.setAttribute("employeeService", employeeService);
        context.setAttribute("attendanceService", attendanceService);
    }

    @Override
    public void contextDestroyed(ServletContextEvent event) {
        // Nothing to clean up
    }
}