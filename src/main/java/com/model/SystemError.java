package com.model;

import java.sql.Timestamp;

public class SystemError {
    private Long id;
    private String moduleName;
    private String errorType;
    private String errorMessage;
    private String severity;
    private Integer userId;
    private Timestamp createdAt;

    public SystemError() {}

    public SystemError(String moduleName, String errorType, String errorMessage, String severity, Integer userId) {
        this.moduleName = moduleName;
        this.errorType = errorType;
        this.errorMessage = errorMessage;
        this.severity = severity;
        this.userId = userId;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getModuleName() { return moduleName; }
    public void setModuleName(String moduleName) { this.moduleName = moduleName; }

    public String getErrorType() { return errorType; }
    public void setErrorType(String errorType) { this.errorType = errorType; }

    public String getErrorMessage() { return errorMessage; }
    public void setErrorMessage(String errorMessage) { this.errorMessage = errorMessage; }

    public String getSeverity() { return severity; }
    public void setSeverity(String severity) { this.severity = severity; }

    public Integer getUserId() { return userId; }
    public void setUserId(Integer userId) { this.userId = userId; }

    public Timestamp getCreatedAt() { return createdAt; }
    public void setCreatedAt(Timestamp createdAt) { this.createdAt = createdAt; }
}