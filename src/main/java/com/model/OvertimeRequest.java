package com.model;

import java.sql.Date;
import java.sql.Timestamp;

public class OvertimeRequest {
    private int id;
    private String employeeId;
    private Date requestDate;
    private double requestedHours;
    private String reason;
    private String status;
    private String approvedBy;
    private Timestamp actionTimestamp;

    public OvertimeRequest() {}

    public int getId() { return id; }
    public void setId(int id) { this.id = id; }

    public String getEmployeeId() { return employeeId; }
    public void setEmployeeId(String employeeId) { this.employeeId = employeeId; }

    public Date getRequestDate() { return requestDate; }
    public void setRequestDate(Date requestDate) { this.requestDate = requestDate; }

    public double getRequestedHours() { return requestedHours; }
    public void setRequestedHours(double requestedHours) { this.requestedHours = requestedHours; }

    public String getReason() { return reason; }
    public void setReason(String reason) { this.reason = reason; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public String getApprovedBy() { return approvedBy; }
    public void setApprovedBy(String approvedBy) { this.approvedBy = approvedBy; }

    public Timestamp getActionTimestamp() { return actionTimestamp; }
    public void setActionTimestamp(Timestamp actionTimestamp) { this.actionTimestamp = actionTimestamp; }
}