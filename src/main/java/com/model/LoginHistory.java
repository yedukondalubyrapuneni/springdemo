package com.model;

import java.sql.Timestamp;

public class LoginHistory {
    private Long id;
    private Integer userId;
    private String email;
    private String activityType;
    private String ipAddress;
    private String userAgent;
    private Timestamp createdAt;

    public LoginHistory() {}

    public LoginHistory(Integer userId, String email, String activityType, String ipAddress, String userAgent) {
        this.userId = userId;
        this.email = email;
        this.activityType = activityType;
        this.ipAddress = ipAddress;
        this.userAgent = userAgent;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Integer getUserId() { return userId; }
    public void setUserId(Integer userId) { this.userId = userId; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public String getActivityType() { return activityType; }
    public void setActivityType(String activityType) { this.activityType = activityType; }

    public String getIpAddress() { return ipAddress; }
    public void setIpAddress(String ipAddress) { this.ipAddress = ipAddress; }

    public String getUserAgent() { return userAgent; }
    public void setUserAgent(String userAgent) { this.userAgent = userAgent; }

    public Timestamp getCreatedAt() { return createdAt; }
    public void setCreatedAt(Timestamp createdAt) { this.createdAt = createdAt; }
}