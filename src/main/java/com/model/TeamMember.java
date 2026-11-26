package com.model;

import java.time.LocalDate;

public class TeamMember {
    private int id;
    private int teamId;
    private int employeeId;
    private String empCode;      // e.g. EMP101
    private String employeeName;  // e.g. Abhishek
    private String role;          // e.g. Java Developer / EMPLOYEE
    private String department;
    private LocalDate joinedDate;
    private String status;

    public TeamMember() {}

    public int getId() { return id; }
    public void setId(int id) { this.id = id; }

    public int getTeamId() { return teamId; }
    public void setTeamId(int teamId) { this.teamId = teamId; }

    public int getEmployeeId() { return employeeId; }
    public void setEmployeeId(int employeeId) { this.employeeId = employeeId; }

    public String getEmpCode() { return empCode; }
    public void setEmpCode(String empCode) { this.empCode = empCode; }

    public String getEmployeeName() { return employeeName; }
    public void setEmployeeName(String employeeName) { this.employeeName = employeeName; }

    public String getRole() { return role; }
    public void setRole(String role) { this.role = role; }

    public String getDepartment() { return department; }
    public void setDepartment(String department) { this.department = department; }

    public LocalDate getJoinedDate() { return joinedDate; }
    public void setJoinedDate(LocalDate joinedDate) { this.joinedDate = joinedDate; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
}