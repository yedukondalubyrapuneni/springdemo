package com.model;

public class TeamMemberStatus {
    private String employeeId;
    private String name;
    private String role;
    private String department;
    private String todayStatus;   // PRESENT, ABSENT, HALF_DAY, LEAVE, NOT_CHECKED_IN
    private String checkInTime;

    public String getEmployeeId() { return employeeId; }
    public void setEmployeeId(String employeeId) { this.employeeId = employeeId; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getRole() { return role; }
    public void setRole(String role) { this.role = role; }

    public String getDepartment() { return department; }
    public void setDepartment(String department) { this.department = department; }

    public String getTodayStatus() { return todayStatus != null ? todayStatus : "NOT_CHECKED_IN"; }
    public void setTodayStatus(String todayStatus) { this.todayStatus = todayStatus; }

    public String getCheckInTime() { return checkInTime != null ? checkInTime : "--"; }
    public void setCheckInTime(String checkInTime) { this.checkInTime = checkInTime; }
}