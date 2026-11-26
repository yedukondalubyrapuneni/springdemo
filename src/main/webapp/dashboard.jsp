<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="com.example.demo.model.Employee,com.example.demo.model.Task,com.example.demo.model.Attendance,com.example.demo.model.Payroll,com.example.demo.model.PayrollPayment,com.example.demo.model.AuditLog,com.example.demo.model.LoginHistory,com.example.demo.model.SystemError,com.example.demo.model.FinanceMISReport" %>
<%@ page import="com.dao.TaskDao, com.dao.AttendanceDao, com.dao.PayrollDAO, com.dao.PayrollPaymentDAO, com.dao.AuditLogDAO, com.dao.SystemErrorDAO, com.dao.SystemSettingsDAO" %>
<%@ page import="com.Util.DBConnection" %>
<%@ page import="java.math.BigDecimal, java.sql.*, java.io.*, java.text.SimpleDateFormat" %>
<%@ page import="java.util.*, java.time.Month, java.time.format.TextStyle, java.time.format.DateTimeFormatter" %>
<%!
    private static final DateTimeFormatter TIME_FMT = DateTimeFormatter.ofPattern("hh:mm a");

    private String formatLocalTime(java.time.LocalTime t) {
        return (t != null) ? t.format(TIME_FMT) : "--";
    }

    private String formatBreakRange(java.time.LocalTime start, java.time.LocalTime end) {
        if (start == null) return "--";
        if (end == null) return start.format(TIME_FMT) + " - (Active)";
        return start.format(TIME_FMT) + " - " + end.format(TIME_FMT);
    }

    private String extractDate(Attendance att) {
        if (att == null) return "--";
        try {
            java.lang.reflect.Method m = att.getClass().getMethod("getFormattedDate");
            Object val = m.invoke(att);
            if (val != null) return val.toString();
        } catch (Exception ignored) {}
        try {
            java.lang.reflect.Method m = att.getClass().getMethod("getAttendanceDate");
            Object val = m.invoke(att);
            if (val != null) return val.toString();
        } catch (Exception ignored) {}
        try {
            java.lang.reflect.Method m = att.getClass().getMethod("getDate");
            Object val = m.invoke(att);
            if (val != null) return val.toString();
        } catch (Exception ignored) {}
        return "--";
    }

    private String extractEmpName(Attendance att) {
        if (att == null) return "Employee";
        try {
            java.lang.reflect.Method m = att.getClass().getMethod("getEmployeeName");
            Object val = m.invoke(att);
            if (val != null && !val.toString().isBlank()) return val.toString();
        } catch (Exception ignored) {}
        return (att.getEmployeeId() != null) ? att.getEmployeeId() : "Employee";
    }
