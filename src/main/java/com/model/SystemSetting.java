package com.model;

import java.sql.Timestamp;

public class SystemSetting {
    private Integer id;
    private String settingKey;
    private String settingValue;
    private String description;
    private Integer updatedBy;
    private Timestamp updatedAt;

    public SystemSetting() {}

    public SystemSetting(String settingKey, String settingValue, String description, Integer updatedBy) {
        this.settingKey = settingKey;
        this.settingValue = settingValue;
        this.description = description;
        this.updatedBy = updatedBy;
    }

    public Integer getId() { return id; }
    public void setId(Integer id) { this.id = id; }

    public String getSettingKey() { return settingKey; }
    public void setSettingKey(String settingKey) { this.settingKey = settingKey; }

    public String getSettingValue() { return settingValue; }
    public void setSettingValue(String settingValue) { this.settingValue = settingValue; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public Integer getUpdatedBy() { return updatedBy; }
    public void setUpdatedBy(Integer updatedBy) { this.updatedBy = updatedBy; }

    public Timestamp getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Timestamp updatedAt) { this.updatedAt = updatedAt; }
}