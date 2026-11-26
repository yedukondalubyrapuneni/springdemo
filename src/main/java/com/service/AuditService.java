package com.service;

import com.dao.AuditLogDAO;
import com.model.AuditLog;
import jakarta.servlet.http.HttpServletRequest;

public class AuditService {
    private static final AuditLogDAO auditLogDAO = new AuditLogDAO();

    public static void logActivity(Integer userId, String moduleName, String actionType,
                                   String recordId, String description,
                                   String oldValuesJson, String newValuesJson,
                                   HttpServletRequest request) {
        String clientIp = extractClientIp(request);
        AuditLog log = new AuditLog(userId, moduleName, actionType, recordId, description,
                                    oldValuesJson, newValuesJson, clientIp);
        auditLogDAO.insertAuditLog(log);
    }

    public static String extractClientIp(HttpServletRequest request) {
        if (request == null) return "0.0.0.0";
        String ip = request.getHeader("X-Forwarded-For");
        if (ip == null || ip.isBlank() || "unknown".equalsIgnoreCase(ip)) {
            ip = request.getHeader("Proxy-Client-IP");
        }
        if (ip == null || ip.isBlank() || "unknown".equalsIgnoreCase(ip)) {
            ip = request.getRemoteAddr();
        }
        if (ip != null && ip.contains(",")) {
            ip = ip.split(",")[0].trim();
        }
        return ip;
    }
}