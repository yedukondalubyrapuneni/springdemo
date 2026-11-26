package com.servlet;

import com.dao.SystemSettingsDAO;
import com.model.SystemSetting;
import com.service.AuditService;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;
import java.util.List;
import java.util.Map;

@WebServlet("/admin/system-settings")
public class SystemSettingsServlet extends HttpServlet {
    private final SystemSettingsDAO settingsDAO = new SystemSettingsDAO();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        HttpSession session = request.getSession(false);
        String role = (session != null) ? (String) session.getAttribute("role") : null;

        // Security check: Only Admins and Super Admins can manage settings
        if (role == null || (!role.equalsIgnoreCase("ADMIN") && !role.equalsIgnoreCase("SUPER ADMIN") && !role.equalsIgnoreCase("HR"))) {
            response.sendError(HttpServletResponse.SC_FORBIDDEN, "Access Denied: Administrative privileges required.");
            return;
        }

        List<SystemSetting> settingsList = settingsDAO.getAllSettings();
        Map<String, Object> userMetrics = settingsDAO.getUserMonitoringMetrics();

        request.setAttribute("settingsList", settingsList);
        request.setAttribute("userMetrics", userMetrics);
        request.getRequestDispatcher("/admin/system-settings.jsp").forward(request, response);
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        HttpSession session = request.getSession(false);
        Integer adminUserId = (session != null) ? (Integer) session.getAttribute("userId") : null;

        if (adminUserId == null) {
            response.sendRedirect(request.getContextPath() + "/login.jsp");
            return;
        }

        String key = request.getParameter("settingKey");
        String newValue = request.getParameter("settingValue");

        if (key != null && newValue != null) {
            SystemSetting existing = settingsDAO.getSettingByKey(key);
            String oldValue = existing != null ? existing.getSettingValue() : "";

            boolean success = settingsDAO.updateSetting(key, newValue.trim(), adminUserId);
            if (success) {
                // Record the modification in audit_logs (Requirement 4.D / 9.4)
                String oldJson = "{\"" + key + "\": \"" + oldValue + "\"}";
                String newJson = "{\"" + key + "\": \"" + newValue.trim() + "\"}";
                AuditService.logActivity(
                    adminUserId,
                    "System Settings",
                    "UPDATE",
                    key,
                    "Updated system configuration: " + key,
                    oldJson,
                    newJson,
                    request
                );
            }
        }
        response.sendRedirect(request.getContextPath() + "/admin/system-settings?msg=updated");
    }
}