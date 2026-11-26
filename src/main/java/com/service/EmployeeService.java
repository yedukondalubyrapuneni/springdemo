package com.service;

import com.dao.EmployeeDao;
import com.model.Employee;
import java.util.List;

public class EmployeeService {

    private EmployeeDao employeeDao;

    
    public EmployeeService(EmployeeDao employeeDao) {
        this.employeeDao = employeeDao;
    }

    
    public EmployeeService() {
        this.employeeDao = new EmployeeDao();
    }

    public List<Employee> getAllEmployees() {
        return employeeDao.findAll();
    }

    public Employee getEmployeeById(String employeeId) {
        return employeeDao.findById(employeeId);
    }
    public Employee login(String employeeId, String password) {
        if (employeeId == null || employeeId.isBlank()) {
            throw new IllegalArgumentException("Employee ID is required.");
        }
        if (password == null || password.isBlank()) {
            throw new IllegalArgumentException("Password is required.");
        }

        Employee emp = employeeDao.authenticate(employeeId.trim(), password.trim());

        if (emp == null) {
            throw new IllegalArgumentException("Invalid Employee ID or password.");
        }

        if (!"ACTIVE".equalsIgnoreCase(emp.getStatus())) {
            throw new IllegalStateException("Your account is not active. Please contact HR or Admin.");
        }

        return emp;
    }
    public void addEmployee(Employee emp) {
        if (emp == null || emp.getEmployeeId() == null || emp.getEmployeeId().isBlank()) {
            throw new IllegalArgumentException("Employee ID is required.");
        }
        if (emp.getName() == null || emp.getName().isBlank()) {
            throw new IllegalArgumentException("Employee Name is required.");
        }
        if (emp.getDepartment() == null || emp.getDepartment().isBlank()) {
            throw new IllegalArgumentException("Department is required.");
        }
        employeeDao.save(emp);
    }
}