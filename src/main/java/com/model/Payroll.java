package com.model;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public class Payroll {
    private int id;
    private String employeeId;
    private String employeeName;
    private String department;
    private int payrollMonth;
    private int payrollYear;
    private BigDecimal basicSalary = BigDecimal.ZERO;
    private BigDecimal grossSalary = BigDecimal.ZERO;
    private BigDecimal totalDeductions = BigDecimal.ZERO;
    private BigDecimal netSalary = BigDecimal.ZERO;
    private String status; // DRAFT, PROCESSED, PAID, CANCELLED
    private String processedBy;
    private LocalDateTime processedAt;
    private int workingDays;
    private int presentDays;
    private int unpaidLeaveDays;

    // --- Overtime (OT) Specific Fields ---
    private BigDecimal otHours = BigDecimal.ZERO;
    private BigDecimal otHourlyRate = BigDecimal.ZERO;
    private BigDecimal otAmount = BigDecimal.ZERO;

    public Payroll() {}

    public int getId() { return id; }
    public void setId(int id) { this.id = id; }

    public String getEmployeeId() { return employeeId; }
    public void setEmployeeId(String employeeId) { this.employeeId = employeeId; }

    public String getEmployeeName() { return employeeName; }
    public void setEmployeeName(String employeeName) { this.employeeName = employeeName; }

    public String getDepartment() { return department; }
    public void setDepartment(String department) { this.department = department; }

    public int getPayrollMonth() { return payrollMonth; }
    public void setPayrollMonth(int payrollMonth) { this.payrollMonth = payrollMonth; }

    public int getPayrollYear() { return payrollYear; }
    public void setPayrollYear(int payrollYear) { this.payrollYear = payrollYear; }

    public BigDecimal getBasicSalary() { return basicSalary; }
    public void setBasicSalary(BigDecimal basicSalary) { this.basicSalary = basicSalary; }

    public BigDecimal getGrossSalary() { return grossSalary; }
    public void setGrossSalary(BigDecimal grossSalary) { this.grossSalary = grossSalary; }

    public BigDecimal getTotalDeductions() { return totalDeductions; }
    public void setTotalDeductions(BigDecimal totalDeductions) { this.totalDeductions = totalDeductions; }

    public BigDecimal getNetSalary() { return netSalary; }
    public void setNetSalary(BigDecimal netSalary) { this.netSalary = netSalary; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public String getProcessedBy() { return processedBy; }
    public void setProcessedBy(String processedBy) { this.processedBy = processedBy; }

    public LocalDateTime getProcessedAt() { return processedAt; }
    public void setProcessedAt(LocalDateTime processedAt) { this.processedAt = processedAt; }

    public int getWorkingDays() { return workingDays; }
    public void setWorkingDays(int workingDays) { this.workingDays = workingDays; }

    public int getPresentDays() { return presentDays; }
    public void setPresentDays(int presentDays) { this.presentDays = presentDays; }

    public int getUnpaidLeaveDays() { return unpaidLeaveDays; }
    public void setUnpaidLeaveDays(int unpaidLeaveDays) { this.unpaidLeaveDays = unpaidLeaveDays; }

    // --- Overtime (OT) Getters and Setters ---
    public BigDecimal getOtHours() { 
        return otHours != null ? otHours : BigDecimal.ZERO; 
    }
    public void setOtHours(BigDecimal otHours) { 
        this.otHours = otHours; 
    }

    public BigDecimal getOtHourlyRate() { 
        return otHourlyRate != null ? otHourlyRate : BigDecimal.ZERO; 
    }
    public void setOtHourlyRate(BigDecimal otHourlyRate) { 
        this.otHourlyRate = otHourlyRate; 
    }

    public BigDecimal getOtAmount() { 
        return otAmount != null ? otAmount : BigDecimal.ZERO; 
    }
    public void setOtAmount(BigDecimal otAmount) { 
        this.otAmount = otAmount; 
    }
}