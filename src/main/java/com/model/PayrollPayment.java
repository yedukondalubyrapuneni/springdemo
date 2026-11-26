package com.model;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

public class PayrollPayment {
    private int id;
    private int payrollId;
    private LocalDate paymentDate;
    private String paymentMethod; // BANK_TRANSFER, CHEQUE, CASH
    private String referenceNumber;
    private BigDecimal amountPaid = BigDecimal.ZERO;
    private LocalDateTime createdAt;

    // Transient fields joined from employee & payroll for audit views
    private String employeeId;
    private String employeeName;
    private String payrollPeriod;

    public PayrollPayment() {}

    public PayrollPayment(int payrollId, LocalDate paymentDate, String paymentMethod, String referenceNumber, BigDecimal amountPaid) {
        this.payrollId = payrollId;
        this.paymentDate = paymentDate;
        this.paymentMethod = paymentMethod;
        this.referenceNumber = referenceNumber;
        this.amountPaid = amountPaid;
    }

    public int getId() { return id; }
    public void setId(int id) { this.id = id; }

    public int getPayrollId() { return payrollId; }
    public void setPayrollId(int payrollId) { this.payrollId = payrollId; }

    public LocalDate getPaymentDate() { return paymentDate; }
    public void setPaymentDate(LocalDate paymentDate) { this.paymentDate = paymentDate; }

    public String getPaymentMethod() { return paymentMethod; }
    public void setPaymentMethod(String paymentMethod) { this.paymentMethod = paymentMethod; }

    public String getReferenceNumber() { return referenceNumber; }
    public void setReferenceNumber(String referenceNumber) { this.referenceNumber = referenceNumber; }

    public BigDecimal getAmountPaid() { return amountPaid; }
    public void setAmountPaid(BigDecimal amountPaid) { this.amountPaid = amountPaid; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    // Audit display getters and setters
    public String getEmployeeId() { return employeeId; }
    public void setEmployeeId(String employeeId) { this.employeeId = employeeId; }

    public String getEmployeeName() { return employeeName; }
    public void setEmployeeName(String employeeName) { this.employeeName = employeeName; }

    public String getPayrollPeriod() { return payrollPeriod; }
    public void setPayrollPeriod(String payrollPeriod) { this.payrollPeriod = payrollPeriod; }
}