%>
<%
    Employee loggedIn = (Employee) session.getAttribute("loggedInEmployee");
    String userRole = (loggedIn != null && loggedIn.getRole() != null) ? loggedIn.getRole().trim().toUpperCase() : "";

    if (loggedIn == null || (!"ADMIN".equals(userRole) && !"HR".equals(userRole) && !"SUPER ADMIN".equals(userRole))) {
        response.sendRedirect(request.getContextPath() + "/login.jsp");
        return;
    }

    boolean isAdmin = "ADMIN".equals(userRole) || "SUPER ADMIN".equals(userRole);
    boolean isHr = !isAdmin && ("HR".equals(userRole) || loggedIn.isHrDesignation());
    int currentUserId = loggedIn.getId();
    String userDisplayName = (loggedIn.getName() != null) ? loggedIn.getName() : "Administrator";

    // Backup Storage Directory
    String backupDirPath = application.getRealPath("/") + "backups";
    File backupDir = new File(backupDirPath);
    if (!backupDir.exists()) backupDir.mkdirs();

    // =========================================================================
    // 1. DIRECT GET ACTIONS FOR SYSTEM & SECURITY
    // =========================================================================
    if (isAdmin) {
        String downloadFile = request.getParameter("downloadBackup");
        if (downloadFile != null && !downloadFile.isBlank()) {
            File fileToDownload = new File(backupDir, new File(downloadFile).getName());
            if (fileToDownload.exists()) {
                response.setContentType("application/octet-stream");
                response.setHeader("Content-Disposition", "attachment; filename=\"" + fileToDownload.getName() + "\"");
                try (FileInputStream in = new FileInputStream(fileToDownload);
                     OutputStream outStream = response.getOutputStream()) {
                    byte[] buffer = new byte[4096];
                    int bytesRead;
                    while ((bytesRead = in.read(buffer)) != -1) {
                        outStream.write(buffer, 0, bytesRead);
                    }
                    outStream.flush();
                    return;
                }
            }
        }

        String deleteBackupId = request.getParameter("deleteBackup");
        if (deleteBackupId != null && !deleteBackupId.isBlank()) {
            try (Connection conn = DBConnection.getConnection()) {
                String fileName = null;
                try (PreparedStatement ps = conn.prepareStatement("SELECT backup_file FROM backup_history WHERE id = ?")) {
                    ps.setLong(1, Long.parseLong(deleteBackupId));
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) fileName = rs.getString("backup_file");
                    }
                }
                if (fileName != null) {
                    File f = new File(backupDir, fileName);
                    if (f.exists()) f.delete();
                }
                try (PreparedStatement ps = conn.prepareStatement("DELETE FROM backup_history WHERE id = ?")) {
                    ps.setLong(1, Long.parseLong(deleteBackupId));
                    ps.executeUpdate();
                }
                session.setAttribute("toastMsg", "Backup archive removed successfully.");
            } catch (Exception e) {
                session.setAttribute("toastErr", "Delete backup failed: " + e.getMessage());
            }
            response.sendRedirect(request.getContextPath() + "/dashboard.jsp?tab=tab-sysbackups");
            return;
        }

        if ("clearErrors".equalsIgnoreCase(request.getParameter("sysAction"))) {
            try (Connection conn = DBConnection.getConnection();
                 PreparedStatement ps = conn.prepareStatement("TRUNCATE TABLE system_errors")) {
                ps.executeUpdate();
                session.setAttribute("toastMsg", "All system error logs have been cleared.");
            } catch (Exception e) {
                session.setAttribute("toastErr", "Failed to clear error logs: " + e.getMessage());
            }
            response.sendRedirect(request.getContextPath() + "/dashboard.jsp?tab=tab-syserrors");
            return;
        }
    }

    // =========================================================================
    // 2. DIRECT POST ACTIONS (Self-Attendance, System Settings, Logo, Backups)
    // =========================================================================
    if ("POST".equalsIgnoreCase(request.getMethod())) {
        // A. Self-Attendance Punch Handler
        String punchAction = request.getParameter("punchAction");
        if (punchAction != null && !punchAction.isBlank()) {
            try (Connection conn = DBConnection.getConnection()) {
                java.time.LocalDate today = java.time.LocalDate.now();
                java.time.LocalTime now = java.time.LocalTime.now();
                String empId = loggedIn.getEmployeeId();

                if ("checkIn".equalsIgnoreCase(punchAction)) {
                    try (PreparedStatement checkPs = conn.prepareStatement(
                            "SELECT id FROM attendance WHERE employee_id = ? AND attendance_date = ?")) {
                        checkPs.setString(1, empId);
                        checkPs.setDate(2, java.sql.Date.valueOf(today));
                        try (ResultSet rs = checkPs.executeQuery()) {
                            if (!rs.next()) {
                                try (PreparedStatement insPs = conn.prepareStatement(
                                        "INSERT INTO attendance (employee_id, attendance_date, check_in_time, status) VALUES (?, ?, ?, 'PRESENT')")) {
                                    insPs.setString(1, empId);
                                    insPs.setDate(2, java.sql.Date.valueOf(today));
                                    insPs.setTime(3, java.sql.Time.valueOf(now));
                                    insPs.executeUpdate();
                                    session.setAttribute("toastMsg", "Punched check-in recorded at " + now.format(TIME_FMT));
                                }
                            } else {
                                session.setAttribute("toastErr", "You have already punched in for today.");
                            }
                        }
                    }
                } else if ("checkOut".equalsIgnoreCase(punchAction)) {
                    try (PreparedStatement upPs = conn.prepareStatement(
                            "UPDATE attendance SET check_out_time = ? WHERE employee_id = ? AND attendance_date = ? AND check_out_time IS NULL")) {
                        upPs.setTime(1, java.sql.Time.valueOf(now));
                        upPs.setString(2, empId);
                        upPs.setDate(3, java.sql.Date.valueOf(today));
                        int rows = upPs.executeUpdate();
                        if (rows > 0) {
                            session.setAttribute("toastMsg", "Punched check-out recorded at " + now.format(TIME_FMT));
                        } else {
                            session.setAttribute("toastErr", "No active check-in found to punch out, or already punched out.");
                        }
                    }
                } else if ("breakStart".equalsIgnoreCase(punchAction)) {
                    try (PreparedStatement bPs = conn.prepareStatement(
                            "UPDATE attendance SET break1_start_time = COALESCE(break1_start_time, ?) WHERE employee_id = ? AND attendance_date = ?")) {
                        bPs.setTime(1, java.sql.Time.valueOf(now));
                        bPs.setString(2, empId);
                        bPs.setDate(3, java.sql.Date.valueOf(today));
                        bPs.executeUpdate();
                        session.setAttribute("toastMsg", "Break started at " + now.format(TIME_FMT));
                    }
                } else if ("breakEnd".equalsIgnoreCase(punchAction)) {
                    try (PreparedStatement bePs = conn.prepareStatement(
                            "UPDATE attendance SET break1_end_time = COALESCE(break1_end_time, ?) WHERE employee_id = ? AND attendance_date = ?")) {
                        bePs.setTime(1, java.sql.Time.valueOf(now));
                        bePs.setString(2, empId);
                        bePs.setDate(3, java.sql.Date.valueOf(today));
                        bePs.executeUpdate();
                        session.setAttribute("toastMsg", "Break ended at " + now.format(TIME_FMT));
                    }
                }
            } catch (Exception ex) {
                session.setAttribute("toastErr", "Attendance error: " + ex.getMessage());
            }
            response.sendRedirect(request.getContextPath() + "/dashboard.jsp?tab=tab-selfatt");
            return;
        }

        // B. Company Logo Cloudinary URL Saver (No SQL Required)
        String sysAction = request.getParameter("sysAction");
        if (isAdmin && "updateLogo".equalsIgnoreCase(sysAction)) {
            String logoUrl = request.getParameter("companyLogoUrl");
            String cleanUrl = (logoUrl != null) ? logoUrl.trim() : "";
            application.setAttribute("COMPANY_LOGO_URL", cleanUrl);
            try {
                String propsPath = application.getRealPath("/WEB-INF/branding.properties");
                Properties props = new Properties();
                File propFile = new File(propsPath);
                if (propFile.exists()) {
                    try (FileInputStream fis = new FileInputStream(propFile)) {
                        props.load(fis);
                    }
                }
                props.setProperty("COMPANY_LOGO_URL", cleanUrl);
                try (FileOutputStream fos = new FileOutputStream(propFile)) {
                    props.store(fos, "SmartOffice Branding Configuration");
                }
                session.setAttribute("toastMsg", cleanUrl.isEmpty() ? "Company logo cleared." : "Company logo updated via Cloudinary link!");
            } catch (Exception e) {
                session.setAttribute("toastErr", "Saved to session, but file write failed: " + e.getMessage());
            }
            response.sendRedirect(request.getContextPath() + "/dashboard.jsp?tab=tab-syssettings");
            return;
        }

        // C. System Settings Update Handler (Admin Only)
        if (isAdmin && "updateSetting".equalsIgnoreCase(sysAction)) {
            String key = request.getParameter("settingKey");
            String value = request.getParameter("settingValue");
            if (key != null && value != null) {
                try (Connection conn = DBConnection.getConnection()) {
                    int updated = 0;
                    try (PreparedStatement ps = conn.prepareStatement(
                            "UPDATE system_settings SET setting_value = ?, updated_by = ?, updated_at = CURRENT_TIMESTAMP WHERE setting_key = ?")) {
                        ps.setString(1, value.trim());
                        ps.setInt(2, currentUserId);
                        ps.setString(3, key.trim());
                        updated = ps.executeUpdate();
                    }
                    if (updated == 0) {
                        try (PreparedStatement ins = conn.prepareStatement(
                                "INSERT INTO system_settings (setting_key, setting_value, updated_by, updated_at) VALUES (?, ?, ?, CURRENT_TIMESTAMP)")) {
                            ins.setString(1, key.trim());
                            ins.setString(2, value.trim());
                            ins.setInt(3, currentUserId);
                            ins.executeUpdate();
                        }
                    }
                    try (PreparedStatement aps = conn.prepareStatement(
                            "INSERT INTO audit_logs (user_id, module_name, action_type, record_id, description, new_values, created_at) " +
                            "VALUES (?, 'SYSTEM_SETTINGS', 'UPDATE', ?, 'Updated system configuration parameter', ?, CURRENT_TIMESTAMP)")) {
                        aps.setInt(1, currentUserId);
                        aps.setString(2, key.trim());
                        aps.setString(3, "{\"key\":\"" + key.trim() + "\",\"value\":\"" + value.trim().replace("\"", "\\\"") + "\"}");
                        aps.executeUpdate();
                    } catch (Exception ignored) {}

                    // Sync COMPANY_NAME and COMPANY_ADDRESS to branding.properties for instant payslip rendering
                    if ("COMPANY_NAME".equalsIgnoreCase(key.trim()) || "COMPANY_ADDRESS".equalsIgnoreCase(key.trim())) {
                        try {
                            String propsPath = application.getRealPath("/WEB-INF/branding.properties");
                            Properties props = new Properties();
                            File propFile = new File(propsPath);
                            if (propFile.exists()) {
                                try (FileInputStream fis = new FileInputStream(propFile)) {
                                    props.load(fis);
                                }
                            }
                            props.setProperty(key.trim().toUpperCase(), value.trim());
                            try (FileOutputStream fos = new FileOutputStream(propFile)) {
                                props.store(fos, "SmartOffice Branding Configuration");
                            }
                            application.setAttribute(key.trim().toUpperCase(), value.trim());
                        } catch (Exception ignored) {}
                    }

                    session.setAttribute("toastMsg", "Configuration [" + key + "] updated to " + value.trim());
                } catch (Exception e) {
                    session.setAttribute("toastErr", "Setting update failed: " + e.getMessage());
                }
            }
            response.sendRedirect(request.getContextPath() + "/dashboard.jsp?tab=tab-syssettings");
            return;
        }
        // D. Database Backup Snapshot Generator (Admin Only)
        if (isAdmin && "generateBackup".equalsIgnoreCase(sysAction)) {
            String timestamp = new SimpleDateFormat("yyyyMMdd_HHmmss").format(new java.util.Date());
            String backupFileName = "backup_smartoffice_" + timestamp + ".sql";
            File sqlFile = new File(backupDir, backupFileName);
            long fileSize = 0;

            try {
                try (PrintWriter writer = new PrintWriter(new FileWriter(sqlFile));
                     Connection conn = DBConnection.getConnection()) {
                    writer.println("-- =========================================================");
                    writer.println("-- SMART OFFICE SYSTEM DATABASE SNAPSHOT");
                    writer.println("-- Generated At: " + new java.util.Date());
                    writer.println("-- Operator: " + userDisplayName + " (UID #" + currentUserId + ")");
                    writer.println("-- =========================================================\n");

                    String[] tables = {"system_settings", "employee", "login_history", "audit_logs", "system_errors"};
                    for (String tbl : tables) {
                        writer.println("-- Table Data Dump: " + tbl);
                        try (Statement stmt = conn.createStatement();
                             ResultSet rs = stmt.executeQuery("SELECT * FROM " + tbl)) {
                            ResultSetMetaData md = rs.getMetaData();
                            int colCount = md.getColumnCount();
                            while (rs.next()) {
                                StringBuilder ins = new StringBuilder("INSERT INTO " + tbl + " VALUES (");
                                for (int i = 1; i <= colCount; i++) {
                                    String val = rs.getString(i);
                                    if (val == null) {
                                        ins.append("NULL");
                                    } else {
                                        ins.append("'").append(val.replace("'", "''")).append("'");
                                    }
                                    if (i < colCount) ins.append(", ");
                                }
                                ins.append(");");
                                writer.println(ins.toString());
                            }
                        } catch (Exception ignored) {}
                        writer.println();
                    }
                }

                fileSize = sqlFile.length();

                try (Connection conn = DBConnection.getConnection();
                     PreparedStatement ps = conn.prepareStatement(
                         "INSERT INTO backup_history (backup_file, backup_type, status, file_size, created_by, remarks, created_at) " +
                         "VALUES (?, 'FULL', 'SUCCESS', ?, ?, 'Manual point-in-time snapshot', NOW())")) {
                    ps.setString(1, backupFileName);
                    ps.setLong(2, fileSize);
                    if (currentUserId > 0) ps.setInt(3, currentUserId); else ps.setNull(3, java.sql.Types.INTEGER);
                    ps.executeUpdate();
                }

                try (Connection conn = DBConnection.getConnection();
                     PreparedStatement ps = conn.prepareStatement(
                         "INSERT INTO audit_logs (user_id, module_name, action_type, record_id, description, new_values, created_at) " +
                         "VALUES (?, 'BACKUP_ENGINE', 'CREATE', ?, 'Generated full SQL snapshot', ?, NOW())")) {
                    if (currentUserId > 0) ps.setInt(1, currentUserId); else ps.setNull(1, java.sql.Types.INTEGER);
                    ps.setString(2, backupFileName);
                    ps.setString(3, "{\"file\":\"" + backupFileName + "\",\"size_bytes\":" + fileSize + "}");
                    ps.executeUpdate();
                } catch (Exception ignored) {}

                session.setAttribute("toastMsg", "Database snapshot [" + backupFileName + "] created (" + (fileSize / 1024) + " KB).");
            } catch (Exception e) {
                session.setAttribute("toastErr", "Snapshot failed: " + e.getMessage());
            }
            response.sendRedirect(request.getContextPath() + "/dashboard.jsp?tab=tab-sysbackups");
            return;
        }
    }

    // =========================================================================
    // 3. CORE DASHBOARD & HR DATA LOADING
    // =========================================================================
    TaskDao taskDao = new TaskDao();
    AttendanceDao attendanceDao = new AttendanceDao();
    PayrollDAO payrollDao = new PayrollDAO();
    PayrollPaymentDAO paymentAuditDAO = new PayrollPaymentDAO();

    String reqMonth = request.getParameter("month");
    String reqYear = request.getParameter("year");
    String reqEmpId = request.getParameter("employeeId");

    int currentMonthVal = (reqMonth != null && !reqMonth.isBlank() && !"ALL".equalsIgnoreCase(reqMonth.trim())) 
            ? Integer.parseInt(reqMonth.trim()) 
            : java.time.LocalDate.now().getMonthValue();

    int currentYearVal = (reqYear != null && !reqYear.isBlank() && !"ALL".equalsIgnoreCase(reqYear.trim())) 
            ? Integer.parseInt(reqYear.trim()) 
            : java.time.LocalDate.now().getYear();

    FinanceMISReport misReport = payrollDao.getFinanceMISReport(currentMonthVal, currentYearVal);
    String filterEmpId = (reqEmpId != null && !reqEmpId.isBlank() && !"ALL".equalsIgnoreCase(reqEmpId.trim())) 
            ? reqEmpId.trim() 
            : null;

    List<Task> allTasks = (List<Task>) request.getAttribute("allTasks");
    if (allTasks == null) allTasks = taskDao.getAllTasks();

    int totalTasks = (allTasks != null) ? allTasks.size() : 0;
    int completedTasks = 0, inProgressTasks = 0, pendingReviews = 0, ratedCount = 0;
    double ratingSum = 0;
    Set<String> distinctManagers = new HashSet<>();

    if (allTasks != null) {
        for (Task t : allTasks) {
            if ("COMPLETED".equalsIgnoreCase(t.getStatus())) completedTasks++;
            else if ("IN_PROGRESS".equalsIgnoreCase(t.getStatus())) inProgressTasks++;
            else if ("SUBMITTED_FOR_REVIEW".equalsIgnoreCase(t.getStatus())) pendingReviews++;

            if (t.getRating() != null && t.getRating() > 0) {
                ratedCount++;
                ratingSum += t.getRating();
            }

            String mgrName = t.getCreatedByName();
            if (mgrName != null && !mgrName.isBlank()) {
                distinctManagers.add(mgrName.trim());
            }
        }
    }
    double avgRating = (ratedCount > 0) ? (ratingSum / ratedCount) : 0.0;

    List<Attendance> pendingLeaves = isHr ? attendanceDao.findPendingLeaveRequests() : null;

    List<Payroll> payrollList = payrollDao.getPayrollHistory(filterEmpId, 0, 0);
    if (payrollList == null || payrollList.isEmpty()) {
        payrollList = payrollDao.getPayrollHistory(filterEmpId, currentMonthVal, currentYearVal);
    }

    List<PayrollPayment> auditLogs = paymentAuditDAO.getAllDisbursements();
    List<Employee> activeEmpList = payrollDao.getAllActiveEmployees();
    List<Attendance> todayAttendance = attendanceDao.findByDate(java.time.LocalDate.now());

    int activeHeadcount = (activeEmpList != null) ? activeEmpList.size() : 0;
    long presentToday = (todayAttendance != null) ? todayAttendance.stream().filter(a -> "PRESENT".equalsIgnoreCase(a.getStatus())).count() : 0;
    long inProgressToday = (todayAttendance != null) ? todayAttendance.stream().filter(a -> a.getCheckInTime() != null && a.getCheckOutTime() == null).count() : 0;

    // =========================================================================
    // 4. SYSTEM & SECURITY DATA AGGREGATION (Safe Single-Bracket Types)
    // =========================================================================
    int sysTotalUsers = 0, sysActiveUsers = 0, sysInactiveUsers = 0;
    int sysTotalAuditRecords = 0, sysTodayLogins = 0, sysTodayFailedLogins = 0;
    String sysLatestBackupStatus = "NONE", sysLatestBackupTime = "No snapshots found";
    int sysTotalErrors = 0, sysCriticalErrors = 0, sysHighErrors = 0;
    int sysTotalBackups = 0, sysSuccessBackups = 0;

    List<AuditLog> sysAuditList = new ArrayList<>();
    List<LoginHistory> sysLoginList = new ArrayList<>();
    List<SystemError> sysErrorList = new ArrayList<>();
    List<Object[]> sysBackupRows = new ArrayList<>();
    Map<String, String> sysCfg = new HashMap<>();

    if (isAdmin) {
        try {
            SystemSettingsDAO settingsDAO = new SystemSettingsDAO();
            Map<String, Object> userMetrics = settingsDAO.getUserMonitoringMetrics();
            if (userMetrics != null) {
                if (userMetrics.get("totalUsers") != null) sysTotalUsers = (Integer) userMetrics.get("totalUsers");
                if (userMetrics.get("activeUsers") != null) sysActiveUsers = (Integer) userMetrics.get("activeUsers");
                if (userMetrics.get("inactiveUsers") != null) sysInactiveUsers = (Integer) userMetrics.get("inactiveUsers");
            }
        } catch (Exception ignored) {}

        try {
            AuditLogDAO auditDAO = new AuditLogDAO();
            sysAuditList = auditDAO.getAllAuditLogs(50, 0);
        } catch (Exception ignored) {}

        try (Connection conn = DBConnection.getConnection()) {
            try (PreparedStatement ps = conn.prepareStatement("SELECT COUNT(*) FROM audit_logs");
                 ResultSet rs = ps.executeQuery()) {
                if (rs.next()) sysTotalAuditRecords = rs.getInt(1);
            } catch (Exception ignored) {}

            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT SUM(CASE WHEN activity_type = 'LOGIN' THEN 1 ELSE 0 END) AS s_today, " +
                    "SUM(CASE WHEN activity_type = 'FAILED_LOGIN' THEN 1 ELSE 0 END) AS f_today " +
                    "FROM login_history WHERE DATE(created_at) = CURRENT_DATE");
                 ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    sysTodayLogins = rs.getInt("s_today");
                    sysTodayFailedLogins = rs.getInt("f_today");
                }
            } catch (Exception ignored) {}

            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT id, user_id, email, activity_type, ip_address, user_agent, created_at FROM login_history ORDER BY id DESC LIMIT 50");
                 ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    LoginHistory lh = new LoginHistory();
                    lh.setUserId(rs.getInt("user_id"));
                    lh.setEmail(rs.getString("email"));
                    lh.setActivityType(rs.getString("activity_type"));
                    lh.setIpAddress(rs.getString("ip_address"));
                    lh.setUserAgent(rs.getString("user_agent"));
                    lh.setCreatedAt(rs.getTimestamp("created_at"));
                    sysLoginList.add(lh);
                }
            } catch (Exception ignored) {}

            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT COUNT(*) AS t_err, " +
                    "SUM(CASE WHEN UPPER(severity) = 'CRITICAL' THEN 1 ELSE 0 END) AS c_err, " +
                    "SUM(CASE WHEN UPPER(severity) = 'HIGH' THEN 1 ELSE 0 END) AS h_err FROM system_errors");
                 ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    sysTotalErrors = rs.getInt("t_err");
                    sysCriticalErrors = rs.getInt("c_err");
                    sysHighErrors = rs.getInt("h_err");
                }
            } catch (Exception ignored) {}

            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT id, user_id, module_name, error_type, error_message, severity, created_at FROM system_errors ORDER BY id DESC LIMIT 50");
                 ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    SystemError err = new SystemError();
                    err.setUserId(rs.getInt("user_id"));
                    err.setModuleName(rs.getString("module_name"));
                    err.setErrorType(rs.getString("error_type"));
                    err.setErrorMessage(rs.getString("error_message"));
                    err.setSeverity(rs.getString("severity"));
                    err.setCreatedAt(rs.getTimestamp("created_at"));
                    sysErrorList.add(err);
                }
            } catch (Exception ignored) {}

            try (PreparedStatement ps = conn.prepareStatement("SELECT setting_key, setting_value FROM system_settings");
                 ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    sysCfg.put(rs.getString("setting_key"), rs.getString("setting_value"));
                }
            } catch (Exception ignored) {}

            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT COUNT(*) AS t_bk, " +
                    "SUM(CASE WHEN UPPER(COALESCE(status, 'SUCCESS')) = 'SUCCESS' THEN 1 ELSE 0 END) AS s_bk, " +
                    "MAX(created_at) AS latest FROM backup_history");
                 ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    sysTotalBackups = rs.getInt("t_bk");
                    sysSuccessBackups = rs.getInt("s_bk");
                    Timestamp ts = rs.getTimestamp("latest");
                    if (ts != null) {
                        sysLatestBackupTime = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(ts);
                        sysLatestBackupStatus = "SUCCESS";
                    }
                }
            } catch (Exception ignored) {}

            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT id, backup_file, backup_type, status, file_size, created_at FROM backup_history ORDER BY id DESC LIMIT 50");
                 ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Object[] row = new Object[6];
                    row[0] = rs.getLong("id");
                    row[1] = rs.getString("backup_file");
                    row[2] = rs.getString("backup_type");
                    row[3] = rs.getString("status");
                    row[4] = rs.getLong("file_size");
                    row[5] = rs.getTimestamp("created_at");
                    sysBackupRows.add(row);
                }
            } catch (Exception ignored) {}

        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    String cfgCompanyName = sysCfg.getOrDefault("COMPANY_NAME", "SmartOffice Technologies");
    String cfgCompanyEmail = sysCfg.getOrDefault("COMPANY_EMAIL", "admin@smartoffice.com");
    String cfgCompanyAddress = sysCfg.getOrDefault("COMPANY_ADDRESS", "HITEC City, Hyderabad");
    String cfgCurrency = sysCfg.getOrDefault("SYSTEM_CURRENCY", "INR (₹)");
    String cfgTimezone = sysCfg.getOrDefault("SYSTEM_TIMEZONE", "Asia/Kolkata");
    String cfgMaxAttempts = sysCfg.getOrDefault("MAX_FAILED_ATTEMPTS", "3");
    String cfgLockoutMins = sysCfg.getOrDefault("LOCKOUT_DURATION_MINUTES", "1");
    String cfgWorkHours = sysCfg.getOrDefault("DEFAULT_WORK_HOURS", "8");
    String cfgGraceMins = sysCfg.getOrDefault("GRACE_PERIOD_MINUTES", "15");
    boolean cfgEmailAlerts = "ENABLED".equalsIgnoreCase(sysCfg.getOrDefault("NOTIFY_EMAIL_ALERTS", "ENABLED"));
    boolean cfgAutoBackup = "ENABLED".equalsIgnoreCase(sysCfg.getOrDefault("BACKUP_AUTO_DAILY", "ENABLED"));

    // Load Cloudinary Company Logo URL (No SQL Required)
    String cfgCompanyLogo = (String) application.getAttribute("COMPANY_LOGO_URL");
    if (cfgCompanyLogo == null || cfgCompanyLogo.isBlank()) {
        try {
            String propsPath = application.getRealPath("/WEB-INF/branding.properties");
            File propFile = new File(propsPath);
            if (propFile.exists()) {
                Properties props = new Properties();
                try (FileInputStream fis = new FileInputStream(propFile)) {
                    props.load(fis);
                }
                cfgCompanyLogo = props.getProperty("COMPANY_LOGO_URL", "");
                if (!cfgCompanyLogo.isBlank()) {
                    application.setAttribute("COMPANY_LOGO_URL", cfgCompanyLogo);
                }
            }
        } catch (Exception ignored) {}
    }
    if (cfgCompanyLogo == null) cfgCompanyLogo = "";

    String activeTabParam = request.getParameter("tab");
    String activeTab = (activeTabParam != null && !activeTabParam.isBlank()) ? activeTabParam : "tab-overview";

    String toastMsg = (String) session.getAttribute("toastMsg");
    String toastErr = (String) session.getAttribute("toastErr");
    session.removeAttribute("toastMsg");
    session.removeAttribute("toastErr");

    if (toastMsg == null) toastMsg = request.getParameter("msg");
    if (toastErr == null) toastErr = request.getParameter("error");
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title><%= isAdmin ? "Admin Console" : "HR Operations Console" %> | EMS Enterprise</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@500;600;700;800&display=swap" rel="stylesheet">
    <style>
        :root {
            --brand-primary: #2563eb;
            --brand-hover: #1d4ed8;
            --sidebar-bg: #0f172a;
            --border-subtle: #e2e8f0;
            --text-main: #0f172a;
            --text-muted: #64748b;
            --surface-card: #ffffff;
            --surface-bg: #f8fafc;
            --emerald: #10b981;
            --rose: #ef4444;
            --amber: #f59e0b;
            --purple: #8b5cf6;
            --shadow-card: 0 4px 6px -1px rgba(0, 0, 0, 0.05), 0 2px 4px -2px rgba(0, 0, 0, 0.05);
            --shadow-float: 0 10px 25px -5px rgba(37, 99, 235, 0.12);
        }

        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: 'Plus Jakarta Sans', sans-serif; background: var(--surface-bg); color: var(--text-main); display: flex; height: 100vh; overflow: hidden; }

        /* SIDEBAR (Desktop Fixed + Responsive Mobile Drawer) */
        .sidebar {
            width: 260px;
            background: var(--sidebar-bg);
            color: #fff;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
            padding: 20px 14px;
            flex-shrink: 0;
            overflow-y: auto;
            transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            z-index: 100;
        }
        .sidebar::-webkit-scrollbar { width: 5px; }
        .sidebar::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.2); border-radius: 4px; }

        .sidebar-overlay {
            display: none;
            position: fixed;
            top: 0; left: 0; right: 0; bottom: 0;
            background: rgba(15, 23, 42, 0.6);
            backdrop-filter: blur(4px);
            z-index: 99;
        }

        .logo-area { font-size: 16px; font-weight: 800; letter-spacing: -0.3px; padding-left: 12px; margin-bottom: 20px; display: flex; justify-content: space-between; align-items: center; }
        .close-sidebar-btn { display: none; background: transparent; border: none; color: #fff; font-size: 22px; cursor: pointer; }
        .nav-section-title { font-size: 10px; font-weight: 800; text-transform: uppercase; color: #64748b; letter-spacing: 0.5px; padding: 12px 12px 4px; }
        .nav-list { display: flex; flex-direction: column; gap: 4px; list-style: none; margin-bottom: 8px; }
        .nav-item { display: flex; align-items: center; gap: 10px; padding: 9px 12px; border-radius: 8px; color: #94a3b8; font-size: 12.5px; font-weight: 700; cursor: pointer; transition: all 0.2s ease; user-select: none; text-decoration: none; }
        .nav-item:hover { color: #fff; background: rgba(255,255,255,0.06); }
        .nav-item.active { background: var(--brand-primary); color: #fff; box-shadow: 0 4px 12px rgba(37,99,235,0.3); }
        .nav-icon { font-size: 14px; }
        .badge-count { margin-left: auto; background: #ef4444; color: white; padding: 2px 7px; border-radius: 12px; font-size: 10px; font-weight: 800; }
        .user-badge { padding: 12px; background: rgba(255,255,255,0.05); border-radius: 10px; font-size: 12px; margin-top: 16px; }
        .user-name { font-weight: 700; color: #fff; }
        .user-role { color: #94a3b8; font-size: 11px; margin-top: 2px; }

        /* MAIN CONTENT AREA */
/* MAIN CONTENT AREA */
.main-wrapper { 
    flex: 1; 
    min-width: 0; /* CRITICAL: Prevents horizontal overflow on flex children */
    display: flex; 
    flex-direction: column; 
    overflow-y: auto; 
    overflow-x: hidden;
    scroll-behavior: smooth; 
}
        .topbar { background: #fff; border-bottom: 1px solid var(--border-subtle); padding: 14px 28px; display: flex; justify-content: space-between; align-items: center; flex-shrink: 0; }
        .mobile-hamburger-btn { display: none; background: #f1f5f9; border: 1px solid var(--border-subtle); padding: 8px 12px; border-radius: 8px; font-size: 18px; cursor: pointer; margin-right: 12px; }

.content-area { 
    padding: 24px 28px; 
    display: flex; 
    flex-direction: column; 
    gap: 20px; 
    max-width: 100%; 
    width: 100%; 
}
        .card { 
            background: var(--surface-card); 
            border: 1px solid var(--border-subtle); 
            border-radius: 16px; 
            padding: 24px; 
            box-shadow: var(--shadow-card); 
        }
.grid-4 { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 16px; }
.grid-3 { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 16px; }
.grid-2 { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 16px; }
        /* KPI STAT CARDS */
        .stat-card {
            background: #ffffff;
            border: 1px solid var(--border-subtle);
            border-radius: 14px;
            padding: 18px 20px;
            position: relative;
            overflow: hidden;
            box-shadow: 0 1px 3px rgba(0,0,0,0.02);
            transition: transform 0.2s ease, box-shadow 0.2s ease;
        }
        .stat-card:hover { transform: translateY(-2px); box-shadow: var(--shadow-card); }
        .stat-card::before { content: ""; position: absolute; left: 0; top: 0; bottom: 0; width: 4.5px; }
        .stat-card.blue::before { background: var(--brand-primary); }
        .stat-card.green::before { background: var(--emerald); }
        .stat-card.amber::before { background: var(--amber); }
        .stat-card.purple::before { background: var(--purple); }
        .stat-card.rose::before { background: var(--rose); }
        .stat-val { font-size: 26px; font-weight: 800; margin-top: 6px; font-family: 'JetBrains Mono', monospace; }
        .stat-lbl { font-size: 11px; font-weight: 800; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.5px; }

        /* FORM INPUT STYLES */
        .field-group { display: flex; flex-direction: column; gap: 6px; }
        .field-label { font-size: 11px; font-weight: 800; color: #475569; text-transform: uppercase; letter-spacing: 0.3px; display: flex; justify-content: space-between; align-items: center; }
        .input-base, .form-input {
            height: 40px;
            border: 1.5px solid var(--border-subtle);
            border-radius: 8px;
            padding: 0 14px;
            font-size: 13px;
            background: #ffffff;
            outline: none;
            transition: all 0.2s ease;
            width: 100%;
        }
        .input-base:focus, .form-input:focus {
            border-color: var(--brand-primary);
            box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.12);
        }
        .mono-val { font-family: 'JetBrains Mono', monospace; font-weight: 600; }

/* TABLES & SLEEK SCROLLBARS */
.table-wrapper {
    border: 1px solid var(--border-subtle);
    border-radius: 12px;
    overflow-x: auto;
    background: #fff;
    width: 100%;
    scrollbar-width: thin;
    scrollbar-color: #cbd5e1 transparent;
}
.table-wrapper::-webkit-scrollbar { height: 6px; width: 6px; }
.table-wrapper::-webkit-scrollbar-track { background: transparent; }
.table-wrapper::-webkit-scrollbar-thumb { background: #cbd5e1; border-radius: 9999px; }
.table-wrapper::-webkit-scrollbar-thumb:hover { background: #94a3b8; }

table { width: 100%; border-collapse: collapse; font-size: 12.5px; }
th { text-align: left; padding: 11px 12px; background: #f8fafc; color: var(--text-muted); font-weight: 800; font-size: 10.5px; text-transform: uppercase; letter-spacing: 0.4px; border-bottom: 1.5px solid var(--border-subtle); white-space: nowrap; }
td { padding: 11px 12px; border-bottom: 1px solid var(--border-subtle); vertical-align: middle; }        tr:hover td { background-color: #fcfdfe; }

        .badge-pill { padding: 4px 12px; border-radius: 20px; font-size: 11px; font-weight: 800; display: inline-flex; align-items: center; gap: 4px; }
        .badge-green { background: #ecfdf5; color: #059669; border: 1px solid #a7f3d0; }
        .badge-amber { background: #fef3c7; color: #b45309; border: 1px solid #fde68a; }
        .badge-red { background: #fef2f2; color: #dc2626; border: 1px solid #fecaca; }
        .badge-gray { background: #f1f5f9; color: #475569; border: 1px solid #e2e8f0; }
        .badge-blue { background: #eff6ff; color: #2563eb; border: 1px solid #bfdbfe; }
        .badge-purple { background: #f5f3ff; color: #7c3aed; border: 1px solid #ddd6fe; }

        .btn-action { 
            height: 38px; 
            padding: 0 16px; 
            border-radius: 7px; 
            font-size: 12.5px; 
            font-weight: 700; 
            border: none; 
            cursor: pointer; 
            display: inline-flex; 
            align-items: center; 
            gap: 6px; 
            text-decoration: none; 
            transition: all 0.15s ease; 
        }
        .btn-approve { background: #ecfdf5; color: #059669; border: 1px solid #a7f3d0; }
        .btn-approve:hover { background: #d1fae5; }
        .btn-reject { background: #fef2f2; color: #dc2626; border: 1px solid #fecaca; }
        .btn-reject:hover { background: #fee2e2; }
        .btn-primary { 
            background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%); 
            color: #fff; 
            box-shadow: 0 3px 10px rgba(37, 99, 235, 0.25);
        }
        .btn-primary:hover { transform: translateY(-1px); box-shadow: 0 5px 14px rgba(37, 99, 235, 0.35); }
        .btn-emerald {
            background: linear-gradient(135deg, #10b981 0%, #059669 100%);
            color: #fff;
            box-shadow: 0 3px 10px rgba(16, 185, 129, 0.25);
        }
        .btn-emerald:hover { transform: translateY(-1px); }

        .alert { padding: 13px 18px; border-radius: 10px; font-size: 13px; font-weight: 700; display: flex; align-items: center; gap: 8px; }
        .alert-success { background: #ecfdf5; color: #065f46; border: 1px solid #a7f3d0; }
        .alert-error { background: #fef2f2; color: #991b1b; border: 1px solid #fecaca; }

        .tab-pane { display: none; }
        .tab-pane.active { display: flex; flex-direction: column; gap: 20px; animation: fadeIn 0.2s ease; }
        @keyframes fadeIn { from { opacity: 0; transform: translateY(4px); } to { opacity: 1; transform: translateY(0); } }

        .embedded-frame { width: 100%; height: 740px; border: 1px solid var(--border-subtle); border-radius: 12px; background: #fff; }

        .section-tag {
            font-size: 11.5px;
            font-weight: 800;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: var(--text-muted);
            margin: 20px 0 10px;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        .section-tag::after { content: ""; flex: 1; height: 1px; background: var(--border-subtle); }

        .calc-strip {
            background: #ffffff;
            border: 1px solid var(--border-subtle);
            border-left: 4.5px solid var(--brand-primary);
            border-radius: 12px;
            padding: 16px 20px;
            margin: 16px 0;
            box-shadow: 0 2px 4px rgba(0,0,0,0.02);
        }

        .hike-simulator {
            background: #ffffff;
            border: 1px solid var(--border-subtle);
            border-left: 4.5px solid var(--emerald);
            border-radius: 12px;
            padding: 16px 20px;
            margin-bottom: 16px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            flex-wrap: wrap;
            gap: 12px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.02);
        }
        .hike-btn {
            background: #f8fafc;
            border: 1.5px solid var(--border-subtle);
            color: #0f172a;
            font-weight: 800;
            font-size: 11.5px;
            padding: 6px 14px;
            border-radius: 6px;
            cursor: pointer;
            transition: all 0.15s;
        }
        .hike-btn:hover { background: #eff6ff; border-color: var(--brand-primary); color: var(--brand-primary); }

        /* Settings Rows */
        .setting-row {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 16px 0;
            border-bottom: 1px solid var(--border-subtle);
            gap: 20px;
        }
        .setting-row:last-child { border-bottom: none; }
        .setting-info { flex: 1; }
        .setting-title { font-size: 14px; font-weight: 700; color: var(--text-main); display: flex; align-items: center; gap: 8px; }
        .setting-title code { font-family: 'JetBrains Mono', monospace; font-size: 11px; background: #f1f5f9; padding: 2px 6px; border-radius: 4px; color: var(--text-muted); border: 1px solid var(--border-subtle); }
        .setting-desc { font-size: 12.5px; color: var(--text-muted); margin-top: 3px; }
        .setting-ctrl { display: flex; align-items: center; gap: 8px; }

        .toggle-group { display: inline-flex; background: #f1f5f9; padding: 3px; border-radius: 8px; border: 1px solid var(--border-subtle); }
        .toggle-opt { border: none; background: transparent; padding: 6px 14px; border-radius: 6px; font-size: 12px; font-weight: 700; color: var(--text-muted); cursor: pointer; }
        .toggle-opt.on { background: var(--emerald); color: #fff; }
        .toggle-opt.off { background: var(--rose); color: #fff; }

        .code-chip { font-family: 'JetBrains Mono', monospace; background: #f1f5f9; padding: 2px 7px; border-radius: 5px; font-size: 11.5px; border: 1px solid var(--border-subtle); }
        .payload-box { font-family: 'JetBrains Mono', monospace; background: #f8fafc; border: 1px solid var(--border-subtle); padding: 6px 10px; border-radius: 6px; font-size: 11px; max-width: 280px; white-space: pre-wrap; word-break: break-all; }

        .modal-overlay { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(15, 23, 42, 0.7); z-index: 1000; justify-content: center; align-items: center; padding: 20px; }
        .modal-content { background: #fff; width: 100%; max-width: 860px; height: 90vh; border-radius: 14px; display: flex; flex-direction: column; overflow: hidden; box-shadow: var(--shadow-float); }
        .modal-header { padding: 14px 20px; background: #0f172a; color: #fff; display: flex; justify-content: space-between; align-items: center; }
        .modal-iframe { flex: 1; border: none; width: 100%; height: 100%; }

        /* RESPONSIVE MOBILE VIEW MEDIA QUERIES */
        @media (max-width: 900px) {
            .mobile-hamburger-btn { display: inline-flex; align-items: center; justify-content: center; }
            .close-sidebar-btn { display: inline-block; }

            .sidebar {
                position: fixed;
                top: 0; bottom: 0; left: 0;
                transform: translateX(-100%);
                box-shadow: 10px 0 30px rgba(0, 0, 0, 0.5);
            }
            .sidebar.mobile-open { transform: translateX(0); }
            .sidebar-overlay.active { display: block; }

            .topbar { padding: 12px 16px; }
            .content-area { padding: 16px 12px; }

            .grid-4, .grid-3, .grid-2 { grid-template-columns: 1fr; }
            .stat-val { font-size: 22px; }
            .card { padding: 16px; border-radius: 12px; }
            .embedded-frame { height: 600px; }
            .desktop-only { display: none !important; }
            .setting-row { flex-direction: column; align-items: stretch; }
            .setting-ctrl { width: 100%; }

            div[style*="grid-template-columns: 340px 1fr;"] {
                display: flex !important;
                flex-direction: column !important;
            }
        }
    </style>
</head>
<body>

    <!-- Mobile Drawer Overlay -->
    <div id="sidebarOverlay" class="sidebar-overlay" onclick="toggleMobileSidebar()"></div>

    <!-- Unified Sidebar Navigation -->
    <aside class="sidebar" id="appSidebar">
        <div>
           <div class="logo-area">
                <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                    <% if (!cfgCompanyLogo.isEmpty()) { %>
                        <img src="<%= cfgCompanyLogo %>" alt="Logo" style="width: 30px; height: 30px; border-radius: 6px; object-fit: contain; background: #fff; padding: 2px; flex-shrink: 0;">
                    <% } %>
                    <span style="color: #fff; font-weight: 800; font-size: 14px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;" title="<%= cfgCompanyName %>">
                        <%= cfgCompanyName %>
                    </span>
                </div>
                <button type="button" class="close-sidebar-btn" onclick="toggleMobileSidebar()">&times;</button>
            </div>

            <!-- Dashboard & Audits Group -->
            <div class="nav-section-title">Dashboard & Audits</div>
            <ul class="nav-list">
                <li class="nav-item <%= "tab-overview".equals(activeTab) ? "active" : "" %>" onclick="switchAdminTab('tab-overview', this)">
                    <span class="nav-icon">📊</span> Overview
                </li>

                <% if (isAdmin) { %>
                    <li class="nav-item <%= "tab-taskmonitor".equals(activeTab) ? "active" : "" %>" onclick="switchAdminTab('tab-taskmonitor', this)">
                        <span class="nav-icon">📋</span> Task Audit
                    </li>
                <% } %>

                <li class="nav-item <%= "tab-perfaudits".equals(activeTab) ? "active" : "" %>" onclick="switchAdminTab('tab-perfaudits', this)">
                    <span class="nav-icon">🔍</span> Performance & Team Audits
                </li>
               
                <% if (isHr) { %>
                    <li class="nav-item <%= "tab-leaveapprovals".equals(activeTab) ? "active" : "" %>" onclick="switchAdminTab('tab-leaveapprovals', this)">
                        <span class="nav-icon">📝</span> Leave Approvals
                        <% if (pendingLeaves != null && !pendingLeaves.isEmpty()) { %>
                            <span class="badge-count"><%= pendingLeaves.size() %></span>
                        <% } %>
                    </li>
                <% } %>
            </ul>

            <!-- Payroll & Finance Group -->
            <div class="nav-section-title">Payroll & Finance</div>
            <ul class="nav-list">
                <li class="nav-item <%= "tab-allpayslips".equals(activeTab) ? "active" : "" %>" onclick="switchAdminTab('tab-allpayslips', this)">
                    <span class="nav-icon">📋</span> All Payslips
                </li>

                <% if (isHr) { %>
                    <li class="nav-item <%= "tab-structure".equals(activeTab) ? "active" : "" %>" onclick="switchAdminTab('tab-structure', this)">
                        <span class="nav-icon">⚙</span> Structure Setup
                    </li>
                    <li class="nav-item <%= "tab-processcycle".equals(activeTab) ? "active" : "" %>" onclick="switchAdminTab('tab-processcycle', this)">
                        <span class="nav-icon">🧮</span> Process Monthly Cycle
                    </li>
                    <li class="nav-item <%= "tab-financemis".equals(activeTab) ? "active" : "" %>" onclick="switchAdminTab('tab-financemis', this)">
                        <span class="nav-icon">📈</span> MIS & Audit Reports
                    </li>
                <% } %>
            </ul>

            <!-- Attendance Group -->
            <div class="nav-section-title">Attendance</div>
            <ul class="nav-list">
                <li class="nav-item <%= "tab-selfatt".equals(activeTab) ? "active" : "" %>" onclick="switchAdminTab('tab-selfatt', this)">
                    <span class="nav-icon">⏱</span> Self Attendance
                </li>
                <li class="nav-item <%= "tab-dailyroster".equals(activeTab) ? "active" : "" %>" onclick="switchAdminTab('tab-dailyroster', this)">
                    <span class="nav-icon">📅</span> Daily Roster Report
                </li>
                <li class="nav-item <%= "tab-monthlyanalytics".equals(activeTab) ? "active" : "" %>" onclick="switchAdminTab('tab-monthlyanalytics', this)">
                    <span class="nav-icon">📈</span> Monthly Analytics
                </li>
            </ul>

            <% if (isAdmin) { %>
                <!-- Organization & Teams Group -->
                <div class="nav-section-title">Organization & Teams</div>
                <ul class="nav-list">
                    <li class="nav-item <%= "tab-teamscatalog".equals(activeTab) ? "active" : "" %>" onclick="switchAdminTab('tab-teamscatalog', this)">
                        <span class="nav-icon">👥</span> Teams Catalog
                    </li>
                    <li class="nav-item <%= "tab-addmanager".equals(activeTab) ? "active" : "" %>" onclick="switchAdminTab('tab-addmanager', this)">
                        <span class="nav-icon">👤</span> + Add Manager
                    </li>
                    <li class="nav-item <%= "tab-addemployee".equals(activeTab) ? "active" : "" %>" onclick="switchAdminTab('tab-addemployee', this)">
                        <span class="nav-icon">👤</span> + Add Employee
                    </li>
                    <li class="nav-item <%= "tab-createteam".equals(activeTab) ? "active" : "" %>" onclick="switchAdminTab('tab-createteam', this)">
                        <span class="nav-icon">➕</span> + Create Team
                    </li>
                </ul>

                <!-- NATIVE IN-PAGE SYSTEM & SECURITY SECTION -->
                <div class="nav-section-title" style="color: #60a5fa; font-weight: 800;">System & Security</div>
                <ul class="nav-list">
                    <li class="nav-item <%= "tab-sysdash".equals(activeTab) ? "active" : "" %>" onclick="switchAdminTab('tab-sysdash', this)">
                        <span class="nav-icon">💻</span> System Dashboard
                    </li>
                    <li class="nav-item <%= "tab-sysaudit".equals(activeTab) ? "active" : "" %>" onclick="switchAdminTab('tab-sysaudit', this)">
                        <span class="nav-icon">📜</span> Audit Logs
                    </li>
                    <li class="nav-item <%= "tab-syslogin".equals(activeTab) ? "active" : "" %>" onclick="switchAdminTab('tab-syslogin', this)">
                        <span class="nav-icon">🔑</span> Login History
                    </li>
                    <li class="nav-item <%= "tab-syssettings".equals(activeTab) ? "active" : "" %>" onclick="switchAdminTab('tab-syssettings', this)">
                        <span class="nav-icon">⚙</span> Settings
                    </li>
                    <li class="nav-item <%= "tab-syserrors".equals(activeTab) ? "active" : "" %>" onclick="switchAdminTab('tab-syserrors', this)">
                        <span class="nav-icon">⚠</span> Errors
                    </li>
                    <li class="nav-item <%= "tab-sysbackups".equals(activeTab) ? "active" : "" %>" onclick="switchAdminTab('tab-sysbackups', this)">
                        <span class="nav-icon">💾</span> Backups
                    </li>
                </ul>
            <% } %>
        </div>
        
        <div class="user-badge">
            <div class="user-name"><%= loggedIn.getName() %></div>
            <div class="user-role"><%= loggedIn.getEmployeeId() %> • <strong><%= userRole %></strong></div>
        </div>
    </aside>

    <!-- Main Workspace Container -->
    <div class="main-wrapper">
        <header class="topbar">
            <div style="display: flex; align-items: center;">
                <button type="button" class="mobile-hamburger-btn" onclick="toggleMobileSidebar()">☰</button>
                <div>
                    <h2 id="adminHeaderTitle" style="font-size: 18px; font-weight: 800;">Overview</h2>
                    <div style="font-size: 11px; color: var(--text-muted); margin-top: 1px;">Live operations, payroll & security console</div>
                </div>
            </div>
            <div style="display: flex; align-items: center; gap: 14px; font-size: 12.5px;">
                <span style="color: var(--text-muted);" class="desktop-only">Audit Date: <strong><%= java.time.LocalDate.now().format(java.time.format.DateTimeFormatter.ofPattern("EEEE, d MMMM yyyy")) %></strong></span>
                <a href="<%= request.getContextPath() %>/logout" style="color: #ef4444; font-weight: 700; text-decoration: none; padding: 6px 12px; border-radius: 6px; background: #fef2f2;">Sign Out</a>
            </div>
        </header>

        <div class="content-area">
            <% if (toastMsg != null && !toastMsg.isBlank()) { %><div class="alert alert-success">✔ <%= toastMsg %></div><% } %>
            <% if (toastErr != null && !toastErr.isBlank()) { %><div class="alert alert-error">⚠ <%= toastErr %></div><% } %>

            <!-- ===================================================================
                 TAB 1: OVERVIEW METRICS & CONTROLS
                 =================================================================== -->
            <div id="tab-overview" class="tab-pane <%= "tab-overview".equals(activeTab) ? "active" : "" %>">
                <div class="grid-4">
                    <div class="stat-card blue">
                        <div class="stat-lbl">Active Headcount</div>
                        <div class="stat-val" style="color: var(--brand-primary);"><%= activeHeadcount %></div>
                    </div>
                    <div class="stat-card green">
                        <div class="stat-lbl">Present Today</div>
                        <div class="stat-val" style="color: #059669;"><%= presentToday %></div>
                    </div>
                    <div class="stat-card amber">
                        <div class="stat-lbl">Shift In-Progress</div>
                        <div class="stat-val" style="color: #d97706;"><%= inProgressToday %></div>
                    </div>
                    <% if (isHr) { %>
                        <div class="stat-card purple">
                            <div class="stat-lbl">Pending Leaves</div>
                            <div class="stat-val" style="color: #dc2626;"><%= (pendingLeaves != null) ? pendingLeaves.size() : 0 %></div>
                        </div>
                    <% } else { %>
                        <div class="stat-card purple">
                            <div class="stat-lbl">System Role</div>
                            <div class="stat-val" style="color: var(--brand-primary); font-size: 20px;">ADMIN</div>
                        </div>
                    <% } %>
                </div>

                <div class="grid-4">
                    <div class="stat-card blue">
                        <div class="stat-lbl">Total Tasks Logged</div>
                        <div class="stat-val"><%= totalTasks %></div>
                    </div>
                    <div class="stat-card green">
                        <div class="stat-lbl">Completed Deliverables</div>
                        <div class="stat-val" style="color: #059669;"><%= completedTasks %></div>
                    </div>
                    <div class="stat-card purple">
                        <div class="stat-lbl">Pending Review</div>
                        <div class="stat-val" style="color: #7c3aed;"><%= pendingReviews %></div>
                    </div>
                    <div class="stat-card amber">
                        <div class="stat-lbl">Avg Quality Rating</div>
                        <div class="stat-val" style="color: #d97706;"><%= (ratedCount > 0) ? String.format("%.1f", avgRating) + " ★" : "--" %></div>
                    </div>
                </div>

                <div class="card" style="border-left: 4.5px solid var(--brand-primary); display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 12px;">
                    <div>
                        <h3 style="font-size: 16px; font-weight: 800; color: #1e3a8a;">Quick Operations Ready</h3>
                        <p style="font-size: 13px; color: var(--text-muted); margin-top: 2px;">
                            Workforce payroll cycles, automated PDF vouchers, and security auditing are operating smoothly.
                        </p>
                    </div>
                    <% if (isHr) { %>
                        <button type="button" class="btn-action btn-primary" onclick="switchAdminTab('tab-processcycle')">
                            Open Payroll Engine →
                        </button>
                    <% } else { %>
                        <button type="button" class="btn-action btn-primary" onclick="switchAdminTab('tab-sysdash')">
                            Open System & Security Center →
                        </button>
                    <% } %>
                </div>
            </div>

            <!-- ===================================================================
                 TAB 2: STRUCTURE SETUP (Full Original Engine Preserved)
                 =================================================================== -->
            <% if (isHr) { %>
            <div id="tab-structure" class="tab-pane <%= "tab-structure".equals(activeTab) ? "active" : "" %>">
                <div class="card" style="border-left: 4.5px solid var(--brand-primary);">
                    <div style="display: flex; justify-content: space-between; align-items: center; border-bottom: 1.5px solid var(--border-subtle); padding-bottom: 16px; margin-bottom: 22px;">
                        <div>
                            <h3 style="font-size: 18px; font-weight: 800; color: #1e3a8a;">
                                ⚙ Baseline Salary Architecture Setup
                            </h3>
                            <p style="font-size: 12px; color: var(--text-muted); margin-top: 2px;">
                                Type an Employee ID to populate details, configure allowances, test salary hikes, and commit baseline.
                            </p>
                        </div>
                        <span class="badge-pill badge-blue">Direct Auto-Sync</span>
                    </div>

                    <form method="post" action="<%= request.getContextPath() %>/payroll/salary-structure">
                        <div class="grid-2" style="margin-bottom: 20px;">
                            <div class="field-group">
                                <label class="field-label">Target Employee ID <span style="color:#2563eb;">*</span></label>
                                <input type="text" id="inlineEmpIdInput" name="employeeId" class="input-base mono-val" 
                                       placeholder="e.g. EMP104, EMP101, ADMIN01" 
                                       oninput="handleInlineEmpIdInput(this.value)" 
                                       autocomplete="off" required>
                                <div id="inlineFetchStatus" style="font-size: 12px; font-weight: 700; min-height: 18px; margin-top: 3px;"></div>
                            </div>
                            <div class="field-group">
                                <label class="field-label">Employee Email (For Automated Payslip Delivery)</label>
                                <input type="email" id="inlineEmpEmail" name="email" class="input-base" placeholder="e.g. employee@outlook.com, employee@gmail.com">
                            </div>
                        </div>

                        <div class="section-tag">Identity Profile</div>
                        <div class="grid-4" style="background: #f8fafc; border: 1.5px solid var(--border-subtle); border-radius: 12px; padding: 18px; margin-bottom: 20px;">
                            <div class="field-group">
                                <label class="field-label">Employee Name</label>
                                <input type="text" id="inlineEmpName" class="input-base" readonly placeholder="Auto-populated" style="background: transparent; border: none; font-weight: 700;">
                            </div>
                            <div class="field-group">
                                <label class="field-label">Department</label>
                                <input type="text" id="inlineDepartment" class="input-base" readonly placeholder="Auto-populated" style="background: transparent; border: none; font-weight: 700;">
                            </div>
                            <div class="field-group">
                                <label class="field-label">Designation / Role</label>
                                <input type="text" id="inlineDesignation" class="input-base" readonly placeholder="Auto-populated" style="background: transparent; border: none; font-weight: 700;">
                            </div>
                            <div class="field-group">
                                <label class="field-label">Joining Date</label>
                                <input type="text" id="inlineJoiningDate" class="input-base" readonly placeholder="Auto-populated" style="background: transparent; border: none; font-weight: 700;">
                            </div>
                        </div>

                        <div class="section-tag">Bank Account Disbursement Details</div>
                        <div class="grid-2">
                            <div class="field-group">
                                <label class="field-label">Bank Name</label>
                                <input type="text" id="inlineBankName" name="bankName" class="input-base" placeholder="e.g. HDFC Bank, SBI, ICICI" required>
                            </div>
                            <div class="field-group">
                                <label class="field-label">Account Number</label>
                                <input type="text" id="inlineBankAccount" name="bankAccount" class="input-base mono-val" 
                                       placeholder="e.g. 50100870325198" 
                                       oninput="checkDuplicateAccount(this.value)" 
                                       autocomplete="off" required>
                                <div id="accountErrorMsg" style="font-size: 11.5px; font-weight: 700; min-height: 18px; margin-top: 3px;"></div>
                            </div>
                        </div>

                        <div class="calc-strip">
                            <div style="font-size: 13px; font-weight: 800; color: #1e40af; margin-bottom: 12px;">
                                💰 Package Input (Enter Annual CTC or Monthly Gross)
                            </div>
                            <div class="grid-2">
                                <div class="field-group">
                                    <label class="field-label" style="color: #1e40af;">Annual CTC Package (INR)</label>
                                    <input type="number" step="1" id="inlineAnnualCtc" class="input-base mono-val" placeholder="e.g. 480000" oninput="calculateInlineFromAnnual(this.value)">
                                </div>
                                <div class="field-group">
                                    <label class="field-label" style="color: #1e40af;">Monthly Gross Baseline (INR)</label>
                                    <input type="number" step="0.01" id="inlineMonthlyGross" class="input-base mono-val" placeholder="e.g. 40000" oninput="calculateInlineFromMonthly(this.value)">
                                </div>
                            </div>
                            <p style="font-size: 11px; color: #64748b; margin-top: 8px;">
                                Standard Split: Basic (37.15%) | DA (55% of Basic) | HRA (50% of Basic) | Conveyance (₹1,600) | Medical (₹1,250) | Special Allowance (Residual) | PT (₹200) | PF (₹3,600 or 12%).
                            </p>
                        </div>

                        <div class="hike-simulator">
                            <div>
                                <span style="font-size: 13px; font-weight: 800; color: #059669;">🚀 Salary Hike Simulator:</span>
                                <span style="font-size: 11.5px; color: #64748b; margin-left: 6px;">Quickly scale current CTC baseline</span>
                            </div>
                            <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
                                <button type="button" class="hike-btn" onclick="applyPercentageHike(5)">+5%</button>
                                <button type="button" class="hike-btn" onclick="applyPercentageHike(10)">+10%</button>
                                <button type="button" class="hike-btn" onclick="applyPercentageHike(15)">+15%</button>
                                <button type="button" class="hike-btn" onclick="applyPercentageHike(20)">+20%</button>
                                <div style="display: flex; align-items: center; gap: 4px; margin-left: 8px;">
                                    <input type="number" id="customHikePct" placeholder="Custom %" style="width: 80px; height: 32px; border: 1.5px solid var(--border-subtle); border-radius: 6px; padding: 0 8px; font-size: 12px; font-weight: 700;">
                                    <button type="button" class="hike-btn" onclick="applyPercentageHike(document.getElementById('customHikePct').value)">Apply</button>
                                </div>
                            </div>
                        </div>

                        <div class="section-tag">
                            Calculated Monthly Breakdown (Toggle Checkboxes to Add / Remove Components)
                        </div>
                        
                        <div class="grid-4">
                            <div class="field-group">
                                <label class="field-label">
                                    <span>BASIC PAY</span>
                                    <span style="font-size: 10px; color: #2563eb;">CORE</span>
                                </label>
                                <input type="number" step="0.01" name="basic" id="inlineBasic" class="input-base mono-val" required>
                            </div>
                            <div class="field-group">
                                <label class="field-label">
                                    <span>DA</span>
                                    <label style="font-size: 10px; font-weight: 700; cursor: pointer; text-transform: none;">
                                        <input type="checkbox" id="toggle_da" checked onchange="toggleComponent('inlineDa', this.checked)"> Enable
                                    </label>
                                </label>
                                <input type="number" step="0.01" name="da" id="inlineDa" class="input-base mono-val">
                            </div>
                            <div class="field-group">
                                <label class="field-label">
                                    <span>HRA</span>
                                    <label style="font-size: 10px; font-weight: 700; cursor: pointer; text-transform: none;">
                                        <input type="checkbox" id="toggle_hra" checked onchange="toggleComponent('inlineHra', this.checked)"> Enable
                                    </label>
                                </label>
                                <input type="number" step="0.01" name="hra" id="inlineHra" class="input-base mono-val">
                            </div>
                            <div class="field-group">
                                <label class="field-label">
                                    <span>CONVEYANCE</span>
                                    <label style="font-size: 10px; font-weight: 700; cursor: pointer; text-transform: none;">
                                        <input type="checkbox" id="toggle_conveyance" checked onchange="toggleComponent('inlineConveyance', this.checked)"> Enable
                                    </label>
                                </label>
                                <input type="number" step="0.01" name="conveyance" id="inlineConveyance" class="input-base mono-val" value="1600">
                            </div>
                        </div>

                        <div class="grid-4" style="margin-top: 14px;">
                            <div class="field-group">
                                <label class="field-label">
                                    <span>MEDICAL ALLOWANCE</span>
                                    <label style="font-size: 10px; font-weight: 700; cursor: pointer; text-transform: none;">
                                        <input type="checkbox" id="toggle_medical" checked onchange="toggleComponent('inlineMedical', this.checked)"> Enable
                                    </label>
                                </label>
                                <input type="number" step="0.01" name="medical" id="inlineMedical" class="input-base mono-val" value="1250">
                            </div>
                            <div class="field-group">
                                <label class="field-label">
                                    <span>SPECIAL ALLOWANCE</span>
                                    <label style="font-size: 10px; font-weight: 700; cursor: pointer; text-transform: none;">
                                        <input type="checkbox" id="toggle_special" checked onchange="toggleComponent('inlineSpecial', this.checked)"> Enable
                                    </label>
                                </label>
                                <input type="number" step="0.01" name="special" id="inlineSpecial" class="input-base mono-val">
                            </div>
                            <div class="field-group">
                                <label class="field-label">
                                    <span>PROF TAX (PT)</span>
                                </label>
                                <input type="number" step="0.01" name="profTax" id="inlineProfTax" class="input-base mono-val" value="200">
                            </div>
                            <div class="field-group">
                                <label class="field-label">
                                    <span>PF</span>
                                </label>
                                <input type="number" step="0.01" name="pf" id="inlinePf" class="input-base mono-val" value="3600">
                            </div>
                        </div>

                        <div style="background: #ffffff; border: 1px solid var(--border-subtle); border-left: 4.5px solid var(--amber); border-radius: 14px; padding: 22px; margin-top: 24px;">
                            <div style="font-size: 13.5px; font-weight: 800; color: #b45309; margin-bottom: 12px; display: flex; align-items: center; gap: 8px;">
                                <span>🎉</span> Festival / Specific Month Discretionary Bonus
                            </div>
                            <div class="grid-2">
                                <div class="field-group">
                                    <label class="field-label" style="color: #92400e;">Bonus Amount (INR)</label>
                                    <input type="number" step="0.01" name="bonusAmount" class="input-base mono-val" placeholder="e.g. 10000 or leave 0" style="background:#ffffff;">
                                </div>
                                <div class="field-group">
                                    <label class="field-label" style="color: #92400e;">Target Bonus Month</label>
                                    <select name="bonusMonth" class="input-base" style="background:#ffffff;">
                                        <option value="0">None / Standard Payroll Cycle</option>
                                        <% for (int m = 1; m <= 12; m++) { 
                                            String mName = Month.of(m).getDisplayName(TextStyle.FULL, Locale.ENGLISH);
                                        %>
                                            <option value="<%= m %>"><%= mName %> Special Bonus</option>
                                        <% } %>
                                    </select>
                                </div>
                            </div>
                        </div>

                        <button type="submit" id="commitStructureBtn" class="btn-action btn-primary" style="width: 100%; height: 46px; justify-content: center; font-size: 14px; border-radius: 9px; margin-top: 24px;">
                            Commit Baseline & Bank Details →
                        </button>
                    </form>
                </div>
            </div>
            <% } %>

            <!-- ===================================================================
                 TAB 3: PROCESS MONTHLY CYCLE (Full Original Disbursement & Terminal)
                 =================================================================== -->
            <% if (isHr) { %>
            <div id="tab-processcycle" class="tab-pane <%= "tab-processcycle".equals(activeTab) ? "active" : "" %>">
                <div class="card" style="border-left: 4.5px solid var(--emerald);">
                    <div style="display: flex; justify-content: space-between; align-items: center; border-bottom: 1.5px solid var(--border-subtle); padding-bottom: 16px; margin-bottom: 22px;">
                        <div>
                            <h3 style="font-size: 18px; font-weight: 800; color: #1e3a8a;">⚙ Payroll Calculation Terminal</h3>
                            <p style="font-size: 12.5px; color: var(--text-muted); margin-top: 2px;">
                                Compute attendance-linked salaries with 1 Sick + 1 Casual paid leave allowance logic.
                            </p>
                        </div>
                        <span class="badge-pill badge-green">Engine Online</span>
                    </div>

                    <!-- Inline Disbursement Card -->
                    <div id="inlineDisbursePanel" style="display: none; background: #ffffff; border: 2px solid #2563eb; border-radius: 14px; padding: 22px; margin-bottom: 24px; box-shadow: var(--shadow-float);">
                        <div style="display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid var(--border-subtle); padding-bottom: 12px; margin-bottom: 16px;">
                            <div>
                                <h4 style="font-size: 16px; font-weight: 800; color: #1e3a8a;">Disbursement & Payout Confirmation</h4>
                                <p style="font-size: 12px; color: var(--text-muted); margin-top: 2px;">Record transactional reference numbers and finalize disbursement.</p>
                            </div>
                            <button type="button" onclick="closeInlineDisburse()" style="background: transparent; border: 1px solid var(--border-subtle); padding: 5px 12px; border-radius: 6px; cursor: pointer; font-size: 12px; font-weight: 700;">
                                ✕ Close
                            </button>
                        </div>

                        <div style="background: #eff6ff; border: 1px solid #bfdbfe; border-radius: 10px; padding: 14px 18px; display: grid; grid-template-columns: repeat(4, 1fr); gap: 14px; margin-bottom: 18px;">
                            <div>
                                <div style="font-size: 10.5px; font-weight: 800; color: #1e40af; text-transform: uppercase;">Employee</div>
                                <div id="disburseEmpLabel" style="font-size: 14px; font-weight: 800; color: #0f172a; margin-top: 2px;">--</div>
                            </div>
                            <div>
                                <div style="font-size: 10.5px; font-weight: 800; color: #1e40af; text-transform: uppercase;">Payroll Period</div>
                                <div id="disbursePeriodLabel" style="font-size: 14px; font-weight: 800; color: #0f172a; margin-top: 2px;">--</div>
                            </div>
                            <div>
                                <div style="font-size: 10.5px; font-weight: 800; color: #1e40af; text-transform: uppercase;">Bank Account</div>
                                <div id="disburseBankLabel" style="font-size: 13px; font-weight: 800; color: #0f172a; margin-top: 2px;">--</div>
                            </div>
                            <div>
                                <div style="font-size: 10.5px; font-weight: 800; color: #1e40af; text-transform: uppercase;">Net Payable Amount</div>
                                <div id="disburseAmountLabel" style="font-size: 16px; font-weight: 800; color: #059669; font-family: 'JetBrains Mono', monospace; margin-top: 2px;">₹ 0.00</div>
                            </div>
                        </div>

                        <form method="post" action="<%= request.getContextPath() %>/payroll/payment">
                            <input type="hidden" name="payrollId" id="disbursePayrollId">
                            <div style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 16px; margin-bottom: 18px;">
                                <div class="field-group">
                                    <label class="field-label">Disbursement Method</label>
                                    <select name="paymentMethod" class="input-base" required>
                                        <option value="Corporate UPI">Corporate UPI</option>
                                        <option value="NEFT / RTGS" selected>NEFT / RTGS</option>
                                        <option value="IMPS">IMPS</option>
                                        <option value="Direct Bank Transfer">Direct Bank Transfer</option>
                                    </select>
                                </div>
                                <div class="field-group">
                                    <label class="field-label">Transaction / UTR Reference ID</label>
                                    <input type="text" name="referenceNumber" class="input-base mono-val" placeholder="e.g. UTR20261102984128" required autocomplete="off">
                                </div>
                                <div class="field-group">
                                    <label class="field-label">Disbursement Date</label>
                                    <input type="date" name="paymentDate" class="input-base" value="<%= java.time.LocalDate.now() %>" required>
                                </div>
                            </div>
                            <button type="submit" class="btn-action btn-primary" style="width: 100%; height: 44px; justify-content: center; font-size: 13.5px; border-radius: 8px;">
                                Record Payment & Mark as Disbursed →
                            </button>
                        </form>
                    </div>

                    <div style="display: grid; grid-template-columns: 340px 1fr; gap: 24px;">
                        <div style="background: #f8fafc; border: 1.5px solid var(--border-subtle); border-radius: 12px; padding: 22px;">
                            <h4 style="font-size: 14.5px; font-weight: 800; margin-bottom: 14px; color: var(--text-main); display: flex; align-items: center; gap: 8px;">
                                <span>⚡</span> Execute Calculation
                            </h4>
                            <form method="post" action="<%= request.getContextPath() %>/payroll/process">
                                <div class="field-group" style="margin-bottom: 14px;">
                                    <label class="field-label">Target Employee ID (or "ALL")</label>
                                    <input type="text" name="employeeId" class="input-base mono-val" 
                                           value="<%= (reqEmpId != null && !reqEmpId.isBlank()) ? reqEmpId : "ALL" %>" 
                                           placeholder="e.g. EMP104 or ALL" required>
                                </div>
                                <div class="field-group" style="margin-bottom: 14px;">
                                    <label class="field-label">Payroll Month</label>
                                    <select name="month" class="input-base" required>
                                        <% for (int m = 1; m <= 12; m++) { 
                                            String mName = Month.of(m).getDisplayName(TextStyle.FULL, Locale.ENGLISH);
                                        %>
                                            <option value="<%= m %>" <%= (m == currentMonthVal) ? "selected" : "" %>><%= mName %></option>
                                        <% } %>
                                    </select>
                                </div>
                                <div class="field-group" style="margin-bottom: 18px;">
                                    <label class="field-label">Payroll Year</label>
                                    <input type="number" name="year" class="input-base mono-val" value="<%= currentYearVal %>" required>
                                </div>
                                <button type="submit" class="btn-action btn-primary" style="width: 100%; height: 42px; justify-content: center; font-size: 13px;" onclick="return confirm('Execute payroll calculation for this cycle?');">
                                    ⚙ Compute & Commit Record
                                </button>
                            </form>
                        </div>

                        <div>
                            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px;">
                                <h4 style="font-size: 14px; font-weight: 800; color: var(--text-main);">Current Cycle Processed Records</h4>
                                <span style="font-size: 11.5px; font-weight: 700; color: var(--text-muted);">Showing: <strong><%= payrollList != null ? payrollList.size() : 0 %> records</strong></span>
                            </div>

                            <div class="table-wrapper">
                                <table>
                                    <thead>
                                        <tr>
                                            <th>Emp ID</th>
                                            <th>Present / Total</th>
                                            <th>LOP</th>
                                            <th style="text-align: right;">Net Pay</th>
                                            <th style="text-align: center;">Status</th>
                                            <th style="text-align: center;">Payment</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        <% if (payrollList != null && !payrollList.isEmpty()) { 
                                            for (Payroll py : payrollList) { 
                                                boolean isPaid = "PAID".equalsIgnoreCase(py.getStatus());
                                                String periodTxt = Month.of(py.getPayrollMonth()).getDisplayName(TextStyle.FULL, Locale.ENGLISH) + " " + py.getPayrollYear();
                                                String netFormatted = String.format("%.2f", py.getNetSalary() != null ? py.getNetSalary() : java.math.BigDecimal.ZERO);
                                        %>
                                            <tr>
                                                <td class="mono-val" style="font-weight: 800; color: var(--brand-primary);"><%= py.getEmployeeId() %></td>
                                                <td><strong><%= py.getPresentDays() %></strong> / <%= py.getWorkingDays() %></td>
                                                <td style="color: <%= py.getUnpaidLeaveDays() > 0 ? "#dc2626" : "#64748b" %>; font-weight: 800;">
                                                    <%= py.getUnpaidLeaveDays() %>
                                                </td>
                                                <td class="mono-val" style="text-align: right; font-weight: 800; color: #0f172a;">
                                                    ₹ <%= netFormatted %>
                                                </td>
                                                <td style="text-align: center;">
                                                    <span class="badge-pill <%= isPaid ? "badge-green" : "badge-amber" %>">
                                                        <%= py.getStatus() != null ? py.getStatus() : "PROCESSED" %>
                                                    </span>
                                                </td>
                                                <td style="text-align: center;">
                                                    <% if (!isPaid) { %>
                                                        <button type="button" 
                                                                onclick="openInlineDisburse('<%= py.getId() %>', '<%= py.getEmployeeId() %>', '<%= periodTxt %>', '<%= netFormatted %>')" 
                                                                class="btn-action" 
                                                                style="background: #eff6ff; color: #2563eb; padding: 4px 12px; font-size: 11.5px; border: 1.5px solid #bfdbfe; border-radius: 6px; cursor: pointer; font-weight: 800;">
                                                            Disburse
                                                        </button>
                                                    <% } else { %>
                                                        <span style="font-size: 11.5px; color: #059669; font-weight: 800;">✔ Disbursed</span>
                                                    <% } %>
                                                </td>
                                            </tr>
                                        <%  } 
                                            } else { %>
                                            <tr>
                                                <td colspan="6" style="text-align: center; color: var(--text-muted); padding: 36px;">
                                                    No records processed for this monthly cycle yet.
                                                </td>
                                            </tr>
                                        <% } %>
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            <% } %>

            <!-- ===================================================================
                 TAB 4: FINANCE MIS REPORTS, CTC BREAKDOWNS & AUDIT TRAILS
                 =================================================================== -->
            <% if (isHr) { 
                String misMonthName = Month.of(currentMonthVal).getDisplayName(TextStyle.FULL, Locale.ENGLISH);
            %>
            <div id="tab-financemis" class="tab-pane <%= "tab-financemis".equals(activeTab) ? "active" : "" %>">
                <div class="card" style="border-left: 4.5px solid var(--purple);">
                    <div style="display: flex; justify-content: space-between; align-items: center; border-bottom: 1.5px solid var(--border-subtle); padding-bottom: 16px; margin-bottom: 24px; flex-wrap: wrap; gap: 12px;">
                        <div>
                            <h3 style="font-size: 19px; font-weight: 800; color: #1e3a8a; letter-spacing: -0.3px;">
                                📈 Finance Management Information System (MIS) & CTC Analytics
                            </h3>
                            <p style="font-size: 12.5px; color: var(--text-muted); margin-top: 3px;">
                                High-level executive reconciliation of salary liability, statutory tax pools, and transaction audit trails.
                            </p>
                        </div>
                        <form method="get" action="<%= request.getContextPath() %>/dashboard.jsp" style="display: flex; gap: 8px; align-items: center;">
                            <input type="hidden" name="tab" value="tab-financemis">
                            <select name="month" class="form-input" style="height: 38px; width: 140px;">
                                <% for (int m = 1; m <= 12; m++) { 
                                    String mName = Month.of(m).getDisplayName(TextStyle.FULL, Locale.ENGLISH);
                                %>
                                    <option value="<%= m %>" <%= (m == currentMonthVal) ? "selected" : "" %>><%= mName %></option>
                                <% } %>
                            </select>
                            <input type="number" name="year" class="form-input mono-val" value="<%= currentYearVal %>" style="height: 38px; width: 90px;" required>
                            <button type="submit" class="btn-action btn-primary" style="height: 38px;">Apply Filter</button>
                        </form>
                    </div>

                    <div class="grid-4" style="margin-bottom: 24px;">
                        <div class="stat-card blue">
                            <div class="stat-lbl">Monthly CTC Liability</div>
                            <div class="stat-val" style="color: var(--brand-primary); font-size: 22px;">
                                ₹ <%= String.format("%.2f", misReport.getTotalEstimatedCtc()) %>
                            </div>
                            <span style="font-size: 10.5px; color: var(--text-muted); font-weight: 700;">Gross + Employer Share</span>
                        </div>
                        <div class="stat-card green">
                            <div class="stat-lbl">Total Net Disbursed</div>
                            <div class="stat-val" style="color: #059669; font-size: 22px;">
                                ₹ <%= String.format("%.2f", misReport.getTotalNetDisbursed()) %>
                            </div>
                            <span style="font-size: 10.5px; color: #059669; font-weight: 700;">
                                <%= misReport.getTotalDisbursedCount() %> Disbursed
                            </span>
                        </div>
                        <div class="stat-card purple">
                            <div class="stat-lbl">Statutory PF Pool</div>
                            <div class="stat-val" style="color: #7c3aed; font-size: 22px;">
                                ₹ <%= String.format("%.2f", misReport.getTotalPfContribution()) %>
                            </div>
                            <span style="font-size: 10.5px; color: var(--text-muted); font-weight: 700;">EPFO Remittance</span>
                        </div>
                        <div class="stat-card amber">
                            <div class="stat-lbl">Professional Tax (PT)</div>
                            <div class="stat-val" style="color: #d97706; font-size: 22px;">
                                ₹ <%= String.format("%.2f", misReport.getTotalPtDeduction()) %>
                            </div>
                            <span style="font-size: 10.5px; color: var(--text-muted); font-weight: 700;">State Tax Pool</span>
                        </div>
                    </div>

                    <div style="background: #ffffff; border: 1.5px solid var(--border-subtle); border-radius: 14px; padding: 22px; margin-bottom: 28px;">
                        <h4 style="font-size: 14.5px; font-weight: 800; color: #1e3a8a; margin-bottom: 14px;">
                            📊 <%= misMonthName %> <%= currentYearVal %> Cost-to-Company (CTC) Component Statement
                        </h4>
                        <div class="table-wrapper">
                            <table>
                                <thead>
                                    <tr>
                                        <th>Financial Component Description</th>
                                        <th>Classification</th>
                                        <th>Impact</th>
                                        <th style="text-align: right;">Period Subtotal (INR)</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <tr>
                                        <td><strong>Gross Direct Salary Obligations</strong></td>
                                        <td><span class="badge-pill badge-blue">Direct Compensation</span></td>
                                        <td>Company Expense</td>
                                        <td class="mono-val" style="text-align: right; font-weight: 700;">
                                            ₹ <%= String.format("%.2f", misReport.getTotalGrossPayout()) %>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td><strong>Employee Provident Fund (EPF Matching Pool)</strong></td>
                                        <td><span class="badge-pill badge-purple">Statutory Liability</span></td>
                                        <td>Remittance Due</td>
                                        <td class="mono-val" style="text-align: right; font-weight: 700;">
                                            ₹ <%= String.format("%.2f", misReport.getTotalPfContribution()) %>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td><strong>Professional Tax (PT) Deducted</strong></td>
                                        <td><span class="badge-pill badge-gray">State Withholding</span></td>
                                        <td>Withheld From Payout</td>
                                        <td class="mono-val" style="text-align: right; font-weight: 700;">
                                            ₹ <%= String.format("%.2f", misReport.getTotalPtDeduction()) %>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td><strong>Loss of Pay (LOP) Retained</strong></td>
                                        <td><span class="badge-pill badge-amber">Attendance Clawback</span></td>
                                        <td>Retained Liquid Savings</td>
                                        <td class="mono-val" style="text-align: right; font-weight: 700; color: #059669;">
                                            - ₹ <%= String.format("%.2f", misReport.getTotalLopDeductions().max(java.math.BigDecimal.ZERO)) %>
                                        </td>
                                    </tr>
                                    <tr style="background: #f8fafc;">
                                        <td><strong style="color: #0f172a;">Total Estimated Corporate CTC Burden</strong></td>
                                        <td><span class="badge-pill badge-green">Consolidated Run</span></td>
                                        <td><strong>Total Cash Outlay</strong></td>
                                        <td class="mono-val" style="text-align: right; font-weight: 800; font-size: 15px; color: var(--brand-primary);">
                                            ₹ <%= String.format("%.2f", misReport.getTotalEstimatedCtc()) %>
                                        </td>
                                    </tr>
                                </tbody>
                            </table>
                        </div>
                    </div>

                    <div>
                        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px;">
                            <div>
                                <h4 style="font-size: 15px; font-weight: 800; color: #1e3a8a; margin: 0;">
                                    📋 Banking Audit Trail & UTR Settlement Ledger
                                </h4>
                                <p style="font-size: 12px; color: var(--text-muted); margin-top: 2px;">
                                    Tamper-evident log of bank transfer channels, UTR transaction numbers, and settlement timestamps.
                                </p>
                            </div>
                            <span class="badge-pill badge-blue">Audited Entries: <%= (auditLogs != null) ? auditLogs.size() : 0 %></span>
                        </div>

                        <div class="table-wrapper">
                            <table>
                                <thead>
                                    <tr>
                                        <th style="width: 100px;">Audit ID</th>
                                        <th style="width: 110px;">Date</th>
                                        <th style="width: 100px;">Emp ID</th>
                                        <th>Beneficiary Name</th>
                                        <th style="width: 110px;">Period</th>
                                        <th style="width: 140px;">Payment Mode</th>
                                        <th>UTR / Reference ID</th>
                                        <th style="text-align: right; width: 140px;">Disbursed Net</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <% if (auditLogs != null && !auditLogs.isEmpty()) { 
                                        for (PayrollPayment rec : auditLogs) { 
                                            String rNum = (rec.getReferenceNumber() != null && !rec.getReferenceNumber().isBlank()) ? rec.getReferenceNumber() : "--";
                                    %>
                                        <tr>
                                            <td class="mono-val" style="color: var(--text-muted); font-size: 11.5px;">#TXN-<%= rec.getId() %></td>
                                            <td style="color: var(--text-muted); font-size: 12px;"><%= rec.getPaymentDate() %></td>
                                            <td class="mono-val" style="font-weight: 800; color: var(--brand-primary);"><%= rec.getEmployeeId() %></td>
                                            <td><strong><%= (rec.getEmployeeName() != null && !rec.getEmployeeName().isBlank()) ? rec.getEmployeeName() : rec.getEmployeeId() %></strong></td>
                                            <td><span class="badge-pill badge-gray"><%= rec.getPayrollPeriod() %></span></td>
                                            <td><span class="badge-pill badge-blue"><%= rec.getPaymentMethod() %></span></td>
                                            <td class="mono-val" style="font-weight: 700;"><%= rNum %></td>
                                            <td class="mono-val" style="text-align: right; font-weight: 800; color: #059669;">
                                                ₹ <%= String.format("%.2f", rec.getAmountPaid() != null ? rec.getAmountPaid() : java.math.BigDecimal.ZERO) %>
                                            </td>
                                        </tr>
                                    <%  } 
                                       } else { %>
                                        <tr>
                                            <td colspan="8" style="text-align: center; color: var(--text-muted); padding: 36px;">
                                                No financial audit transactions recorded for this period yet.
                                            </td>
                                        </tr>
                                    <% } %>
                                </tbody>
                            </table>
                        </div>
                    </div>

                </div>
            </div>
            <% } %>

            <!-- ===================================================================
                 TAB 5: ALL PAYSLIPS (WITH DYNAMIC FILTERS & MODAL)
                 =================================================================== -->
            <div id="tab-allpayslips" class="tab-pane <%= "tab-allpayslips".equals(activeTab) ? "active" : "" %>">
                <div class="card" style="border-left: 4.5px solid var(--brand-primary);">
                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 18px; flex-wrap: wrap; gap: 12px;">
                        <div>
                            <h3 style="font-size: 18px; font-weight: 800; color: #1e3a8a;">📄 Organization Salary Records & Payslips</h3>
                            <p style="font-size: 12.5px; color: var(--text-muted); margin-top: 2px;">Search and inspect generated vouchers by employee, month, or year.</p>
                        </div>
                    </div>

                    <div style="background: #f8fafc; border: 1.5px solid var(--border-subtle); border-radius: 12px; padding: 16px 20px; display: flex; gap: 14px; align-items: flex-end; flex-wrap: wrap; margin-bottom: 20px;">
                        <div style="display: flex; flex-direction: column; gap: 4px; flex: 1; min-width: 170px;">
                            <label style="font-size: 11px; font-weight: 800; color: var(--text-muted); text-transform: uppercase;">Search Employee</label>
                            <input type="text" id="slipSearchEmp" onkeyup="filterPayslipTable()" class="form-input" placeholder="ID or name...">
                        </div>
                        <div style="display: flex; flex-direction: column; gap: 4px; width: 160px;">
                            <label style="font-size: 11px; font-weight: 800; color: var(--text-muted); text-transform: uppercase;">Payroll Month</label>
                            <select id="slipFilterMonth" onchange="filterPayslipTable()" class="form-input">
                                <option value="ALL">All Months</option>
                                <option value="1">January</option>
                                <option value="2">February</option>
                                <option value="3">March</option>
                                <option value="4">April</option>
                                <option value="5">May</option>
                                <option value="6">June</option>
                                <option value="7">July</option>
                                <option value="8">August</option>
                                <option value="9">September</option>
                                <option value="10">October</option>
                                <option value="11">November</option>
                                <option value="12">December</option>
                            </select>
                        </div>
                        <div style="display: flex; flex-direction: column; gap: 4px; width: 140px;">
                            <label style="font-size: 11px; font-weight: 800; color: var(--text-muted); text-transform: uppercase;">Payroll Year</label>
                            <select id="slipFilterYear" onchange="filterPayslipTable()" class="form-input">
                                <option value="ALL">All Years</option>
                                <option value="2027">2027</option>
                                <option value="2026" selected>2026</option>
                                <option value="2025">2025</option>
                                <option value="2024">2024</option>
                            </select>
                        </div>
                        <button type="button" onclick="resetPayslipFilters()" class="btn-action" style="height: 40px; background: #fff; border: 1.5px solid var(--border-subtle); color: var(--text-muted);">
                            ↺ Reset
                        </button>
                    </div>

                    <div class="table-wrapper">
                        <table>
                            <thead>
                                <tr>
                                    <th style="width: 50px;">SNO</th>
                                    <th>EMP ID</th>
                                    <th>EMPLOYEE NAME</th>
                                    <th>PERIOD</th>
                                    <th>TOTAL EARNINGS</th>
                                    <th>NET PAY</th>
                                    <th>STATUS</th>
                                    <th style="text-align: center; width: 110px;">ACTIONS</th>
                                </tr>
                            </thead>
                            <tbody id="payslipsTableBody">
                                <% if (payrollList != null && !payrollList.isEmpty()) { 
                                    int count = 1;
                                    for (Payroll p : payrollList) {
                                        String pMonth = Month.of(p.getPayrollMonth()).getDisplayName(TextStyle.FULL, Locale.ENGLISH);
                                        String empDisplay = (p.getEmployeeName() != null ? p.getEmployeeName() : "Employee");
                                        boolean isPaid = "PAID".equalsIgnoreCase(p.getStatus());
                                    %>
                                    <tr class="payslip-data-row" 
                                        data-empid="<%= p.getEmployeeId().toLowerCase() %>" 
                                        data-empname="<%= empDisplay.toLowerCase() %>" 
                                        data-month="<%= p.getPayrollMonth() %>" 
                                        data-year="<%= p.getPayrollYear() %>">
                                        <td class="row-index" style="color: var(--text-muted);"><%= count++ %></td>
                                        <td class="mono-val" style="font-weight: 800; color: var(--brand-primary);"><%= p.getEmployeeId() %></td>
                                        <td>
                                            <div style="font-weight: 700;"><%= empDisplay %></div>
                                            <div style="font-size: 11px; color: var(--text-muted);"><%= p.getDepartment() != null ? p.getDepartment() : "General" %></div>
                                        </td>
                                        <td>
                                            <div style="font-weight: 700;"><%= pMonth %></div>
                                            <div style="font-size: 11px; color: var(--text-muted);"><%= p.getPayrollYear() %></div>
                                        </td>
                                        <td class="mono-val">INR <%= String.format("%.2f", p.getGrossSalary() != null ? p.getGrossSalary() : java.math.BigDecimal.ZERO) %></td>
                                        <td class="mono-val" style="color: #059669; font-weight: 800;">INR <%= String.format("%.2f", p.getNetSalary() != null ? p.getNetSalary() : java.math.BigDecimal.ZERO) %></td>
                                        <td>
                                            <span class="badge-pill <%= isPaid ? "badge-green" : "badge-amber" %>">• <%= p.getStatus() != null ? p.getStatus() : "PROCESSED" %></span>
                                        </td>
                                        <td style="text-align: center;">
                                            <a href="javascript:void(0)" onclick="openPayslipModal('<%= request.getContextPath() %>/salary-slip.jsp?id=<%= p.getId() %>')" class="btn-action" style="background:#eff6ff; color:#2563eb; height: 32px; padding: 0 10px;" title="Quick View">👁</a>
                                            <a href="<%= request.getContextPath() %>/salary-slip.jsp?id=<%= p.getId() %>" class="btn-action" style="background:#f1f5f9; color:#0f172a; height: 32px; padding: 0 10px;" title="Print/Download Voucher" target="_blank">📥</a>
                                        </td>
                                    </tr>
                                <%  } 
                                   } else { %>
                                    <tr>
                                        <td colspan="8" style="text-align: center; padding: 40px; color: var(--text-muted);">
                                            No payroll records generated yet.
                                        </td>
                                    </tr>
                                <% } %>
                                <tr id="noPayslipsRow" style="display: none;">
                                    <td colspan="8" style="text-align: center; padding: 36px; color: var(--text-muted);">
                                        No payslip records match the selected Employee, Month, or Year.
                                    </td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>

            <!-- ===================================================================
                 TAB 6: SELF ATTENDANCE (Direct In-Page Punching)
                 =================================================================== -->
            <div id="tab-selfatt" class="tab-pane <%= "tab-selfatt".equals(activeTab) ? "active" : "" %>">
                <div class="card" style="max-width: 620px; margin: 0 auto; width: 100%; border-left: 4.5px solid var(--brand-primary);">
                    <div style="border-bottom: 1.5px solid var(--border-subtle); padding-bottom: 14px; margin-bottom: 20px;">
                        <h3 style="font-size: 18px; font-weight: 800; color: #1e3a8a;">⏱ Self Attendance Console</h3>
                        <p style="font-size: 12.5px; color: var(--text-muted); margin-top: 2px;">
                            Punch real-time shifts and break allowances for <strong><%= loggedIn.getName() %></strong> (<%= loggedIn.getEmployeeId() %>).
                        </p>
                    </div>

                    <div style="background: #f8fafc; border: 1.5px solid var(--border-subtle); border-radius: 12px; padding: 22px; text-align: center; margin-bottom: 24px;">
                        <div style="font-size: 11px; font-weight: 800; text-transform: uppercase; color: var(--text-muted); letter-spacing: 0.6px;">Current Local Time</div>
                        <div id="liveClockDisplay" style="font-size: 34px; font-weight: 800; font-family: 'JetBrains Mono', monospace; color: #0f172a; margin-top: 4px;">--:--:--</div>
                    </div>

                    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 14px;">
                        <form method="post" action="<%= request.getRequestURI() %>">
                            <input type="hidden" name="punchAction" value="checkIn">
                            <button type="submit" class="btn-action" style="width: 100%; height: 44px; background: #10b981; color: #fff; font-weight: 800; justify-content: center;">✔ Punch Check-In</button>
                        </form>
                        <form method="post" action="<%= request.getRequestURI() %>">
                            <input type="hidden" name="punchAction" value="checkOut">
                            <button type="submit" class="btn-action" style="width: 100%; height: 44px; background: #ef4444; color: #fff; font-weight: 800; justify-content: center;">✖ Punch Check-Out</button>
                        </form>
                        <form method="post" action="<%= request.getRequestURI() %>">
                            <input type="hidden" name="punchAction" value="breakStart">
                            <button type="submit" class="btn-action" style="width: 100%; height: 44px; background: #f59e0b; color: #fff; font-weight: 800; justify-content: center;">☕ Start Break</button>
                        </form>
                        <form method="post" action="<%= request.getRequestURI() %>">
                            <input type="hidden" name="punchAction" value="breakEnd">
                            <button type="submit" class="btn-action" style="width: 100%; height: 44px; background: #3b82f6; color: #fff; font-weight: 800; justify-content: center;">⚡ End Break</button>
                        </form>
                    </div>
                </div>
            </div>

            <!-- ===================================================================
                 TAB 7: DAILY ROSTER REPORT
                 =================================================================== -->
            <div id="tab-dailyroster" class="tab-pane <%= "tab-dailyroster".equals(activeTab) ? "active" : "" %>">
                <div class="card" style="border-left: 4.5px solid var(--brand-primary);">
                    <div style="display: flex; justify-content: space-between; align-items: center; border-bottom: 1.5px solid var(--border-subtle); padding-bottom: 14px; margin-bottom: 20px;">
                        <div>
                            <h3 style="font-size: 18px; font-weight: 800; color: #1e3a8a;">📅 Daily Roster & Shift Monitor</h3>
                            <p style="font-size: 12.5px; color: var(--text-muted); margin-top: 2px;">
                                Inspect daily employee attendance, active break states, and shift conclusions.
                            </p>
                        </div>
                    </div>

                    <div class="table-wrapper">
                        <table>
                            <thead>
                                <tr>
                                    <th>Emp ID</th>
                                    <th>Date</th>
                                    <th>Check In</th>
                                    <th>Break 1</th>
                                    <th>Break 2</th>
                                    <th>Check Out</th>
                                    <th>Net Working Time</th>
                                    <th style="text-align: center;">Final Status</th>
                                </tr>
                            </thead>
                            <tbody>
                                <% if (todayAttendance != null && !todayAttendance.isEmpty()) { 
                                    for (Attendance att : todayAttendance) { %>
                                    <tr>
                                        <td class="mono-val" style="font-weight: 800; color: var(--brand-primary);"><%= att.getEmployeeId() %></td>
                                        <td><%= extractDate(att) %></td>
                                        <td><%= formatLocalTime(att.getCheckInTime()) %></td>
                                        <td><%= formatBreakRange(att.getBreak1StartTime(), att.getBreak1EndTime()) %></td>
                                        <td><%= formatBreakRange(att.getBreak2StartTime(), att.getBreak2EndTime()) %></td>
                                        <td><%= formatLocalTime(att.getCheckOutTime()) %></td>
                                        <td><%= att.getNetWorkingMinutes() %> mins</td>
                                        <td style="text-align: center;">
                                            <span class="badge-pill <%= "PRESENT".equalsIgnoreCase(att.getStatus()) ? "badge-green" : "badge-amber" %>">
                                                <%= att.getStatus() %>
                                            </span>
                                        </td>
                                    </tr>
                                <%  } 
                                   } else { %>
                                    <tr>
                                        <td colspan="8" style="text-align: center; color: var(--text-muted); padding: 36px;">
                                            No attendance entries recorded for today.
                                        </td>
                                    </tr>
                                <% } %>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>

            <!-- ===================================================================
                 TAB 8: MONTHLY ANALYTICS & OTHER WORKSPACE TABS
                 =================================================================== -->
            <div id="tab-monthlyanalytics" class="tab-pane <%= "tab-monthlyanalytics".equals(activeTab) ? "active" : "" %>">
                <div class="card">
                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px;">
                        <h3 style="font-size: 16px; font-weight: 800;">Monthly Attendance Analytics</h3>
                        <a href="<%= request.getContextPath() %>/monthly-attendance.jsp" target="_blank" style="font-size: 12.5px; font-weight: 700; color: var(--brand-primary); text-decoration: none;">Open in Full Window ↗</a>
                    </div>
                    <iframe src="<%= request.getContextPath() %>/monthly-attendance.jsp" class="embedded-frame"></iframe>
                </div>
            </div>

            <div id="tab-perfaudits" class="tab-pane <%= "tab-perfaudits".equals(activeTab) ? "active" : "" %>">
                <div class="card">
                    <h3 style="font-size: 16px; font-weight: 800; margin-bottom: 12px;">Performance & Drill-down Audits</h3>
                    <iframe src="<%= request.getContextPath() %>/drill-reports.jsp" class="embedded-frame"></iframe>
                </div>
            </div>

            <% if (isHr) { %>
            <div id="tab-leaveapprovals" class="tab-pane <%= "tab-leaveapprovals".equals(activeTab) ? "active" : "" %>">
                <div class="card">
                    <h3 style="font-size: 16px; font-weight: 800; margin-bottom: 14px;">Pending Leave Requests</h3>
                    <div class="table-wrapper">
                        <table>
                            <thead>
                                <tr>
                                    <th>Record ID</th>
                                    <th>Employee</th>
                                    <th>Leave Date</th>
                                    <th>Reason</th>
                                    <th>Actions</th>
                                </tr>
                            </thead>
                            <tbody>
                                <% if (pendingLeaves != null && !pendingLeaves.isEmpty()) { 
                                    for (Attendance att : pendingLeaves) { %>
                                        <tr>
                                            <td><strong><%= att.getAttendanceId() %></strong></td>
                                            <td>
                                                <strong><%= extractEmpName(att) %></strong>
                                                <div style="font-size: 11px; color: var(--text-muted);"><%= att.getEmployeeId() %></div>
                                            </td>
                                            <td><strong><%= extractDate(att) %></strong></td>
                                            <td><%= (att.getReason() != null ? att.getReason() : "--") %></td>
                                            <td>
                                                <div style="display: flex; gap: 8px;">
                                                    <form action="<%= request.getContextPath() %>/attendance/leave-requests" method="post" style="display: inline; margin: 0;">
                                                        <input type="hidden" name="attendanceId" value="<%= att.getAttendanceId() %>">
                                                        <input type="hidden" name="decision" value="APPROVED">
                                                        <button type="submit" class="btn-action btn-approve">✔ Approve</button>
                                                    </form>
                                                    <form action="<%= request.getContextPath() %>/attendance/leave-requests" method="post" style="display: inline; margin: 0;" onsubmit="return confirm('Reject this leave application?');">
                                                        <input type="hidden" name="attendanceId" value="<%= att.getAttendanceId() %>">
                                                        <input type="hidden" name="decision" value="REJECTED">
                                                        <button type="submit" class="btn-action btn-reject">✖ Reject</button>
                                                    </form>
                                                </div>
                                            </td>
                                        </tr>
                                <%  } 
                                   } else { %>
                                    <tr><td colspan="5" style="text-align: center; color: var(--text-muted); padding: 32px;">No pending leave applications awaiting approval.</td></tr>
                            <% } %>
                        </tbody>
                    </table>
                </div>
            </div>
            <% } %>

            <% if (isAdmin) { %>
            <div id="tab-taskmonitor" class="tab-pane <%= "tab-taskmonitor".equals(activeTab) ? "active" : "" %>">
                <div class="card">
                    <h3 style="font-size: 16px; font-weight: 800; margin-bottom: 14px;">Enterprise Task & Performance Monitor</h3>
                    <div class="table-wrapper">
                        <table>
                            <thead>
                                <tr>
                                    <th>Task Title</th>
                                    <th>Assignee</th>
                                    <th>Manager</th>
                                    <th>Timeline</th>
                                    <th>Status</th>
                                </tr>
                            </thead>
                            <tbody>
                                <% if (allTasks != null && !allTasks.isEmpty()) { 
                                    for (Task t : allTasks) { %>
                                        <tr>
                                            <td><strong><%= t.getTaskTitle() %></strong></td>
                                            <td><%= t.getAssignedToName() != null ? t.getAssignedToName() : t.getAssignedTo() %></td>
                                            <td><%= t.getCreatedByName() != null ? t.getCreatedByName() : "Manager" %></td>
                                            <td><%= t.getDueDate() != null ? t.getDueDate() : "--" %></td>
                                            <td><span class="badge-pill badge-green">• <%= t.getStatus() %></span></td>
                                        </tr>
                                <%  } 
                                   } %>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>

            <div id="tab-teamscatalog" class="tab-pane <%= "tab-teamscatalog".equals(activeTab) ? "active" : "" %>">
                <div class="card">
                    <h3 style="font-size: 16px; font-weight: 800; margin-bottom: 12px;">Teams Catalog</h3>
                    <iframe src="<%= request.getContextPath() %>/manageTeams.jsp" class="embedded-frame"></iframe>
                </div>
            </div>

            <div id="tab-addmanager" class="tab-pane <%= "tab-addmanager".equals(activeTab) ? "active" : "" %>">
                <div class="card">
                    <h3 style="font-size: 16px; font-weight: 800; margin-bottom: 12px;">Add Manager</h3>
                    <iframe src="<%= request.getContextPath() %>/add-manager.jsp" class="embedded-frame"></iframe>
                </div>
            </div>

            <div id="tab-addemployee" class="tab-pane <%= "tab-addemployee".equals(activeTab) ? "active" : "" %>">
                <div class="card">
                    <h3 style="font-size: 16px; font-weight: 800; margin-bottom: 12px;">Add Employee</h3>
                    <iframe src="<%= request.getContextPath() %>/add-employee.jsp" class="embedded-frame"></iframe>
                </div>
            </div>

            <div id="tab-createteam" class="tab-pane <%= "tab-createteam".equals(activeTab) ? "active" : "" %>">
                <div class="card">
                    <h3 style="font-size: 16px; font-weight: 800; margin-bottom: 12px;">Create Team</h3>
                    <iframe src="<%= request.getContextPath() %>/createTeam.jsp" class="embedded-frame"></iframe>
                </div>
            </div>

            <!-- ===================================================================
                 NATIVE IN-PAGE SYSTEM & SECURITY MODULES (NO EXTERNAL PAGE RELOAD)
                 =================================================================== -->

            <!-- SYS TAB 1: SYSTEM DASHBOARD -->
            <div id="tab-sysdash" class="tab-pane <%= "tab-sysdash".equals(activeTab) ? "active" : "" %>">
                <div class="grid-4">
                    <div class="stat-card blue">
                        <div class="stat-lbl">Registered Users</div>
                        <div class="stat-val" style="color: var(--brand-primary);"><%= sysTotalUsers %></div>
                        <div style="font-size: 11px; color: var(--text-muted); margin-top: 4px;"><span style="color: #059669; font-weight: 700;"><%= sysActiveUsers %> Active</span> • <%= sysInactiveUsers %> Inactive</div>
                    </div>
                    <div class="stat-card purple">
                        <div class="stat-lbl">Audit Trail Logs</div>
                        <div class="stat-val" style="color: #7c3aed;"><%= sysTotalAuditRecords %></div>
                        <div style="font-size: 11px; color: var(--text-muted); margin-top: 4px;">Immutable state changes</div>
                    </div>
                    <div class="stat-card green">
                        <div class="stat-lbl">Logins Today</div>
                        <div class="stat-val" style="color: #059669;"><%= sysTodayLogins %></div>
                        <div style="font-size: 11px; color: var(--text-muted); margin-top: 4px;">Successful authentications</div>
                    </div>
                    <div class="stat-card rose">
                        <div class="stat-lbl">Failed Logins Today</div>
                        <div class="stat-val" style="color: #dc2626;"><%= sysTodayFailedLogins %></div>
                        <div style="font-size: 11px; color: var(--text-muted); margin-top: 4px;">Latest Backup: <b><%= sysLatestBackupStatus %></b></div>
                    </div>
                </div>

                <div class="grid-2">
                    <div class="card" style="border-left: 4px solid var(--brand-primary);">
                        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px;">
                            <h3 style="font-size: 15.5px; font-weight: 800; color: #1e3a8a;">🔍 Recent Administrative Changes</h3>
                            <button type="button" class="btn-action" style="height: 28px; font-size: 11px; background: #eff6ff; color: var(--brand-primary);" onclick="switchAdminTab('tab-sysaudit')">View All →</button>
                        </div>
                        <div class="table-wrapper">
                            <table style="min-width: 100%;">
                                <thead><tr><th>Time</th><th>Module</th><th>Action</th><th>Record</th></tr></thead>
                                <tbody>
                                    <% if (sysAuditList != null && !sysAuditList.isEmpty()) {
                                        int lim = Math.min(5, sysAuditList.size());
                                        for (int i = 0; i < lim; i++) {
                                            AuditLog a = sysAuditList.get(i); %>
                                        <tr>
                                            <td style="font-size: 11.5px; color: var(--text-muted);"><%= a.getCreatedAt() != null ? a.getCreatedAt() : "-" %></td>
                                            <td><b><%= a.getModuleName() %></b></td>
                                            <td><span class="badge-pill badge-blue"><%= a.getActionType() %></span></td>
                                            <td><span class="code-chip"><%= a.getRecordId() != null ? a.getRecordId() : "-" %></span></td>
                                        </tr>
                                    <% } } else { %>
                                        <tr><td colspan="4" style="text-align: center; color: var(--text-muted);">No audit records yet.</td></tr>
                                    <% } %>
                                </tbody>
                            </table>
                        </div>
                    </div>

                    <div class="card" style="border-left: 4px solid var(--emerald);">
                        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px;">
                            <h3 style="font-size: 15.5px; font-weight: 800; color: #1e3a8a;">🔐 Live Authentication Stream</h3>
                            <button type="button" class="btn-action" style="height: 28px; font-size: 11px; background: #ecfdf5; color: #059669;" onclick="switchAdminTab('tab-syslogin')">View All →</button>
                        </div>
                        <div class="table-wrapper">
                            <table style="min-width: 100%;">
                                <thead><tr><th>Time</th><th>Account</th><th>Event</th><th>IP</th></tr></thead>
                                <tbody>
                                    <% if (sysLoginList != null && !sysLoginList.isEmpty()) {
                                        int lim = Math.min(5, sysLoginList.size());
                                        for (int i = 0; i < lim; i++) {
                                            LoginHistory l = sysLoginList.get(i);
                                            String act = l.getActivityType() != null ? l.getActivityType() : ""; %>
                                        <tr>
                                            <td style="font-size: 11.5px; color: var(--text-muted);"><%= l.getCreatedAt() != null ? l.getCreatedAt() : "-" %></td>
                                            <td><b><%= l.getEmail() %></b></td>
                                            <td><span class="badge-pill <%= "LOGIN".equalsIgnoreCase(act) ? "badge-green" : ("LOGOUT".equalsIgnoreCase(act) ? "badge-gray" : "badge-red") %>"><%= act %></span></td>
                                            <td><span class="code-chip"><%= l.getIpAddress() != null ? l.getIpAddress() : "-" %></span></td>
                                        </tr>
                                    <% } } else { %>
                                        <tr><td colspan="4" style="text-align: center; color: var(--text-muted);">No logins logged yet.</td></tr>
                                    <% } %>
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>

            <!-- SYS TAB 2: AUDIT LOGS -->
            <div id="tab-sysaudit" class="tab-pane <%= "tab-sysaudit".equals(activeTab) ? "active" : "" %>">
                <div class="card" style="border-left: 4.5px solid var(--purple);">
                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; flex-wrap: wrap; gap: 12px;">
                        <div>
                            <h3 style="font-size: 18px; font-weight: 800; color: #1e3a8a;">📜 Immutable Audit Trail & Data Changes</h3>
                            <p style="font-size: 12.5px; color: var(--text-muted);">Chronological ledger of all administrative mutations and payload snapshots.</p>
                        </div>
                        <input type="text" id="auditSearchBox" onkeyup="filterSimpleTable('auditSearchBox', 'sysAuditTableBody')" class="form-input" style="max-width: 260px;" placeholder="Filter module, action, or ID...">
                    </div>
                    <div class="table-wrapper">
                        <table>
                            <thead>
                                <tr>
                                    <th>Timestamp</th>
                                    <th>User</th>
                                    <th>Module</th>
                                    <th>Action</th>
                                    <th>Record ID</th>
                                    <th>Description</th>
                                    <th>Payload Snapshot</th>
                                </tr>
                            </thead>
                            <tbody id="sysAuditTableBody">
                                <% if (sysAuditList != null && !sysAuditList.isEmpty()) {
                                    for (AuditLog log : sysAuditList) {
                                        String act = log.getActionType() != null ? log.getActionType().toUpperCase() : "";
                                        String bClass = "badge-blue";
                                        if (act.contains("CREATE") || act.contains("INSERT")) bClass = "badge-green";
                                        else if (act.contains("UPDATE")) bClass = "badge-amber";
                                        else if (act.contains("DELETE")) bClass = "badge-red"; %>
                                    <tr>
                                        <td style="font-size: 12px; color: var(--text-muted);"><%= log.getCreatedAt() != null ? log.getCreatedAt() : "-" %></td>
                                        <td><b><%= log.getUserId() != null && log.getUserId() > 0 ? "UID #" + log.getUserId() : "System" %></b></td>
                                        <td><b><%= log.getModuleName() %></b></td>
                                        <td><span class="badge-pill <%= bClass %>"><%= act %></span></td>
                                        <td><span class="code-chip"><%= log.getRecordId() != null ? log.getRecordId() : "-" %></span></td>
                                        <td><%= log.getDescription() != null ? log.getDescription() : "-" %></td>
                                        <td>
                                            <% if (log.getNewValues() != null && !log.getNewValues().trim().isEmpty() && !"{}".equals(log.getNewValues())) { %>
                                                <div class="payload-box"><%= log.getNewValues() %></div>
                                            <% } else { %>
                                                <span style="font-size: 11.5px; color: var(--text-muted);">No state payload</span>
                                            <% } %>
                                        </td>
                                    </tr>
                                <% } } else { %>
                                    <tr><td colspan="7" style="text-align: center; padding: 36px; color: var(--text-muted);">No audit records found.</td></tr>
                                <% } %>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>

            <!-- SYS TAB 3: LOGIN HISTORY -->
            <div id="tab-syslogin" class="tab-pane <%= "tab-syslogin".equals(activeTab) ? "active" : "" %>">
                <div class="card" style="border-left: 4.5px solid var(--brand-primary);">
                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; flex-wrap: wrap; gap: 12px;">
                        <div>
                            <h3 style="font-size: 18px; font-weight: 800; color: #1e3a8a;">🔑 Authentication Logs & Security History</h3>
                            <p style="font-size: 12.5px; color: var(--text-muted);">Monitor successful sessions, logouts, and failed brute-force login attempts.</p>
                        </div>
                        <input type="text" id="loginSearchBox" onkeyup="filterSimpleTable('loginSearchBox', 'sysLoginTableBody')" class="form-input" style="max-width: 260px;" placeholder="Filter email, IP, or status...">
                    </div>
                    <div class="table-wrapper">
                        <table>
                            <thead>
                                <tr>
                                    <th>Timestamp</th>
                                    <th>User ID</th>
                                    <th>Email Account</th>
                                    <th>Activity Event</th>
                                    <th>Client IP</th>
                                    <th>User Agent / Browser</th>
                                </tr>
                            </thead>
                            <tbody id="sysLoginTableBody">
                                <% if (sysLoginList != null && !sysLoginList.isEmpty()) {
                                    for (LoginHistory item : sysLoginList) {
                                        String act = item.getActivityType() != null ? item.getActivityType() : ""; %>
                                    <tr>
                                        <td style="font-size: 12px; color: var(--text-muted);"><%= item.getCreatedAt() != null ? item.getCreatedAt() : "-" %></td>
                                        <td><b><%= item.getUserId() != null && item.getUserId() > 0 ? "#" + item.getUserId() : "-" %></b></td>
                                        <td><b><%= item.getEmail() %></b></td>
                                        <td>
                                            <% if ("LOGIN".equalsIgnoreCase(act)) { %>
                                                <span class="badge-pill badge-green">✔ LOGIN</span>
                                            <% } else if ("LOGOUT".equalsIgnoreCase(act)) { %>
                                                <span class="badge-pill badge-gray">LOGOUT</span>
                                            <% } else { %>
                                                <span class="badge-pill badge-red">⚠ FAILED LOGIN</span>
                                            <% } %>
                                        </td>
                                        <td><span class="code-chip"><%= item.getIpAddress() != null ? item.getIpAddress() : "0.0.0.0" %></span></td>
                                        <td style="max-width: 240px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-size: 11.5px; color: var(--text-muted);" title="<%= item.getUserAgent() != null ? item.getUserAgent() : "" %>">
                                            <%= item.getUserAgent() != null ? item.getUserAgent() : "-" %>
                                        </td>
                                    </tr>
                                <% } } else { %>
                                    <tr><td colspan="6" style="text-align: center; padding: 36px; color: var(--text-muted);">No login history records available.</td></tr>
                                <% } %>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>

            <!-- SYS TAB 4: SYSTEM SETTINGS (WITH CLOUDINARY LOGO & NO-SQL BRANDING) -->
            <div id="tab-syssettings" class="tab-pane <%= "tab-syssettings".equals(activeTab) ? "active" : "" %>">
                <div class="card" style="border-left: 4.5px solid var(--brand-primary);">
                    <div style="border-bottom: 1.5px solid var(--border-subtle); padding-bottom: 14px; margin-bottom: 12px;">
                        <h3 style="font-size: 18px; font-weight: 800; color: #1e3a8a;">⚙ Global System Governance & Security Parameters</h3>
                        <p style="font-size: 12.5px; color: var(--text-muted);">Configure organization branding, authentication lockouts, and automated background tasks.</p>
                    </div>

                 <!-- CLEAN COMPANY LOGO SECTION (DIRECT URL PASTE ONLY) -->
                    <div class="section-tag">Company Branding & Logo</div>
                    <div class="setting-row" style="align-items: flex-start;">
                        <div class="setting-info">
                            <div class="setting-title">Change Company Logo <code>COMPANY_LOGO_URL</code></div>
                            <div class="setting-desc">Paste a direct image link (PNG, JPG, or SVG) to update the logo across the sidebar, login screen, and salary slips.</div>
                            
                            <div style="margin-top: 12px; display: flex; align-items: center; gap: 14px;">
                                <div style="width: 64px; height: 64px; border-radius: 12px; border: 1.5px dashed var(--border-subtle); background: #f8fafc; display: flex; align-items: center; justify-content: center; overflow: hidden;">
                                    <% if (!cfgCompanyLogo.isEmpty()) { %>
                                        <img id="logoPreviewImg" src="<%= cfgCompanyLogo %>" alt="Company Logo" style="max-width: 100%; max-height: 100%; object-fit: contain;">
                                    <% } else { %>
                                        <img id="logoPreviewImg" src="" alt="Preview" style="max-width: 100%; max-height: 100%; object-fit: contain; display: none;">
                                        <span id="logoPlaceholderTxt" style="font-size: 10.5px; color: var(--text-muted); font-weight: 800;">NO LOGO</span>
                                    <% } %>
                                </div>
                                <div style="font-size: 12px; color: var(--text-muted);">
                                    <b>Live Brand Preview</b><br>
                                    Saved to <code>WEB-INF/branding.properties</code>
                                </div>
                            </div>
                        </div>

                        <form method="post" action="<%= request.getRequestURI() %>" class="setting-ctrl" style="min-width: 310px;">
                            <input type="hidden" name="sysAction" value="updateLogo">
                            <div style="display: flex; gap: 8px; width: 100%;">
                                <input type="url" id="logoUrlInput" name="companyLogoUrl" value="<%= cfgCompanyLogo %>" 
                                       placeholder="https://example.com/images/company-logo.png" 
                                       class="form-input" style="flex: 1;" 
                                       oninput="previewCompanyLogo(this.value)">
                                <button type="submit" class="btn-action btn-primary">Save Logo</button>
                            </div>
                        </form>
                    </div>

                    <div class="section-tag">Authentication & Lockout Controls</div>
                    <div class="setting-row">
                        <div class="setting-info">
                            <div class="setting-title">Failed Password Attempts Threshold <code>MAX_FAILED_ATTEMPTS</code></div>
                            <div class="setting-desc">Number of consecutive wrong password attempts allowed before locking account.</div>
                        </div>
                        <form method="post" action="<%= request.getRequestURI() %>" class="setting-ctrl">
                            <input type="hidden" name="sysAction" value="updateSetting">
                            <input type="hidden" name="settingKey" value="MAX_FAILED_ATTEMPTS">
                            <select name="settingValue" class="form-input" style="width: 170px;">
                                <option value="2" <%= "2".equals(cfgMaxAttempts) ? "selected" : "" %>>2 Attempts</option>
                                <option value="3" <%= "3".equals(cfgMaxAttempts) ? "selected" : "" %>>3 Attempts</option>
                                <option value="5" <%= "5".equals(cfgMaxAttempts) ? "selected" : "" %>>5 Attempts</option>
                                <option value="10" <%= "10".equals(cfgMaxAttempts) ? "selected" : "" %>>10 Attempts</option>
                            </select>
                            <button type="submit" class="btn-action btn-primary">Save</button>
                        </form>
                    </div>

                    <div class="setting-row">
                        <div class="setting-info">
                            <div class="setting-title">Lockout Cooldown Duration <code>LOCKOUT_DURATION_MINUTES</code></div>
                            <div class="setting-desc">Wait duration in minutes before a locked account automatically resets.</div>
                        </div>
                        <form method="post" action="<%= request.getRequestURI() %>" class="setting-ctrl">
                            <input type="hidden" name="sysAction" value="updateSetting">
                            <input type="hidden" name="settingKey" value="LOCKOUT_DURATION_MINUTES">
                            <select name="settingValue" class="form-input" style="width: 170px;">
                                <option value="1" <%= "1".equals(cfgLockoutMins) ? "selected" : "" %>>1 Minute</option>
                                <option value="2" <%= "2".equals(cfgLockoutMins) ? "selected" : "" %>>2 Minutes</option>
                                <option value="5" <%= "5".equals(cfgLockoutMins) ? "selected" : "" %>>5 Minutes</option>
                                <option value="15" <%= "15".equals(cfgLockoutMins) ? "selected" : "" %>>15 Minutes</option>
                            </select>
                            <button type="submit" class="btn-action btn-primary">Save</button>
                        </form>
                    </div>

                    <div class="section-tag">Organization Profile & Localization</div>
                    <div class="setting-row">
                        <div class="setting-info">
                            <div class="setting-title">Organization Legal Name <code>COMPANY_NAME</code></div>
                            <div class="setting-desc">Displayed across payslip headers, compliance exports, and reports.</div>
                        </div>
                        <form method="post" action="<%= request.getRequestURI() %>" class="setting-ctrl">
                            <input type="hidden" name="sysAction" value="updateSetting">
                            <input type="hidden" name="settingKey" value="COMPANY_NAME">
                            <input type="text" name="settingValue" value="<%= cfgCompanyName %>" class="form-input" style="width: 240px;" required>
                            <button type="submit" class="btn-action btn-primary">Save</button>
                        </form>
                    </div>

                    <div class="setting-row">
                        <div class="setting-info">
                            <div class="setting-title">Helpdesk Support Email <code>COMPANY_EMAIL</code></div>
                            <div class="setting-desc">Sender identity for system notifications and HR alerts.</div>
                        </div>
                        <form method="post" action="<%= request.getRequestURI() %>" class="setting-ctrl">
                            <input type="hidden" name="sysAction" value="updateSetting">
                            <input type="hidden" name="settingKey" value="COMPANY_EMAIL">
                            <input type="email" name="settingValue" value="<%= cfgCompanyEmail %>" class="form-input" style="width: 240px;" required>
                            <button type="submit" class="btn-action btn-primary">Save</button>
                        </form>
                    </div>

                    <div class="setting-row">
                        <div class="setting-info">
                            <div class="setting-title">Corporate Headquarters <code>COMPANY_ADDRESS</code></div>
                            <div class="setting-desc">Registered office address printed on statutory documents.</div>
                        </div>
                        <form method="post" action="<%= request.getRequestURI() %>" class="setting-ctrl">
                            <input type="hidden" name="sysAction" value="updateSetting">
                            <input type="hidden" name="settingKey" value="COMPANY_ADDRESS">
                            <input type="text" name="settingValue" value="<%= cfgCompanyAddress %>" class="form-input" style="width: 240px;" required>
                            <button type="submit" class="btn-action btn-primary">Save</button>
                        </form>
                    </div>

                    <div class="setting-row">
                        <div class="setting-info">
                            <div class="setting-title">System Base Currency <code>SYSTEM_CURRENCY</code></div>
                            <div class="setting-desc">Currency symbol used across payroll disbursements.</div>
                        </div>
                        <form method="post" action="<%= request.getRequestURI() %>" class="setting-ctrl">
                            <input type="hidden" name="sysAction" value="updateSetting">
                            <input type="hidden" name="settingKey" value="SYSTEM_CURRENCY">
                            <select name="settingValue" class="form-input" style="width: 240px;">
                                <option value="INR (₹)" <%= cfgCurrency.contains("INR") ? "selected" : "" %>>INR (₹) - Indian Rupee</option>
                                <option value="USD ($)" <%= cfgCurrency.contains("USD") ? "selected" : "" %>>USD ($) - US Dollar</option>
                                <option value="EUR (€)" <%= cfgCurrency.contains("EUR") ? "selected" : "" %>>EUR (€) - Euro</option>
                            </select>
                            <button type="submit" class="btn-action btn-primary">Save</button>
                        </form>
                    </div>

                    <div class="section-tag">Operations & Automation Switches</div>
                    <div class="setting-row">
                        <div class="setting-info">
                            <div class="setting-title">Transactional Email Alerts <code>NOTIFY_EMAIL_ALERTS</code></div>
                            <div class="setting-desc">Dispatch automated email notifications on leave decisions and incidents.</div>
                        </div>
                        <form method="post" action="<%= request.getRequestURI() %>" class="setting-ctrl">
                            <input type="hidden" name="sysAction" value="updateSetting">
                            <input type="hidden" name="settingKey" value="NOTIFY_EMAIL_ALERTS">
                            <div class="toggle-group">
                                <button type="submit" name="settingValue" value="ENABLED" class="toggle-opt <%= cfgEmailAlerts ? "on" : "" %>">ENABLED</button>
                                <button type="submit" name="settingValue" value="DISABLED" class="toggle-opt <%= !cfgEmailAlerts ? "off" : "" %>">DISABLED</button>
                            </div>
                        </form>
                    </div>

                    <div class="setting-row">
                        <div class="setting-info">
                            <div class="setting-title">Daily Automated DB Snapshots <code>BACKUP_AUTO_DAILY</code></div>
                            <div class="setting-desc">Run automated point-in-time SQL backup archive daily at 02:00 AM.</div>
                        </div>
                        <form method="post" action="<%= request.getRequestURI() %>" class="setting-ctrl">
                            <input type="hidden" name="sysAction" value="updateSetting">
                            <input type="hidden" name="settingKey" value="BACKUP_AUTO_DAILY">
                            <div class="toggle-group">
                                <button type="submit" name="settingValue" value="ENABLED" class="toggle-opt <%= cfgAutoBackup ? "on" : "" %>">ENABLED</button>
                                <button type="submit" name="settingValue" value="DISABLED" class="toggle-opt <%= !cfgAutoBackup ? "off" : "" %>">DISABLED</button>
                            </div>
                        </form>
                    </div>
                </div>
            </div>

            <!-- SYS TAB 5: APPLICATION ERRORS & INCIDENTS -->
            <div id="tab-syserrors" class="tab-pane <%= "tab-syserrors".equals(activeTab) ? "active" : "" %>">
                <div class="grid-3">
                    <div class="stat-card blue">
                        <div class="stat-lbl">Total Logged Incidents</div>
                        <div class="stat-val" style="color: var(--brand-primary);"><%= sysTotalErrors %></div>
                    </div>
                    <div class="stat-card rose">
                        <div class="stat-lbl">Critical Faults</div>
                        <div class="stat-val" style="color: #dc2626;"><%= sysCriticalErrors %></div>
                    </div>
                    <div class="stat-card amber">
                        <div class="stat-lbl">High Severity Faults</div>
                        <div class="stat-val" style="color: #d97706;"><%= sysHighErrors %></div>
                    </div>
                </div>

                <div class="card" style="border-left: 4.5px solid var(--rose);">
                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; flex-wrap: wrap; gap: 12px;">
                        <div>
                            <h3 style="font-size: 18px; font-weight: 800; color: #1e3a8a;">⚠ Application Exception & Incident Triage</h3>
                            <p style="font-size: 12.5px; color: var(--text-muted);">Real-time uncaught runtime exceptions and failure diagnostics.</p>
                        </div>
                        <div style="display: flex; gap: 10px; align-items: center;">
                            <input type="text" id="errSearchBox" onkeyup="filterSimpleTable('errSearchBox', 'sysErrorTableBody')" class="form-input" style="max-width: 230px;" placeholder="Filter module or message...">
                            <% if (sysTotalErrors > 0) { %>
                                <a href="<%= request.getContextPath() %>/dashboard.jsp?sysAction=clearErrors" class="btn-action btn-reject" onclick="return confirm('Purge all logged exception records?');">🗑 Clear Logs</a>
                            <% } %>
                        </div>
                    </div>

                    <div class="table-wrapper">
                        <table>
                            <thead>
                                <tr>
                                    <th>Timestamp</th>
                                    <th>Module</th>
                                    <th>Severity</th>
                                    <th>Exception Type</th>
                                    <th>Diagnostic Message</th>
                                    <th>User ID</th>
                                </tr>
                            </thead>
                            <tbody id="sysErrorTableBody">
                                <% if (sysErrorList != null && !sysErrorList.isEmpty()) {
                                    for (SystemError err : sysErrorList) {
                                        String sev = err.getSeverity() != null ? err.getSeverity().toUpperCase() : "LOW";
                                        String bClass = "badge-blue";
                                        if ("CRITICAL".equals(sev)) bClass = "badge-red";
                                        else if ("HIGH".equals(sev)) bClass = "badge-amber"; %>
                                    <tr>
                                        <td style="font-size: 12px; color: var(--text-muted);"><%= err.getCreatedAt() != null ? err.getCreatedAt() : "-" %></td>
                                        <td><b><%= err.getModuleName() != null ? err.getModuleName() : "-" %></b></td>
                                        <td><span class="badge-pill <%= bClass %>"><%= sev %></span></td>
                                        <td><span class="code-chip"><%= err.getErrorType() != null ? err.getErrorType() : "-" %></span></td>
                                        <td style="max-width: 340px; word-break: break-word;"><%= err.getErrorMessage() != null ? err.getErrorMessage() : "-" %></td>
                                        <td><b><%= err.getUserId() != null && err.getUserId() > 0 ? "#" + err.getUserId() : "-" %></b></td>
                                    </tr>
                                <% } } else { %>
                                    <tr><td colspan="6" style="text-align: center; padding: 40px; color: #059669; font-weight: 700;">✔ Zero unhandled exceptions recorded. System healthy.</td></tr>
                                <% } %>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>

            <!-- SYS TAB 6: DATABASE BACKUPS & RECOVERY -->
            <div id="tab-sysbackups" class="tab-pane <%= "tab-sysbackups".equals(activeTab) ? "active" : "" %>">
                <div class="grid-3">
                    <div class="stat-card blue">
                        <div class="stat-lbl">Total Backup Archives</div>
                        <div class="stat-val" style="color: var(--brand-primary);"><%= sysTotalBackups %></div>
                    </div>
                    <div class="stat-card green">
                        <div class="stat-lbl">Verified Snapshots</div>
                        <div class="stat-val" style="color: #059669;"><%= sysSuccessBackups %></div>
                    </div>
                    <div class="stat-card amber">
                        <div class="stat-lbl">Latest Snapshot Time</div>
                        <div class="stat-val" style="font-size: 17px; margin-top: 8px;"><%= sysLatestBackupTime %></div>
                    </div>
                </div>

                <div class="card" style="border-left: 4.5px solid var(--emerald); display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 16px;">
                    <div>
                        <h3 style="font-size: 16.5px; font-weight: 800; color: #1e3a8a;">▶ Initiate Point-in-Time Database Snapshot</h3>
                        <p style="font-size: 13px; color: var(--text-muted); margin-top: 2px;">Exports database settings, employee directory, audit trails, and security logs into an immutable SQL file.</p>
                    </div>
                    <form method="post" action="<%= request.getRequestURI() %>" onsubmit="return confirm('Generate complete SQL database snapshot now?');">
                        <input type="hidden" name="sysAction" value="generateBackup">
                        <button type="submit" class="btn-action btn-emerald" style="height: 44px; padding: 0 22px; font-size: 13.5px;">
                            💾 Initiate Full Backup Now
                        </button>
                    </form>
                </div>

                <div class="card">
                    <h3 style="font-size: 16px; font-weight: 800; margin-bottom: 14px;">Historical Database Snapshots</h3>
                    <div class="table-wrapper">
                        <table>
                            <thead>
                                <tr>
                                    <th>Timestamp</th>
                                    <th>Backup File Name</th>
                                    <th>Type</th>
                                    <th>Verification</th>
                                    <th>Size</th>
                                    <th style="text-align: right;">Actions</th>
                                </tr>
                            </thead>
                            <tbody>
                                <% if (sysBackupRows != null && !sysBackupRows.isEmpty()) {
                                    for (Object[] bk : sysBackupRows) {
                                        long bId = (Long) bk[0];
                                        String bFile = (String) bk[1];
                                        String bType = (String) bk[2];
                                        long bSize = (Long) bk[4]; %>
                                    <tr>
                                        <td style="font-size: 12.5px; color: var(--text-muted);"><%= bk[5] %></td>
                                        <td><span class="code-chip"><%= bFile %></span></td>
                                        <td><b><%= bType != null ? bType : "FULL" %></b></td>
                                        <td><span class="badge-pill badge-green">✔ SUCCESS</span></td>
                                        <td><b><%= (bSize > 1024) ? (bSize / 1024) + " KB" : bSize + " B" %></b></td>
                                        <td style="text-align: right;">
                                            <a href="<%= request.getContextPath() %>/dashboard.jsp?downloadBackup=<%= bFile %>" class="btn-action" style="height: 30px; font-size: 11.5px; background: #eff6ff; color: var(--brand-primary);">📥 Download</a>
                                            <a href="<%= request.getContextPath() %>/dashboard.jsp?deleteBackup=<%= bId %>" class="btn-action btn-reject" style="height: 30px; font-size: 11.5px; margin-left: 6px;" onclick="return confirm('Delete this backup archive?');">🗑 Delete</a>
                                        </td>
                                    </tr>
                                <% } } else { %>
                                    <tr><td colspan="6" style="text-align: center; padding: 40px; color: var(--text-muted);">No database snapshots recorded yet. Click <b>Initiate Full Backup Now</b> above.</td></tr>
                                <% } %>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
            <% } %>

        </div>
    </div>

    <!-- Modal Popup for Instant Payslip View -->
    <div id="payslipModal" class="modal-overlay" onclick="closePayslipModal(event)">
        <div class="modal-content" onclick="event.stopPropagation()">
            <div class="modal-header">
                <h3 style="font-size: 14px; font-weight: 700;">💵 Payslip Document View</h3>
                <button type="button" onclick="closePayslipModal()" style="background: transparent; border: none; color: #fff; font-size: 20px; cursor: pointer;">×</button>
            </div>
            <iframe id="modalFrame" class="modal-iframe" src=""></iframe>
        </div>
    </div>

    <!-- Complete Client-Side Engine -->
    <script>
    function toggleMobileSidebar() {
        const sidebar = document.getElementById('appSidebar');
        const overlay = document.getElementById('sidebarOverlay');
        sidebar.classList.toggle('mobile-open');
        overlay.classList.toggle('active');
    }

    window.addEventListener('DOMContentLoaded', () => {
        const urlParams = new URLSearchParams(window.location.search);
        const activeTabParam = urlParams.get('tab');
        if (activeTabParam) {
            switchAdminTab(activeTabParam);
        }
    });

    const employeeCatalog = {
    <% 
        if (activeEmpList != null) {
            for (int i = 0; i < activeEmpList.size(); i++) {
                Employee emp = activeEmpList.get(i);
                java.util.Map<String, String> pMap = payrollDao.getEmployeeProfileForSalary(emp.getEmployeeId());
                String eId = (emp.getEmployeeId() != null) ? emp.getEmployeeId().trim().toUpperCase() : "";
                String eName = pMap.getOrDefault("name", (emp.getName() != null ? emp.getName() : ""));
                String eDept = pMap.getOrDefault("department", "IT");
                String eRole = pMap.getOrDefault("designation", "Staff");
                String eEmail = pMap.getOrDefault("email", "");
                String bName = pMap.getOrDefault("bankName", "");
                String bAcc = pMap.getOrDefault("bankAccount", "");
                String basic = pMap.getOrDefault("basicSalary", "0");
    %>
        "<%= eId %>": {
            name: "<%= eName.replace("\\", "\\\\").replace("\"", "\\\"") %>",
            dept: "<%= eDept.replace("\\", "\\\\").replace("\"", "\\\"") %>",
            role: "<%= eRole.replace("\\", "\\\\").replace("\"", "\\\"") %>",
            email: "<%= eEmail.replace("\\", "\\\\").replace("\"", "\\\"") %>",
            bankName: "<%= "-".equals(bName) ? "" : bName.replace("\\", "\\\\").replace("\"", "\\\"") %>",
            bankAccount: "<%= "-".equals(bAcc) ? "" : bAcc.replace("\\", "\\\\").replace("\"", "\\\"") %>",
            basicSalary: "<%= basic %>"
        }<%= (i < activeEmpList.size() - 1) ? "," : "" %>
    <% 
            }
        }
    %>
    };

    function switchAdminTab(tabId, el) {
        document.querySelectorAll('.tab-pane').forEach(pane => pane.classList.remove('active'));
        document.querySelectorAll('.nav-item').forEach(item => item.classList.remove('active'));

        const targetPane = document.getElementById(tabId);
        if (targetPane) targetPane.classList.add('active');

        if (el) {
            el.classList.add('active');
            const titleText = el.innerText.replace(/[^\w\s&]/gi, '').trim();
            document.getElementById('adminHeaderTitle').innerText = titleText;
        } else {
            const navItems = document.querySelectorAll('.nav-item');
            navItems.forEach(item => {
                if (item.getAttribute('onclick') && item.getAttribute('onclick').includes(tabId)) {
                    item.classList.add('active');
                    const titleText = item.innerText.replace(/[^\w\s&]/gi, '').trim();
                    document.getElementById('adminHeaderTitle').innerText = titleText;
                }
            });
        }

        if (window.innerWidth <= 900) {
            const sidebar = document.getElementById('appSidebar');
            const overlay = document.getElementById('sidebarOverlay');
            if (sidebar.classList.contains('mobile-open')) {
                sidebar.classList.remove('mobile-open');
                overlay.classList.remove('active');
            }
        }
    }

    function previewCompanyLogo(url) {
        const img = document.getElementById('logoPreviewImg');
        const placeholder = document.getElementById('logoPlaceholderTxt');
        if (!img) return;
        if (url && url.trim().startsWith('http')) {
            img.src = url.trim();
            img.style.display = 'block';
            if (placeholder) placeholder.style.display = 'none';
        } else {
            img.style.display = 'none';
            if (placeholder) placeholder.style.display = 'inline';
        }
    }
    async function uploadToCloudinary(fileInput) {
        const file = fileInput.files[0];
        if (!file) return;

        const CLOUD_NAME = "YOUR_CLOUD_NAME";
        const UPLOAD_PRESET = "YOUR_UNSIGNED_PRESET";

        const statusEl = document.getElementById('cloudinaryUploadStatus');
        if (CLOUD_NAME === "YOUR_CLOUD_NAME") {
            statusEl.innerHTML = '<span style="color:#d97706;">Paste Cloudinary URL directly or set Cloud Name in JS</span>';
            return;
        }

        statusEl.innerHTML = '<span style="color:#2563eb;">Uploading...</span>';
        const formData = new FormData();
        formData.append("file", file);
        formData.append("upload_preset", UPLOAD_PRESET);

        try {
            const res = await fetch(`https://api.cloudinary.com/v1_1/${CLOUD_NAME}/image/upload`, {
                method: "POST",
                body: formData
            });
            const data = await res.json();
            if (data.secure_url) {
                document.getElementById('cloudinaryUrlInput').value = data.secure_url;
                previewCloudinaryLogo(data.secure_url);
                statusEl.innerHTML = '<span style="color:#059669;">✔ Ready! Click Save Logo</span>';
            } else {
                statusEl.innerHTML = '<span style="color:#dc2626;">Upload failed</span>';
            }
        } catch (err) {
            statusEl.innerHTML = '<span style="color:#dc2626;">Network error</span>';
        }
    }

    function filterSimpleTable(inputId, tbodyId) {
        const query = document.getElementById(inputId).value.toLowerCase().trim();
        const rows = document.getElementById(tbodyId).querySelectorAll('tr');
        rows.forEach(row => {
            const text = row.innerText.toLowerCase();
            row.style.display = text.includes(query) ? '' : 'none';
        });
    }

    function handleInlineEmpIdInput(val) {
        const cleanId = (val || '').trim().toUpperCase();
        const statusDiv = document.getElementById('inlineFetchStatus');

        if (!cleanId) {
            clearInlineFields();
            return;
        }

        const empData = employeeCatalog[cleanId];

        if (empData) {
            applyInlineValue('inlineEmpName', empData.name);
            applyInlineValue('inlineDepartment', empData.dept);
            applyInlineValue('inlineDesignation', empData.role);
            applyInlineValue('inlineJoiningDate', '-');

            const emailInput = document.getElementById('inlineEmpEmail');
            if (emailInput) emailInput.value = empData.email || '';

            const bankNameInput = document.getElementById('inlineBankName');
            const bankAccInput = document.getElementById('inlineBankAccount');
            
            if (bankNameInput) bankNameInput.value = empData.bankName;
            if (bankAccInput) {
                bankAccInput.value = empData.bankAccount;
                checkDuplicateAccount(bankAccInput.value);
            }

            if (empData.basicSalary && parseFloat(empData.basicSalary) > 0) {
                const basic = parseFloat(empData.basicSalary);
                const estimatedGross = Math.round(basic / 0.3715);
                document.getElementById('inlineMonthlyGross').value = estimatedGross;
                document.getElementById('inlineAnnualCtc').value = Math.round(estimatedGross * 12);
                applyInlinePercentages(estimatedGross);
            }

            if (statusDiv) {
                statusDiv.innerHTML = '<span style="color: #059669;">✔ Verified: ' + empData.name + ' (' + empData.dept + ')</span>';
            }
        } else {
            clearInlineFields();
            if (statusDiv) {
                statusDiv.innerHTML = '<span style="color: #ef4444;">⚠ Record not found for "' + cleanId + '"</span>';
            }
        }
    }

    function checkDuplicateAccount(accNo) {
        const cleanAcc = (accNo || '').trim();
        const currentEmpId = document.getElementById('inlineEmpIdInput').value.trim().toUpperCase();
        const errorDiv = document.getElementById('accountErrorMsg');
        const accInput = document.getElementById('inlineBankAccount');
        const submitBtn = document.getElementById('commitStructureBtn');

        if (!cleanAcc) {
            if (errorDiv) errorDiv.innerHTML = '';
            if (accInput) {
                accInput.style.borderColor = 'var(--border-subtle)';
                accInput.style.boxShadow = 'none';
            }
            if (submitBtn) submitBtn.disabled = false;
            return;
        }

        let duplicateOwner = null;
        for (const [id, emp] of Object.entries(employeeCatalog)) {
            if (id !== currentEmpId && emp.bankAccount && emp.bankAccount.trim() === cleanAcc) {
                duplicateOwner = emp.name + ' (' + id + ')';
                break;
            }
        }

        if (duplicateOwner) {
            if (errorDiv) errorDiv.innerHTML = '<span style="color: #dc2626;">⚠ Account already registered to ' + duplicateOwner + '</span>';
            if (accInput) {
                accInput.style.borderColor = '#dc2626';
                accInput.style.boxShadow = '0 0 0 3px rgba(220, 38, 38, 0.15)';
            }
            if (submitBtn) submitBtn.disabled = true;
        } else {
            if (errorDiv) errorDiv.innerHTML = '<span style="color: #059669;">✔ Account number available</span>';
            if (accInput) {
                accInput.style.borderColor = '#10b981';
                accInput.style.boxShadow = '0 0 0 3px rgba(16, 185, 129, 0.15)';
            }
            if (submitBtn) submitBtn.disabled = false;
        }
    }

    function applyInlineValue(id, val) {
        const el = document.getElementById(id);
        if (el) {
            el.value = val;
            el.classList.add('glow-success');
            setTimeout(() => el.classList.remove('glow-success'), 900);
        }
    }

    function clearInlineFields() {
        ['inlineEmpName', 'inlineDepartment', 'inlineDesignation', 'inlineJoiningDate', 'inlineBankName', 'inlineBankAccount', 'inlineEmpEmail'].forEach(id => {
            const el = document.getElementById(id);
            if (el) el.value = '';
        });
        const errDiv = document.getElementById('accountErrorMsg');
        if (errDiv) errDiv.innerHTML = '';
        const accInput = document.getElementById('inlineBankAccount');
        if (accInput) {
            accInput.style.borderColor = 'var(--border-subtle)';
            accInput.style.boxShadow = 'none';
        }
        const submitBtn = document.getElementById('commitStructureBtn');
        if (submitBtn) submitBtn.disabled = false;
        const statusDiv = document.getElementById('inlineFetchStatus');
        if (statusDiv) statusDiv.innerHTML = '';
    }

    function toggleComponent(inputId, isEnabled) {
        const input = document.getElementById(inputId);
        if (!input) return;
        input.disabled = !isEnabled;
        if (!isEnabled) {
            input.value = 0;
        } else {
            const gross = parseFloat(document.getElementById('inlineMonthlyGross').value) || 0;
            if (gross > 0) applyInlinePercentages(gross);
        }
    }

    function applyPercentageHike(pct) {
        const hikePct = parseFloat(pct);
        if (isNaN(hikePct) || hikePct === 0) return;

        let currentAnnual = parseFloat(document.getElementById('inlineAnnualCtc').value);
        let currentMonthly = parseFloat(document.getElementById('inlineMonthlyGross').value);

        if ((!currentAnnual || currentAnnual <= 0) && (!currentMonthly || currentMonthly <= 0)) {
            alert('Please enter an Annual CTC or Monthly Gross package first to simulate a hike.');
            return;
        }

        if (!currentMonthly || currentMonthly <= 0) {
            currentMonthly = currentAnnual / 12;
        }

        const newGross = Math.round(currentMonthly * (1 + (hikePct / 100)));
        document.getElementById('inlineMonthlyGross').value = newGross;
        document.getElementById('inlineAnnualCtc').value = Math.round(newGross * 12);
        applyInlinePercentages(newGross);

        const statusDiv = document.getElementById('inlineFetchStatus');
        if (statusDiv) {
            statusDiv.innerHTML = '<span style="color: #16a34a;">🚀 Applied +' + hikePct + '% Hike! New Gross: ₹' + newGross.toLocaleString('en-IN') + '</span>';
        }
    }

    function calculateInlineFromAnnual(annualVal) {
        if (!annualVal || parseFloat(annualVal) <= 0) return;
        const gross = (parseFloat(annualVal) / 12).toFixed(2);
        document.getElementById('inlineMonthlyGross').value = gross;
        applyInlinePercentages(parseFloat(gross));
    }

    function calculateInlineFromMonthly(monthlyVal) {
        if (!monthlyVal || parseFloat(monthlyVal) <= 0) return;
        const gross = parseFloat(monthlyVal);
        document.getElementById('inlineAnnualCtc').value = Math.round(gross * 12);
        applyInlinePercentages(gross);
    }

    function applyInlinePercentages(gross) {
        const basic = Math.round(gross * 0.3715);
        document.getElementById('inlineBasic').value = basic;

        const isDaActive = document.getElementById('toggle_da').checked;
        const da = isDaActive ? Math.round(basic * 0.55) : 0;
        document.getElementById('inlineDa').value = da;

        const isHraActive = document.getElementById('toggle_hra').checked;
        const hra = isHraActive ? Math.round(basic * 0.50) : 0;
        document.getElementById('inlineHra').value = hra;

        const isConvActive = document.getElementById('toggle_conveyance').checked;
        const conveyance = isConvActive ? 1600 : 0;
        document.getElementById('inlineConveyance').value = conveyance;

        const isMedActive = document.getElementById('toggle_medical').checked;
        const medical = isMedActive ? 1250 : 0;
        document.getElementById('inlineMedical').value = medical;

        const isSpecialActive = document.getElementById('toggle_special').checked;
        const sumFixed = basic + da + hra + conveyance + medical;
        let special = 0;
        if (isSpecialActive) {
            special = Math.round(gross - sumFixed);
            if (special < 0) special = 0;
        }
        document.getElementById('inlineSpecial').value = special;

        document.getElementById('inlineProfTax').value = 200;
        if (gross >= 40000) {
            document.getElementById('inlinePf').value = 3600;
        } else {
            document.getElementById('inlinePf').value = Math.round(basic * 0.12);
        }
    }

    function openInlineDisburse(payrollId, empId, period, amount) {
        document.getElementById('disbursePayrollId').value = payrollId;
        document.getElementById('disburseEmpLabel').innerText = empId;
        document.getElementById('disbursePeriodLabel').innerText = period;
        document.getElementById('disburseAmountLabel').innerText = '₹ ' + amount;

        const empData = employeeCatalog[empId.trim().toUpperCase()];
        if (empData && empData.bankAccount) {
            document.getElementById('disburseBankLabel').innerText = (empData.bankName || 'Bank') + ' • ' + empData.bankAccount;
        } else {
            document.getElementById('disburseBankLabel').innerText = 'Bank Details Not Set';
        }

        const panel = document.getElementById('inlineDisbursePanel');
        panel.style.display = 'block';
        panel.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    }

    function closeInlineDisburse() {
        document.getElementById('inlineDisbursePanel').style.display = 'none';
    }

    function filterPayslipTable() {
        var searchVal = document.getElementById('slipSearchEmp').value.toLowerCase().trim();
        var monthVal = document.getElementById('slipFilterMonth').value;
        var yearVal = document.getElementById('slipFilterYear').value;

        var rows = document.querySelectorAll('.payslip-data-row');
        var visibleCount = 0;

        rows.forEach(function(row) {
            var empId = row.getAttribute('data-empid') || '';
            var empName = row.getAttribute('data-empname') || '';
            var rowMonth = row.getAttribute('data-month') || '';
            var rowYear = row.getAttribute('data-year') || '';

            var matchesSearch = (searchVal === '') || empId.includes(searchVal) || empName.includes(searchVal);
            var matchesMonth = (monthVal === 'ALL') || (rowMonth === monthVal);
            var matchesYear = (yearVal === 'ALL') || (rowYear === yearVal);

            if (matchesSearch && matchesMonth && matchesYear) {
                row.style.display = '';
                visibleCount++;
                var idxCell = row.querySelector('.row-index');
                if (idxCell) idxCell.innerText = visibleCount;
            } else {
                row.style.display = 'none';
            }
        });

        var noRow = document.getElementById('noPayslipsRow');
        if (noRow) {
            noRow.style.display = (visibleCount === 0) ? '' : 'none';
        }
    }

    function resetPayslipFilters() {
        document.getElementById('slipSearchEmp').value = '';
        document.getElementById('slipFilterMonth').value = 'ALL';
        document.getElementById('slipFilterYear').value = 'ALL';
        filterPayslipTable();
    }

    function openPayslipModal(url) {
        document.getElementById('modalFrame').src = url;
        document.getElementById('payslipModal').style.display = 'flex';
    }

    function closePayslipModal(e) {
        document.getElementById('payslipModal').style.display = 'none';
        document.getElementById('modalFrame').src = '';
    }

    setInterval(() => {
        const el = document.getElementById('liveClockDisplay');
        if (el) {
            el.innerText = new Date().toLocaleTimeString();
        }
    }, 1000);
    </script>
</body>
</html>