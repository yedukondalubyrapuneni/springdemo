package com.model;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

public class Team {
    private int id;
    private String teamName;
    private String description;
    private Integer departmentId;
    private String departmentName;
    private Integer managerId;
    private String managerName;
    private String status; // "ACTIVE" or "INACTIVE"
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    public Team() {}

    // Formats integer database ID to professional TEAM001 identifier
    public String getFormattedTeamId() {
        return String.format("TEAM%03d", id);
    }

    public String getFormattedCreatedDate() {
        if (createdAt != null) {
            return createdAt.format(DateTimeFormatter.ofPattern("dd-MM-yyyy"));
        }
        return "--";
    }

    public int getId() { return id; }
    public void setId(int id) { this.id = id; }

    public String getTeamName() { return teamName; }
    public void setTeamName(String teamName) { this.teamName = teamName; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public Integer getDepartmentId() { return departmentId; }
    public void setDepartmentId(Integer departmentId) { this.departmentId = departmentId; }

    public String getDepartmentName() { return departmentName; }
    public void setDepartmentName(String departmentName) { this.departmentName = departmentName; }

    public Integer getManagerId() { return managerId; }
    public void setManagerId(Integer managerId) { this.managerId = managerId; }

    public String getManagerName() { return managerName; }
    public void setManagerName(String managerName) { this.managerName = managerName; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }
}