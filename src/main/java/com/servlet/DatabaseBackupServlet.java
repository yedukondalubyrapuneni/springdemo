package com.servlet;

import com.dao.BackupHistoryDAO;
import com.model.BackupHistory;
import com.service.AuditService;
import com.service.BackupService;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;
import java.util.List;

@WebServlet("/admin/backup-management")
public class DatabaseBackupServlet extends HttpServlet {
    private final BackupHistoryDAO backupDAO = new BackupHistoryDAO();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        List<BackupHistory> backups = backupDAO.getAllBackups(25);
        request.setAttribute("backups", backups);
        request.getRequestDispatcher("/admin/backup-management.jsp").forward(request, response);
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

        String appRoot = getServletContext().getRealPath("/WEB-INF");
        boolean ok = BackupService.triggerFullBackup(adminUserId, appRoot);

        // Audit the backup operation (Requirement 4.G / 9.5)
        AuditService.logActivity(
            adminUserId,
            "Backup Management",
            "BACKUP",
            "FULL_DB",
            "Administrator initiated full database backup. Result: " + (ok ? "SUCCESS" : "FAILED"),
            "{}",
            "{\"status\": \"" + (ok ? "SUCCESS" : "FAILED") + "\"}",
            request
        );

        response.sendRedirect(request.getContextPath() + "/admin/backup-management?status=" + (ok ? "done" : "failed"));
    }
}