package com.model;

import java.io.Serializable;
import java.time.LocalDate;

public class ReportItem implements Serializable {
    private static final long serialVersionUID = 1L;

    private String id;
    private String title;
    private String employeeId;
    private String employeeName;
    private String department;
    private String role;
    private String status;
    private LocalDate recordDate;
    private LocalDate startDate;
    private LocalDate endDate;
    private String details;
    private String extra;

    public ReportItem() {}

    public String getId() { return id; }
    public void setId(String id) { this.id = id; }
    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }
    public String getEmployeeId() { return employeeId; }
    public void setEmployeeId(String employeeId) { this.employeeId = employeeId; }
    public String getEmployeeName() { return employeeName; }
    public void setEmployeeName(String employeeName) { this.employeeName = employeeName; }
    public String getDepartment() { return department; }
    public void setDepartment(String department) { this.department = department; }
    public String getRole() { return role; }
    public void setRole(String role) { this.role = role; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public LocalDate getRecordDate() { return recordDate; }
    public void setRecordDate(LocalDate recordDate) { this.recordDate = recordDate; }
    public LocalDate getStartDate() { return startDate; }
    public void setStartDate(LocalDate startDate) { this.startDate = startDate; }
    public LocalDate getEndDate() { return endDate; }
    public void setEndDate(LocalDate endDate) { this.endDate = endDate; }
    public String getDetails() { return details; }
    public void setDetails(String details) { this.details = details; }
    public String getExtra() { return extra; }
    public void setExtra(String extra) { this.extra = extra; }
}