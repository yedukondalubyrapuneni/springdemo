package com.model;

public class Employee {

    private int id;
    private String employeeId;
    private String name;
    private String department;
    private String designation;
    private String mobile;
    private String email;
    private String status;
    private String role;
    private String password;

    public Employee() {}

    // Overloaded 8-parameter constructor to prevent legacy servlet compile errors
    public Employee(String employeeId, String name, String department, String mobile, 
                    String email, String status, String role, String password) {
        this(employeeId, name, department, "Associate Software Engineer", mobile, email, status, role, password);
    }

    // 9-parameter constructor with designation support
    public Employee(String employeeId, String name, String department, String designation, 
                    String mobile, String email, String status, String role, String password) {
        this.employeeId = employeeId;
        this.name = name;
        this.department = department;
        this.designation = designation;
        this.mobile = mobile;
        this.email = email;
        this.status = status;
        this.role = role;
        this.password = password;
        this.id = parseNumericId(employeeId);
    }

    public Employee(int id, String employeeId, String name, String department, String designation, 
                    String mobile, String email, String status, String role, String password) {
        this.id = id;
        this.employeeId = employeeId;
        this.name = name;
        this.department = department;
        this.designation = designation;
        this.mobile = mobile;
        this.email = email;
        this.status = status;
        this.role = role;
        this.password = password;
    }

    private int parseNumericId(String empCode) {
        if (empCode == null) return 0;
        try {
            return Integer.parseInt(empCode.replaceAll("[^0-9]", ""));
        } catch (Exception e) {
            return 0;
        }
    }

    public int getId() {
        if (id == 0 && employeeId != null) {
            id = parseNumericId(employeeId);
        }
        return id;
    }

    public void setId(int id) {
        this.id = id;
    }

    public String getEmployeeId() {
        return employeeId;
    }

    public void setEmployeeId(String employeeId) {
        this.employeeId = employeeId;
        if (this.id == 0) {
            this.id = parseNumericId(employeeId);
        }
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getDepartment() {
        return department;
    }

    public void setDepartment(String department) {
        this.department = department;
    }

    public String getDesignation() {
        return designation;
    }

    public void setDesignation(String designation) {
        this.designation = designation;
    }

    public String getMobile() {
        return mobile;
    }

    public void setMobile(String mobile) {
        this.mobile = mobile;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public String getRole() {
        return role;
    }

    public void setRole(String role) {
        this.role = role;
    }

    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
    }

    public boolean isHrDesignation() {
        return "HR".equalsIgnoreCase(role) 
            || "ADMIN".equalsIgnoreCase(role)
            || (designation != null && designation.toUpperCase().contains("HR"));
    }
}