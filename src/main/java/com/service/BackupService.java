package com.service;

import com.dao.BackupHistoryDAO;
import com.model.BackupHistory;

import java.io.File;
import java.text.SimpleDateFormat;
import java.util.Date;

public class BackupService {
    private static final BackupHistoryDAO backupDAO = new BackupHistoryDAO();

    // Adjust path according to your local MySQL install or system PATH
    private static final String MYSQLDUMP_PATH = "mysqldump"; 
    private static final String DB_USER = "root";
    private static final String DB_PASS = "root"; // your local DB password
    private static final String DB_NAME = "smartoffice";

    public static boolean triggerFullBackup(Integer adminUserId, String backupFolderRoot) {
        String timeStamp = new SimpleDateFormat("yyyyMMdd_HHmmss").format(new Date());
        String fileName = "smartoffice_backup_" + timeStamp + ".sql";

        File storageDir = new File(backupFolderRoot, "backups");
        if (!storageDir.exists()) {
            storageDir.mkdirs();
        }

        File targetFile = new File(storageDir, fileName);
        long fileSize = 0;
        String status = "FAILED";
        String remarks = "";

        try {
            // Build process execution command
            ProcessBuilder pb = new ProcessBuilder(
                MYSQLDUMP_PATH,
                "-u" + DB_USER,
                "-p" + DB_PASS,
                DB_NAME
            );
            pb.redirectOutput(targetFile);
            pb.redirectError(ProcessBuilder.Redirect.INHERIT);

            Process process = pb.start();
            int exitCode = process.waitFor();

            if (exitCode == 0 && targetFile.exists()) {
                status = "SUCCESS";
                fileSize = targetFile.length();
                remarks = "Backup completed successfully via mysqldump.";
            } else {
                remarks = "mysqldump returned non-zero exit code: " + exitCode;
            }
        } catch (Exception e) {
            remarks = "Backup execution error: " + e.getMessage();
        }

        BackupHistory record = new BackupHistory(fileName, "FULL", status, fileSize, adminUserId, remarks);
        backupDAO.recordBackup(record);

        return "SUCCESS".equals(status);
    }
}