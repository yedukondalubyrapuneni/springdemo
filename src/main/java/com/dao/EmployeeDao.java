package com.dao;

import com.model.Employee;
import com.Util.DBConnection;
import com.Util.PasswordUtil;

import java.sql.*;
import java.util.ArrayList;
import java.util.List;

public class EmployeeDao {

    // 1. Authenticate using either Employee ID OR Email with Hashed Password
    public Employee authenticate(String identifier, String plainPassword) {
        if (identifier == null || plainPassword == null) {
            return null;
        }

        String hashedPassword = PasswordUtil.hashPassword(plainPassword.trim());
        String query = "SELECT * FROM employee WHERE (employee_id = ? OR email = ?) AND password = ?";
                       
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query)) {
            
            ps.setString(1, identifier.trim());
            ps.setString(2, identifier.trim());
            ps.setString(3, hashedPassword);

            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return mapRow(rs);
                }
            }
        } catch (SQLException e) {
            System.err.println("Authentication error: " + e.getMessage());
        }
        return null;
    }

    // 2. Automatically generate sequential Employee ID (EMP101, EMP102, ...)
    public synchronized String generateNextEmployeeId() {
        String query = "SELECT employee_id FROM employee WHERE employee_id LIKE 'EMP%' ORDER BY employee_id DESC";
        try (Connection conn = DBConnection.getConnection();
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(query)) {
            
            int maxId = 100;
            while (rs.next()) {
                String empId = rs.getString("employee_id");
                try {
                    int num = Integer.parseInt(empId.replaceAll("[^0-9]", ""));
                    if (num > maxId) {
                        maxId = num;
                    }
                } catch (NumberFormatException ignored) {}
            }
            return String.format("EMP%03d", maxId + 1);
        } catch (SQLException e) {
            System.err.println("Database error generating next Employee ID: " + e.getMessage());
        }
        return "EMP101";
    }

    // 3. Register / Save Employee
    public void save(Employee emp) {
        register(emp);
    }

    public void register(Employee emp) {
        String query = "INSERT INTO employee (employee_id, name, department, mobile, email, status, role, password) " +
                       "VALUES (?, ?, ?, ?, ?, ?, ?, ?)";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query)) {
            
            String hashedPassword = PasswordUtil.hashPassword(emp.getPassword().trim());

            ps.setString(1, emp.getEmployeeId().trim());
            ps.setString(2, emp.getName().trim());
            ps.setString(3, (emp.getDepartment() != null && !emp.getDepartment().isBlank()) ? emp.getDepartment().trim() : "General");
            ps.setString(4, (emp.getMobile() != null && !emp.getMobile().isBlank()) ? emp.getMobile().trim() : "");
            ps.setString(5, (emp.getEmail() != null && !emp.getEmail().isBlank()) ? emp.getEmail().trim() : "");
            ps.setString(6, (emp.getStatus() != null && !emp.getStatus().isBlank()) ? emp.getStatus().trim() : "ACTIVE");
            ps.setString(7, (emp.getRole() != null && !emp.getRole().isBlank()) ? emp.getRole().trim() : "EMPLOYEE");
            ps.setString(8, hashedPassword);

            ps.executeUpdate();
        } catch (SQLException e) {
            throw new RuntimeException("Failed to register employee: " + e.getMessage());
        }
    }

    // 4. Find all employees (Aliased as getAllEmployees for servlet compatibility)
    public List<Employee> getAllEmployees() {
        return findAll();
    }

    public List<Employee> findAll() {
        List<Employee> list = new ArrayList<>();
        String query = "SELECT * FROM employee ORDER BY employee_id ASC";
        try (Connection conn = DBConnection.getConnection();
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(query)) {
            while (rs.next()) {
                list.add(mapRow(rs));
            }
        } catch (SQLException e) {
            System.err.println("Database error in findAll: " + e.getMessage());
        }
        return list;
    }

 // 5. Find employee by ID / Code
    public Employee getEmployeeById(String employeeId) {
        return findById(employeeId);
    }

    public Employee findById(String employeeId) {
        if (employeeId == null || employeeId.trim().isEmpty()) {
            return null;
        }

        String query = "SELECT * FROM employee WHERE LOWER(TRIM(employee_id)) = LOWER(?)";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query)) {
            
            ps.setString(1, employeeId.trim());

            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return mapRow(rs);
                }
            }
        } catch (SQLException e) {
            System.err.println("Database error in findById: " + e.getMessage());
        }
        return null;
    }
 // Fetch all employees having a specific role (e.g., "MANAGER")
    public List<Employee> getEmployeesByRole(String role) {
        List<Employee> list = new ArrayList<>();
        String sql = "SELECT * FROM employees WHERE UPPER(role) = UPPER(?) ORDER BY name ASC";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            
            ps.setString(1, role != null ? role.trim() : "");
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Employee emp = new Employee();
                    emp.setId(rs.getInt("id"));
                    emp.setEmployeeId(rs.getString("employee_id"));
                    emp.setName(rs.getString("name"));
                    emp.setEmail(rs.getString("email"));
                    emp.setRole(rs.getString("role"));
                    try {
                        emp.setDepartment(rs.getString("department"));
                    } catch (Exception ignored) {}
                    list.add(emp);
                }
            }
        } catch (SQLException e) {
            System.err.println("Error fetching employees by role: " + e.getMessage());
            e.printStackTrace();
        }
        return list;
    }
    // 6. Find employee by ID OR Email
    public Employee findByIdOrEmail(String identifier) {
        if (identifier == null || identifier.trim().isEmpty()) {
            return null;
        }

        String query = "SELECT * FROM employee WHERE LOWER(TRIM(employee_id)) = LOWER(?) OR LOWER(TRIM(email)) = LOWER(?)";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query)) {
            
            ps.setString(1, identifier.trim());
            ps.setString(2, identifier.trim());

            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return mapRow(rs);
                }
            }
        } catch (SQLException e) {
            System.err.println("Database error in findByIdOrEmail: " + e.getMessage());
        }
        return null;
    }
    public String generateNextManagerId() {
        // Finds highest existing MGR number (e.g. MGR01 -> 1, MGR15 -> 15)
        String sql = "SELECT COALESCE(MAX(CAST(SUBSTRING(employee_id, 4) AS UNSIGNED)), 0) + 1 AS next_id " +
                     "FROM employee " +
                     "WHERE employee_id LIKE 'MGR%'";

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {

            if (rs.next()) {
                int nextVal = rs.getInt("next_id");
                // Formats to 2 digits: MGR01, MGR02... (or %03d for MGR001)
                return String.format("MGR%02d", nextVal);
            }
        } catch (SQLException e) {
            System.err.println("Error generating Manager ID: " + e.getMessage());
        }
        return "MGR01"; // Fallback default
    }
    // 7. Delete employee cleanly
    public void deleteEmployee(String employeeId) {
        String query = "DELETE FROM employee WHERE employee_id = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(query)) {
            ps.setString(1, employeeId);
            ps.executeUpdate();
        } catch (SQLException e) {
            throw new RuntimeException("Failed to delete employee: " + e.getMessage());
        }
    }

    // Safe Row Mapper
    private Employee mapRow(ResultSet rs) throws SQLException {
        Employee emp = new Employee();
        
        try {
            emp.setId(rs.getInt("id"));
        } catch (SQLException ignored) {
            // If the table doesn't have an "id" column, the parseNumericId fallback runs automatically
        }

        emp.setEmployeeId(rs.getString("employee_id"));
        emp.setName(rs.getString("name"));
        emp.setDepartment(rs.getString("department"));

        try { emp.setMobile(rs.getString("mobile")); } catch (SQLException ignored) {}
        try { emp.setEmail(rs.getString("email")); } catch (SQLException ignored) {}
        try { emp.setStatus(rs.getString("status")); } catch (SQLException ignored) {}
        try { emp.setRole(rs.getString("role")); } catch (SQLException ignored) {}

        return emp;
    }
}