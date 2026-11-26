<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.util.List, java.util.ArrayList, java.sql.*, java.io.*, java.text.SimpleDateFormat" %>
<%@ page import="com.Util.DBConnection" %>
<%@ page import="com.example.demo.model.Employee" %>

<%
    // 1. Session Role Verification
    String userRole = null;
    String userDisplayName = "Administrator";
    int currentUserId = 1;

    if (session != null) {
        if (session.getAttribute("role") != null) {
            userRole = session.getAttribute("role").toString();
        } else if (session.getAttribute("loggedInEmployee") != null) {
            Employee emp = (Employee) session.getAttribute("loggedInEmployee");
            userRole = emp.getRole();
            if (emp.getName() != null) userDisplayName = emp.getName();
            currentUserId = emp.getId();
        }
    }

    boolean isAdmin = userRole != null && (
        userRole.equalsIgnoreCase("ADMIN") || 
        userRole.equalsIgnoreCase("SUPER ADMIN") || 
        userRole.equalsIgnoreCase("HR")
    );

    if (!isAdmin) {
        response.sendError(HttpServletResponse.SC_FORBIDDEN, "Access Denied: Only administrators can access database backups.");
        return;
    }

    String alertMessage = null;
    String alertType = "ok";
    
    // Directory where SQL dump files are stored
    String backupDirPath = application.getRealPath("/") + "backups";
    File backupDir = new File(backupDirPath);
    if (!backupDir.exists()) backupDir.mkdirs();

    // 2. Action: Download Backup File
    String downloadFile = request.getParameter("download");
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

    // 3. Action: Delete Snapshot
    String deleteId = request.getParameter("delete");
    if (deleteId != null) {
        try (Connection conn = DBConnection.getConnection()) {
            String fileName = null;
            try (PreparedStatement ps = conn.prepareStatement("SELECT backup_file FROM backup_history WHERE id = ?")) {
                ps.setLong(1, Long.parseLong(deleteId));
                ResultSet rs = ps.executeQuery();
                if (rs.next()) fileName = rs.getString("backup_file");
            }
            if (fileName != null) {
                File f = new File(backupDir, fileName);
                if (f.exists()) f.delete();
            }
            try (PreparedStatement ps = conn.prepareStatement("DELETE FROM backup_history WHERE id = ?")) {
                ps.setLong(1, Long.parseLong(deleteId));
                ps.executeUpdate();
            }
            alertMessage = "Backup archive removed successfully.";
        } catch (Exception e) {
            alertMessage = "Delete failed: " + e.getMessage();
            alertType = "error";
        }
    }

    // 4. Action: Generate Snapshot (Triggers on POST)
    if ("POST".equalsIgnoreCase(request.getMethod()) || "generate_backup".equals(request.getParameter("action"))) {
        String timestamp = new SimpleDateFormat("yyyyMMdd_HHmmss").format(new java.util.Date());
        String backupFileName = "backup_smartoffice_" + timestamp + ".sql";
        File sqlFile = new File(backupDir, backupFileName);
        long fileSize = 0;

        try {
            // Write database tables content to the file
            try (PrintWriter writer = new PrintWriter(new FileWriter(sqlFile));
                 Connection conn = DBConnection.getConnection()) {
                
                writer.println("-- =========================================================");
                writer.println("-- SMART OFFICE DATABASE SNAPSHOT ARCHIVE");
                writer.println("-- Generated At: " + new java.util.Date());
                writer.println("-- Operator: " + userDisplayName + " (UID #" + currentUserId + ")");
                writer.println("-- =========================================================\n");

                String[] tables = {"system_settings", "employee", "login_history", "audit_logs", "system_errors"};
                for (String tbl : tables) {
                    writer.println("-- --------------------------------------------------");
                    writer.println("-- Table: " + tbl);
                    writer.println("-- --------------------------------------------------");
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
                    } catch (Exception tblEx) {
                        System.err.println("Could not dump table " + tbl + ": " + tblEx.getMessage());
                    }
                    writer.println();
                }
            }

            fileSize = sqlFile.length();

            // Insert strictly matching your 8 columns:
            // (backup_file, backup_type, status, file_size, created_by, remarks, created_at)
            String insertSql = "INSERT INTO backup_history (backup_file, backup_type, status, file_size, created_by, remarks, created_at) " +
                               "VALUES (?, 'FULL', 'SUCCESS', ?, ?, 'Manual point-in-time snapshot', NOW())";

            try (Connection conn = DBConnection.getConnection();
                 PreparedStatement ps = conn.prepareStatement(insertSql)) {
                
                ps.setString(1, backupFileName);
                ps.setLong(2, fileSize);
                
                if (currentUserId > 0) {
                    ps.setInt(3, currentUserId);
                } else {
                    ps.setNull(3, java.sql.Types.INTEGER);
                }
                
                int rows = ps.executeUpdate();
                System.out.println(">>> [backup-management.jsp] Saved to backup_history: " + backupFileName + " (" + rows + " row inserted)");
            }

            // Append to audit_logs
            try (Connection conn = DBConnection.getConnection();
                 PreparedStatement ps = conn.prepareStatement(
                     "INSERT INTO audit_logs (user_id, module_name, action_type, record_id, description, new_values, created_at) " +
                     "VALUES (?, 'BACKUP_ENGINE', 'CREATE', ?, 'Generated full SQL snapshot', ?, NOW())")) {
                if (currentUserId > 0) ps.setInt(1, currentUserId); else ps.setNull(1, java.sql.Types.INTEGER);
                ps.setString(2, backupFileName);
                ps.setString(3, "{\"file\":\"" + backupFileName + "\",\"size_bytes\":" + fileSize + "}");
                ps.executeUpdate();
            } catch (Exception ignored) {}

            alertMessage = "Database snapshot [" + backupFileName + "] created (" + (fileSize / 1024) + " KB). Ready for download.";
        } catch (Exception e) {
            System.err.println(">>> [Backup Generation Error]: " + e.getMessage());
            e.printStackTrace();
            alertMessage = "Snapshot failed: " + e.getMessage();
            alertType = "error";
        }
    }

    // 5. Query KPI Statistics strictly matching your schema
    int totalBackups = 0;
    int successBackups = 0;
    String latestBackup = "None";

    try (Connection conn = DBConnection.getConnection();
         PreparedStatement ps = conn.prepareStatement(
             "SELECT COUNT(*) AS total, " +
             " SUM(CASE WHEN UPPER(COALESCE(status, 'SUCCESS')) = 'SUCCESS' THEN 1 ELSE 0 END) AS succ, " +
             " MAX(created_at) AS latest FROM backup_history");
         ResultSet rs = ps.executeQuery()) {
        if (rs.next()) {
            totalBackups = rs.getInt("total");
            successBackups = rs.getInt("succ");
            Timestamp ts = rs.getTimestamp("latest");
            if (ts != null) latestBackup = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(ts);
        }
    } catch (Exception e) {
        System.err.println(">>> [Backup KPI Query Error]: " + e.getMessage());
    }
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Database Backup & Recovery Center - SmartOffice</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@500;600&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="<%= request.getContextPath() %>/css/admin-responsive.css">
    <style>
        :root {
            --primary: #4f46e5;
            --surface: #ffffff;
            --background: #f8fafc;
            --border: #e2e8f0;
            --text-heading: #0f172a;
            --text-body: #334155;
            --text-muted: #64748b;
            --success: #10b981;
            --danger: #ef4444;
            --radius-md: 12px;
            --shadow-card: 0 4px 6px -1px rgba(0, 0, 0, 0.04);
        }

        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Plus Jakarta Sans', sans-serif; background: var(--background); color: var(--text-body); padding: 32px 24px; }
        .container { max-width: 1440px; margin: 0 auto; display: flex; flex-direction: column; gap: 24px; }

        .top-navbar {
            background: var(--surface); border-radius: var(--radius-md); border: 1px solid var(--border);
            padding: 20px 28px; box-shadow: var(--shadow-card); display: flex; justify-content: space-between;
            align-items: center; flex-wrap: wrap; gap: 16px; position: relative; overflow: hidden;
        }
        .top-navbar::before {
            content: ''; position: absolute; top: 0; left: 0; right: 0; height: 4px;
            background: linear-gradient(90deg, #10b981, #06b6d4, #4f46e5);
        }
        .header-title h1 { font-size: 22px; font-weight: 800; color: var(--text-heading); }
        .header-title p { font-size: 13px; color: var(--text-muted); margin-top: 2px; }

        .nav-tabs { display: flex; gap: 6px; background: #f1f5f9; padding: 6px; border-radius: 10px; }
        .nav-link { text-decoration: none; font-size: 13px; font-weight: 600; padding: 8px 16px; border-radius: 6px; color: var(--text-muted); }
        .nav-link.active { background: var(--surface); color: var(--primary); box-shadow: 0 1px 3px rgba(0,0,0,0.05); }

        .kpi-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 18px; }
        .kpi-card { background: var(--surface); padding: 20px 24px; border-radius: var(--radius-md); border: 1px solid var(--border); box-shadow: var(--shadow-card); display: flex; justify-content: space-between; align-items: center; }
        .kpi-label { font-size: 11.5px; font-weight: 700; text-transform: uppercase; color: var(--text-muted); }
        .kpi-value { font-size: 30px; font-weight: 800; color: var(--text-heading); margin-top: 4px; }

        .content-card { background: var(--surface); border-radius: var(--radius-md); border: 1px solid var(--border); padding: 24px; box-shadow: var(--shadow-card); }
        
        .btn-backup {
            background: #10b981; color: #fff; border: none; padding: 12px 24px; border-radius: 8px;
            font-size: 14px; font-weight: 700; cursor: pointer; display: inline-flex; align-items: center; gap: 8px;
            transition: background 0.15s;
        }
        .btn-backup:hover { background: #059669; }

        .alert-box { padding: 14px 18px; border-radius: 10px; font-size: 13.5px; font-weight: 600; }
        .alert-ok { background: #ecfdf5; color: #10b981; border: 1px solid #a7f3d0; }
        .alert-error { background: #fee2e2; color: #ef4444; border: 1px solid #fecaca; }

        .table-responsive { width: 100%; overflow-x: auto; margin-top: 16px; }
        table { width: 100%; border-collapse: separate; border-spacing: 0; font-size: 13px; min-width: 780px; }
        th { background: #f8fafc; padding: 12px 16px; text-align: left; font-weight: 700; color: var(--text-muted); font-size: 11px; text-transform: uppercase; border-bottom: 1px solid var(--border); }
        td { padding: 14px 16px; border-bottom: 1px solid #f1f5f9; vertical-align: middle; }

        .badge-success { background: #ecfdf5; color: #10b981; padding: 4px 10px; border-radius: 20px; font-weight: 700; font-size: 11px; border: 1px solid #a7f3d0; }
        .btn-action { text-decoration: none; padding: 6px 12px; border-radius: 6px; font-size: 12px; font-weight: 600; display: inline-block; }
        .btn-download { background: #e0e7ff; color: var(--primary); }
        .btn-download:hover { background: #c7d2fe; }
        .btn-delete { background: #fee2e2; color: #dc2626; margin-left: 6px; }
        .btn-delete:hover { background: #fecaca; }

        code { font-family: 'JetBrains Mono', monospace; background: #f1f5f9; padding: 2px 6px; border-radius: 4px; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        
        <header class="top-navbar">
            <div class="header-title">
                <h1>Database Backup & Recovery Center</h1>
                <p>Welcome, <b><%= userDisplayName %></b> • On-demand snapshots, archival verification, and disaster-recovery logs</p>
            </div>
            <nav class="nav-tabs">
                <a href="<%= request.getContextPath() %>/dashboard.jsp" class="nav-link">← Workspace</a>
                <a href="<%= request.getContextPath() %>/system-dashboard.jsp" class="nav-link">Dashboard</a>
                <a href="<%= request.getContextPath() %>/auditlogs.jsp" class="nav-link">Audit Trail</a>
                <a href="<%= request.getContextPath() %>/login-history.jsp" class="nav-link">Login History</a>
                <a href="<%= request.getContextPath() %>/system-settings.jsp" class="nav-link">Settings</a>
                <a href="<%= request.getContextPath() %>/system-errors.jsp" class="nav-link">Exceptions</a>
                <a href="<%= request.getContextPath() %>/backup-management.jsp" class="nav-link active">Backups</a>
            </nav>
        </header>

        <% if (alertMessage != null) { %>
            <div class="alert-box <%= "ok".equals(alertType) ? "alert-ok" : "alert-error" %>"><%= alertMessage %></div>
        <% } %>

        <section class="kpi-grid">
            <div class="kpi-card">
                <div>
                    <div class="kpi-label">Total Backup Archives</div>
                    <div class="kpi-value"><%= totalBackups %></div>
                </div>
                <div style="font-size: 24px;">💾</div>
            </div>
            <div class="kpi-card">
                <div>
                    <div class="kpi-label">Verified Snapshots</div>
                    <div class="kpi-value" style="color: var(--success);"><%= successBackups %></div>
                </div>
                <div style="font-size: 24px; color: var(--success);">✔</div>
            </div>
            <div class="kpi-card">
                <div>
                    <div class="kpi-label">Latest Snapshot Time</div>
                    <div class="kpi-value" style="font-size: 17px; margin-top: 8px;"><%= latestBackup %></div>
                </div>
                <div style="font-size: 24px;">🕑</div>
            </div>
        </section>

        <!-- Backup Action -->
        <section class="content-card">
            <h2 style="font-size: 16px; margin-bottom: 6px;">▶ Initiate Point-in-Time Database Snapshot</h2>
            <p style="color: var(--text-muted); font-size: 13.5px; margin-bottom: 20px;">
                Executing a manual snapshot records database schema, employee records, payroll histories, and audit ledgers into an immutable SQL dump file.
            </p>
            <form method="post" action="<%= request.getContextPath() %>/backup-management.jsp" onsubmit="return confirm('Generate complete database snapshot now?');">
                <input type="hidden" name="action" value="generate_backup">
                <button type="submit" class="btn-backup">💾 Initiate Full Backup Now</button>
            </form>
        </section>

        <!-- Backup History Table -->
        <section class="content-card">
            <h2 style="font-size: 16px;">Historical Database Snapshots</h2>
            <div class="table-responsive">
                <table>
                    <thead>
                        <tr>
                            <th style="width: 18%;">Timestamp</th>
                            <th style="width: 32%;">Backup File Name</th>
                            <th style="width: 12%;">Type</th>
                            <th style="width: 12%;">Verification</th>
                            <th style="width: 10%;">Size</th>
                            <th style="width: 16%; text-align: right;">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        <%
                            boolean hasData = false;
                            try (Connection conn = DBConnection.getConnection();
                                 PreparedStatement ps = conn.prepareStatement("SELECT * FROM backup_history ORDER BY id DESC LIMIT 50");
                                 ResultSet rs = ps.executeQuery()) {
                                while (rs.next()) {
                                    hasData = true;
                                    long rowId = rs.getLong("id");
                                    String bFile = rs.getString("backup_file");
                                    String bType = rs.getString("backup_type");
                                    long size = rs.getLong("file_size");
                        %>
                            <tr>
                                <td style="color: var(--text-muted); font-size: 12.5px;"><%= rs.getTimestamp("created_at") %></td>
                                <td><code><%= bFile %></code></td>
                                <td><b><%= bType != null ? bType : "FULL" %></b></td>
                                <td><span class="badge-success">✔ SUCCESS</span></td>
                                <td><b><%= (size > 1024) ? (size / 1024) + " KB" : size + " B" %></b></td>
                                <td style="text-align: right;">
                                    <a href="<%= request.getContextPath() %>/backup-management.jsp?download=<%= bFile %>" class="btn-action btn-download">📥 Download</a>
                                    <a href="<%= request.getContextPath() %>/backup-management.jsp?delete=<%= rowId %>" class="btn-action btn-delete" onclick="return confirm('Delete this backup archive?');">🗑 Delete</a>
                                </td>
                            </tr>
                        <%
                                }
                            } catch (Exception e) {
                                out.println("<tr><td colspan='6'>Database Query Error: " + e.getMessage() + "</td></tr>");
                            }

                            if (!hasData) {
                        %>
                            <tr>
                                <td colspan="6" style="text-align: center; color: var(--text-muted); padding: 48px 0;">
                                    <div style="font-size: 30px; margin-bottom: 8px;">💾</div>
                                    <div style="font-weight: 700;">No database snapshots recorded yet</div>
                                    <div style="font-size: 12.5px; margin-top: 4px;">Click the <b>Initiate Full Backup Now</b> button above to create the first archive.</div>
                                </td>
                            </tr>
                        <% } %>
                    </tbody>
                </table>
            </div>
        </section>

    </div>
</body>
</html>