package com.model;

import java.sql.Timestamp;

public class BackupHistory {
    private Long id;
    private String backupFile;
    private String backupType;
    private String status;
    private Long fileSize;
    private Integer createdBy;
    private Timestamp createdAt;
    private String remarks;

    public BackupHistory() {}

    public BackupHistory(String backupFile, String backupType, String status, Long fileSize, Integer createdBy, String remarks) {
        this.backupFile = backupFile;
        this.backupType = backupType;
        this.status = status;
        this.fileSize = fileSize;
        this.createdBy = createdBy;
        this.remarks = remarks;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getBackupFile() { return backupFile; }
    public void setBackupFile(String backupFile) { this.backupFile = backupFile; }

    public String getBackupType() { return backupType; }
    public void setBackupType(String backupType) { this.backupType = backupType; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public Long getFileSize() { return fileSize; }
    public void setFileSize(Long fileSize) { this.fileSize = fileSize; }

    public Integer getCreatedBy() { return createdBy; }
    public void setCreatedBy(Integer createdBy) { this.createdBy = createdBy; }

    public Timestamp getCreatedAt() { return createdAt; }
    public void setCreatedAt(Timestamp createdAt) { this.createdAt = createdAt; }

    public String getRemarks() { return remarks; }
    public void setRemarks(String remarks) { this.remarks = remarks; }
}