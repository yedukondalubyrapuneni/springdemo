package com.model;

import java.math.BigDecimal;

public class FinanceMISReport {
    private int payrollMonth;
    private int payrollYear;
    private int totalEmployeesProcessed;
    private int totalDisbursedCount;
    private int pendingDisbursements;
    
    // Financial Aggregations
    private BigDecimal totalGrossPayout = BigDecimal.ZERO;
    private BigDecimal totalNetDisbursed = BigDecimal.ZERO;
    private BigDecimal totalPfContribution = BigDecimal.ZERO;
    private BigDecimal totalPtDeduction = BigDecimal.ZERO;
    private BigDecimal totalLopDeductions = BigDecimal.ZERO;
    private BigDecimal totalEstimatedCtc = BigDecimal.ZERO;

    public FinanceMISReport() {}

    public int getPayrollMonth() { return payrollMonth; }
    public void setPayrollMonth(int payrollMonth) { this.payrollMonth = payrollMonth; }

    public int getPayrollYear() { return payrollYear; }
    public void setPayrollYear(int payrollYear) { this.payrollYear = payrollYear; }

    public int getTotalEmployeesProcessed() { return totalEmployeesProcessed; }
    public void setTotalEmployeesProcessed(int totalEmployeesProcessed) { this.totalEmployeesProcessed = totalEmployeesProcessed; }

    public int getTotalDisbursedCount() { return totalDisbursedCount; }
    public void setTotalDisbursedCount(int totalDisbursedCount) { this.totalDisbursedCount = totalDisbursedCount; }

    public int getPendingDisbursements() { return pendingDisbursements; }
    public void setPendingDisbursements(int pendingDisbursements) { this.pendingDisbursements = pendingDisbursements; }

    public BigDecimal getTotalGrossPayout() { return totalGrossPayout; }
    public void setTotalGrossPayout(BigDecimal totalGrossPayout) { this.totalGrossPayout = totalGrossPayout; }

    public BigDecimal getTotalNetDisbursed() { return totalNetDisbursed; }
    public void setTotalNetDisbursed(BigDecimal totalNetDisbursed) { this.totalNetDisbursed = totalNetDisbursed; }

    public BigDecimal getTotalPfContribution() { return totalPfContribution; }
    public void setTotalPfContribution(BigDecimal totalPfContribution) { this.totalPfContribution = totalPfContribution; }

    public BigDecimal getTotalPtDeduction() { return totalPtDeduction; }
    public void setTotalPtDeduction(BigDecimal totalPtDeduction) { this.totalPtDeduction = totalPtDeduction; }

    public BigDecimal getTotalLopDeductions() { return totalLopDeductions; }
    public void setTotalLopDeductions(BigDecimal totalLopDeductions) { this.totalLopDeductions = totalLopDeductions; }

    public BigDecimal getTotalEstimatedCtc() { return totalEstimatedCtc; }
    public void setTotalEstimatedCtc(BigDecimal totalEstimatedCtc) { this.totalEstimatedCtc = totalEstimatedCtc; }
}