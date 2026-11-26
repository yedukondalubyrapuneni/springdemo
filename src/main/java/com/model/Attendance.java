package com.model;

import java.sql.Date;
import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;

public class Attendance {
    private String attendanceId;
    private String employeeId;
    private String employeeName; // Added field for joining with employee table
    private LocalDate attendanceDate;
    private LocalTime checkInTime;
    
    private LocalTime break1StartTime;
    private LocalTime break1EndTime;
    
    private LocalTime break2StartTime;
    private LocalTime break2EndTime;
    private double approvedOtHours;
    private LocalTime checkOutTime;
    private String status;
    private int netWorkingMinutes;
    private String reason;
    private String leaveStatus = "NONE"; 
    private String rejectionReason;

    public static final DateTimeFormatter DATE_FORMATTER = DateTimeFormatter.ofPattern("dd-MM-yyyy");
    private static final DateTimeFormatter TIME_FMT = DateTimeFormatter.ofPattern("hh:mm a");

    public Attendance() {}

    public Attendance(String attendanceId, String employeeId, LocalDate attendanceDate, LocalTime checkInTime, String status) {
        this.attendanceId = attendanceId;
        this.employeeId = employeeId;
        this.attendanceDate = attendanceDate;
        this.checkInTime = checkInTime;
        this.status = status;
    }

    public String getAttendanceId() { return attendanceId; }
    public void setAttendanceId(String attendanceId) { this.attendanceId = attendanceId; }

    public String getEmployeeId() { return employeeId; }
    public void setEmployeeId(String employeeId) { this.employeeId = employeeId; }

    // --- Employee Name Getter & Setter ---
    public String getEmployeeName() { return employeeName; }
    public void setEmployeeName(String employeeName) { this.employeeName = employeeName; }

    // --- Attendance Date Getters & Setters ---
    public LocalDate getAttendanceDate() { return attendanceDate; }
    
    // Accepts java.time.LocalDate
    public void setAttendanceDate(LocalDate attendanceDate) { 
        this.attendanceDate = attendanceDate; 
    }

    // Overload: Accepts java.sql.Date directly from JDBC ResultSet (rs.getDate)
    public void setAttendanceDate(Date sqlDate) {
        if (sqlDate != null) {
            this.attendanceDate = sqlDate.toLocalDate();
        } else {
            this.attendanceDate = null;
        }
    }

    public LocalTime getCheckInTime() { return checkInTime; }
    public void setCheckInTime(LocalTime checkInTime) { this.checkInTime = checkInTime; }

    public LocalTime getBreak1StartTime() { return break1StartTime; }
    public void setBreak1StartTime(LocalTime break1StartTime) { this.break1StartTime = break1StartTime; }

    public LocalTime getBreak1EndTime() { return break1EndTime; }
    public void setBreak1EndTime(LocalTime break1EndTime) { this.break1EndTime = break1EndTime; }

    public LocalTime getBreak2StartTime() { return break2StartTime; }
    public void setBreak2StartTime(LocalTime break2StartTime) { this.break2StartTime = break2StartTime; }

    public LocalTime getBreak2EndTime() { return break2EndTime; }
    public void setBreak2EndTime(LocalTime break2EndTime) { this.break2EndTime = break2EndTime; }

    public LocalTime getCheckOutTime() { return checkOutTime; }
    public void setCheckOutTime(LocalTime checkOutTime) { this.checkOutTime = checkOutTime; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public int getNetWorkingMinutes() { return netWorkingMinutes; }
    public void setNetWorkingMinutes(int netWorkingMinutes) { this.netWorkingMinutes = netWorkingMinutes; }

    public String getReason() { return reason; }
    public void setReason(String reason) { this.reason = reason; }

    public String getLeaveStatus() { return leaveStatus; }
    public void setLeaveStatus(String leaveStatus) { 
        this.leaveStatus = (leaveStatus != null) ? leaveStatus : "NONE"; 
    }
    public double getApprovedOtHours() {
        return approvedOtHours;
    }

    public void setApprovedOtHours(double approvedOtHours) {
        this.approvedOtHours = approvedOtHours;
    }
    public String getRejectionReason() { return rejectionReason; }
    public void setRejectionReason(String rejectionReason) { this.rejectionReason = rejectionReason; }

    // Duration calculation helpers (in minutes)
    public long getBreak1DurationMinutes() {
        if (break1StartTime != null && break1EndTime != null) {
            return Duration.between(break1StartTime, break1EndTime).toMinutes();
        }
        return 0;
    }

    public long getBreak2DurationMinutes() {
        if (break2StartTime != null && break2EndTime != null) {
            return Duration.between(break2StartTime, break2EndTime).toMinutes();
        }
        return 0;
    }

    // Formatted display helpers for JSP rendering
    public String getFormattedDate() {
        return (attendanceDate != null) ? attendanceDate.format(DATE_FORMATTER) : "--";
    }

    public String getFormattedCheckInTime() {
        return (checkInTime != null) ? checkInTime.format(TIME_FMT) : "--";
    }

    public String getFormattedBreak1Start() {
        return (break1StartTime != null) ? break1StartTime.format(TIME_FMT) : "--";
    }

    public String getFormattedBreak1End() {
        return (break1EndTime != null) ? break1EndTime.format(TIME_FMT) : "--";
    }

    public String getFormattedBreak2Start() {
        return (break2StartTime != null) ? break2StartTime.format(TIME_FMT) : "--";
    }

    public String getFormattedBreak2End() {
        return (break2EndTime != null) ? break2EndTime.format(TIME_FMT) : "--";
    }

    public String getFormattedCheckOutTime() {
        return (checkOutTime != null) ? checkOutTime.format(TIME_FMT) : "--";
    }

    public String getFormattedNetWorkingHours() {
        if (netWorkingMinutes <= 0) return "--";
        int hours = netWorkingMinutes / 60;
        int mins = netWorkingMinutes % 60;
        return hours + "h " + mins + "m";
    }
}