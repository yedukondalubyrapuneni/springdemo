package com.model;

import java.sql.Timestamp;

public class AuditLog {
    private Long id;
    private Integer userId;
    private String moduleName;
    private String actionType;
    private String recordId;
    private String description;
    private String oldValues;
    private String newValues;
    private String ipAddress;
    private Timestamp createdAt;

    public AuditLog() {}

    public AuditLog(Integer userId, String moduleName, String actionType, String recordId, 
                    String description, String oldValues, String newValues, String ipAddress) {
        this.userId = userId;
        this.moduleName = moduleName;
        this.actionType = actionType;
        this.recordId = recordId;
        this.description = description;
        this.oldValues = oldValues;
        this.newValues = newValues;
        this.ipAddress = ipAddress;
    }

    // Getters and Setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Integer getUserId() { return userId; }
    public void setUserId(Integer userId) { this.userId = userId; }

    public String getModuleName() { return moduleName; }
    public void setModuleName(String moduleName) { this.moduleName = moduleName; }

    public String getActionType() { return actionType; }
    public void setActionType(String actionType) { this.actionType = actionType; }

    public String getRecordId() { return recordId; }
    public void setRecordId(String recordId) { this.recordId = recordId; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public String getOldValues() { return oldValues; }
    public void setOldValues(String oldValues) { this.oldValues = oldValues; }

    public String getNewValues() { return newValues; }
    public void setNewValues(String newValues) { this.newValues = newValues; }

    public String getIpAddress() { return ipAddress; }
    public void setIpAddress(String ipAddress) { this.ipAddress = ipAddress; }

    public Timestamp getCreatedAt() { return createdAt; }
    public void setCreatedAt(Timestamp createdAt) { this.createdAt = createdAt; }
}