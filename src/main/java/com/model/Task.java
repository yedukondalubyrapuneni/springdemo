package com.model;

import java.time.LocalDate;
import java.time.LocalDateTime;

public class Task {
    private int id;
    private String taskTitle;
    private String description;
    private String taskFilePath;          // Manager attached briefing file
    
    // String IDs to support alphanumeric codes like "EMP101" & "MGR02"
    private String assignedTo;
    private String createdBy;
    
    private String department;
    private String priority;
    private LocalDate startDate;
    private LocalDate dueDate;
    private String status;
    private String employeeComment;
    private String submissionFilePath;    // Employee uploaded proof document
    private Integer rating;               // 1 to 5 stars
    private String managerFeedback;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    private String assignedToName;
    private String createdByName;

    public Task() {}
    private int teamId;

    public int getTeamId() { 
        return teamId; 
    }

    public void setTeamId(int teamId) { 
        this.teamId = teamId; 
    }
    // --- Task ID & Formatted ID ---
    public int getId() { return id; }
    public void setId(int id) { this.id = id; }
    public String getFormattedTaskId() { return String.format("TASK%03d", id); }

    // --- Title (supports both getTitle and getTaskTitle) ---
    public String getTaskTitle() { return taskTitle != null ? taskTitle : ""; }
    public void setTaskTitle(String taskTitle) { this.taskTitle = taskTitle; }
    public String getTitle() { return getTaskTitle(); }
    public void setTitle(String title) { setTaskTitle(title); }

    // --- Description & File Paths ---
    public String getDescription() { return description != null ? description : ""; }
    public void setDescription(String description) { this.description = description; }

    public String getTaskFilePath() { return taskFilePath; }
    public void setTaskFilePath(String taskFilePath) { this.taskFilePath = taskFilePath; }

    public String getSubmissionFilePath() { return submissionFilePath; }
    public void setSubmissionFilePath(String submissionFilePath) { this.submissionFilePath = submissionFilePath; }

    // --- Assignee Identification (Supports String & int IDs) ---
    public String getAssignedTo() { 
        return (assignedTo != null && !assignedTo.isBlank()) ? assignedTo : (assignedToName != null ? assignedToName : ""); 
    }
    public void setAssignedTo(String assignedTo) { 
        this.assignedTo = assignedTo; 
        if (this.assignedToName == null || this.assignedToName.isBlank()) {
            this.assignedToName = assignedTo;
        }
    }
    public void setAssignedTo(int assignedTo) { 
        this.assignedTo = String.valueOf(assignedTo); 
    }

    public String getAssignedToName() { 
        return (assignedToName != null && !assignedToName.isBlank()) ? assignedToName : assignedTo; 
    }
    public void setAssignedToName(String assignedToName) { 
        this.assignedToName = assignedToName; 
        if (this.assignedTo == null || this.assignedTo.isBlank()) {
            this.assignedTo = assignedToName;
        }
    }

    public String getEmployeeId() { return getAssignedTo(); }
    public void setEmployeeId(String employeeId) { setAssignedTo(employeeId); }

    // --- Creator / Assigned By Identification ---
    public String getCreatedBy() { 
        return (createdBy != null && !createdBy.isBlank()) ? createdBy : (createdByName != null ? createdByName : ""); 
    }
    public void setCreatedBy(String createdBy) { 
        this.createdBy = createdBy; 
        if (this.createdByName == null || this.createdByName.isBlank()) {
            this.createdByName = createdBy;
        }
    }
    public void setCreatedBy(int createdBy) { 
        this.createdBy = String.valueOf(createdBy); 
    }

    public String getCreatedByName() { 
        return (createdByName != null && !createdByName.isBlank()) ? createdByName : createdBy; 
    }
    public void setCreatedByName(String createdByName) { 
        this.createdByName = createdByName; 
        if (this.createdBy == null || this.createdBy.isBlank()) {
            this.createdBy = createdByName;
        }
    }

    public String getAssignedBy() { return getCreatedBy(); }
    public void setAssignedBy(String assignedBy) { setCreatedBy(assignedBy); }

    // --- Organization & Details ---
    public String getDepartment() { return department; }
    public void setDepartment(String department) { this.department = department; }

    public String getPriority() { return (priority != null && !priority.isBlank()) ? priority : "MEDIUM"; }
    public void setPriority(String priority) { this.priority = priority; }

    public LocalDate getStartDate() { return startDate; }
    public void setStartDate(LocalDate startDate) { this.startDate = startDate; }

    public LocalDate getDueDate() { return dueDate; }
    public void setDueDate(LocalDate dueDate) { this.dueDate = dueDate; }

    public String getStatus() { return (status != null && !status.isBlank()) ? status : "ASSIGNED"; }
    public void setStatus(String status) { this.status = status; }

    // --- Submission Comments & Aliases ---
    public String getEmployeeComment() { return employeeComment != null ? employeeComment : ""; }
    public void setEmployeeComment(String employeeComment) { this.employeeComment = employeeComment; }

    public String getEmployeeSubmissionNote() { return getEmployeeComment(); }
    public void setEmployeeSubmissionNote(String employeeSubmissionNote) { setEmployeeComment(employeeSubmissionNote); }

    // --- Performance Rating & Feedback ---
    public Integer getRating() { return rating; }
    public void setRating(Integer rating) { this.rating = rating; }

    public String getManagerFeedback() { return managerFeedback; }
    public void setManagerFeedback(String managerFeedback) { this.managerFeedback = managerFeedback; }

    // --- Timestamps ---
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }
}