<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="com.example.demo.model.Employee,com.example.demo.model.Team,com.example.demo.model.Task,com.example.demo.model.Attendance,com.example.demo.model.Payroll,com.dao.PayrollDAO,com.dao.TaskDao,com.example.demo.model.OvertimeRequest, com.dao.OvertimeDAO" %>
<%@ page import="java.sql.*, java.util.*, java.time.Month, java.time.format.TextStyle, java.time.LocalTime, java.time.LocalDate" %>
<%
    Employee emp = (Employee) session.getAttribute("loggedInEmployee");
    if (emp == null) {
        response.sendRedirect(request.getContextPath() + "/login.jsp");
        return;
    }

    String empCode = (emp.getEmployeeId() != null) ? emp.getEmployeeId().trim() : "";
    String empName = (emp.getName() != null) ? emp.getName().trim() : "";
    int empNumericId = emp.getId();

    // =========================================================================
    // 1. DYNAMIC COMPANY LOGO & NAME LOADER
    // =========================================================================
    String companyLogoUrl = (String) application.getAttribute("COMPANY_LOGO_URL");
    String companyBrandName = (String) application.getAttribute("COMPANY_NAME");

    try {
        String propsPath = application.getRealPath("/WEB-INF/branding.properties");
        java.io.File propFile = new java.io.File(propsPath);
        if (propFile.exists()) {
            Properties props = new Properties();
            try (java.io.FileInputStream fis = new java.io.FileInputStream(propFile)) {
                props.load(fis);
            }
            if (companyLogoUrl == null || companyLogoUrl.isBlank()) companyLogoUrl = props.getProperty("COMPANY_LOGO_URL", "");
            if (companyBrandName == null || companyBrandName.isBlank()) companyBrandName = props.getProperty("COMPANY_NAME", "");
        }
    } catch (Exception ignored) {}

    if (companyBrandName == null || companyBrandName.isBlank()) {
        try (Connection conn = com.Util.DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement("SELECT setting_value FROM system_settings WHERE setting_key = 'COMPANY_NAME' LIMIT 1");
             ResultSet rs = ps.executeQuery()) {
            if (rs.next()) {
                String v = rs.getString("setting_value");
                if (v != null && !v.isBlank()) {
                    companyBrandName = v.trim();
                    application.setAttribute("COMPANY_NAME", companyBrandName);
                }
            }
        } catch (Exception ignored) {}
    }
    if (companyLogoUrl == null) companyLogoUrl = "";
    if (companyBrandName == null || companyBrandName.isBlank()) companyBrandName = "EMS Enterprise";

    // =========================================================================
    // 2. LOAD REQUEST ATTRIBUTES WITH SCHEMA-SAFE DAO & DB FALLBACKS
    // =========================================================================
    Map<String, Object> att = (Map<String, Object>) request.getAttribute("empAttendance");
    Team myTeam = (Team) request.getAttribute("myTeam");
    List<Employee> teamMembers = (List<Employee>) request.getAttribute("teamMembers");
    List<Task> myTasks = (List<Task>) request.getAttribute("myTasks");
    List<Attendance> attendanceHistory = (List<Attendance>) request.getAttribute("attendanceHistory");

    String debugTaskErr = "";
    String debugTeamErr = "";

    // A. Schema-Safe Tasks Fallback
    if (myTasks == null || myTasks.isEmpty()) {
        myTasks = new ArrayList<>();
        try (Connection conn = com.Util.DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement("SELECT * FROM tasks ORDER BY id DESC");
             ResultSet rs = ps.executeQuery()) {
            ResultSetMetaData md = rs.getMetaData();
            Set<String> cols = new HashSet<>();
            for (int i = 1; i <= md.getColumnCount(); i++) {
                cols.add(md.getColumnLabel(i).toLowerCase());
            }
            while (rs.next()) {
                boolean isMatch = false;
                String[] idCols = {"assigned_to", "employee_id", "assigned_to_id", "assignee_id", "user_id"};
                for (String c : idCols) {
                    if (cols.contains(c) && rs.getObject(c) != null) {
                        String val = String.valueOf(rs.getObject(c)).trim();
                        if (val.equalsIgnoreCase(empCode) || val.equals(String.valueOf(empNumericId))) {
                            isMatch = true;
                            break;
                        }
                    }
                }
                if (isMatch) {
                    Task t = new Task();
                    if (cols.contains("id")) t.setId(rs.getInt("id"));
                    if (cols.contains("task_title")) t.setTaskTitle(rs.getString("task_title"));
                    else if (cols.contains("title")) t.setTaskTitle(rs.getString("title"));

                    if (cols.contains("description")) t.setDescription(rs.getString("description"));
                    if (cols.contains("priority")) t.setPriority(rs.getString("priority"));
                    if (cols.contains("status")) t.setStatus(rs.getString("status"));

                    if (cols.contains("due_date") && rs.getDate("due_date") != null) {
                        t.setDueDate(rs.getDate("due_date").toLocalDate());
                    }
                    if (cols.contains("task_file_path")) t.setTaskFilePath(rs.getString("task_file_path"));
                    if (cols.contains("rating")) t.setRating(rs.getInt("rating"));
                    if (cols.contains("created_by_name")) t.setCreatedByName(rs.getString("created_by_name"));
                    myTasks.add(t);
                }
            }
        } catch (Exception e) {
            debugTaskErr = e.getMessage();
        }
    }
    try (Connection conn = com.Util.DBConnection.getConnection()) {
        // B. Today's Shift Status Fallback
        if (att == null) {
            att = new HashMap<>();
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT * FROM attendance WHERE LOWER(TRIM(employee_id)) = LOWER(TRIM(?)) AND attendance_date = CURRENT_DATE LIMIT 1")) {
                ps.setString(1, empCode);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        Time ci = rs.getTime("check_in_time");
                        Time co = rs.getTime("check_out_time");
                        Time b1s = rs.getTime("break1_start_time");
                        Time b1e = rs.getTime("break1_end_time");
                        Time b2s = rs.getTime("break2_start_time");
                        Time b2e = rs.getTime("break2_end_time");
                        String st = rs.getString("status");

                        att.put("clockIn", ci);
                        att.put("clockOut", co);
                        if ((b1s != null && b1e == null) || (b2s != null && b2e == null)) {
                            att.put("status", "ON_BREAK");
                        } else if (co != null) {
                            att.put("status", "CHECKED_OUT");
                        } else if (ci != null) {
                            att.put("status", st != null ? st : "PRESENT");
                        }
                    }
                }
            } catch (Exception ignored) {}
        }

        // C. Attendance History Fallback (Column-safe)
        if (attendanceHistory == null) {
            attendanceHistory = new ArrayList<>();
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT * FROM attendance WHERE LOWER(TRIM(employee_id)) = LOWER(TRIM(?)) ORDER BY attendance_date DESC LIMIT 30")) {
                ps.setString(1, empCode);
                try (ResultSet rs = ps.executeQuery()) {
                    ResultSetMetaData md = rs.getMetaData();
                    Set<String> cols = new HashSet<>();
                    for (int i = 1; i <= md.getColumnCount(); i++) {
                        cols.add(md.getColumnLabel(i).toLowerCase());
                    }
                    while (rs.next()) {
                        Attendance a = new Attendance();
                        if (cols.contains("attendance_id")) a.setAttendanceId(rs.getString("attendance_id"));
                        else if (cols.contains("id")) a.setAttendanceId(String.valueOf(rs.getObject("id")));

                        if (cols.contains("employee_id")) a.setEmployeeId(rs.getString("employee_id"));
                        if (cols.contains("attendance_date")) {
                            java.sql.Date d = rs.getDate("attendance_date");
                            if (d != null) a.setAttendanceDate(d.toLocalDate());
                        }
                        if (cols.contains("check_in_time") && rs.getTime("check_in_time") != null) {
                            a.setCheckInTime(rs.getTime("check_in_time").toLocalTime());
                        }
                        if (cols.contains("check_out_time") && rs.getTime("check_out_time") != null) {
                            a.setCheckOutTime(rs.getTime("check_out_time").toLocalTime());
                        }
                        if (cols.contains("break1_start_time") && rs.getTime("break1_start_time") != null) {
                            a.setBreak1StartTime(rs.getTime("break1_start_time").toLocalTime());
                        }
                        if (cols.contains("break1_end_time") && rs.getTime("break1_end_time") != null) {
                            a.setBreak1EndTime(rs.getTime("break1_end_time").toLocalTime());
                        }
                        if (cols.contains("break2_start_time") && rs.getTime("break2_start_time") != null) {
                            a.setBreak2StartTime(rs.getTime("break2_start_time").toLocalTime());
                        }
                        if (cols.contains("break2_end_time") && rs.getTime("break2_end_time") != null) {
                            a.setBreak2EndTime(rs.getTime("break2_end_time").toLocalTime());
                        }
                        if (cols.contains("net_working_minutes")) a.setNetWorkingMinutes(rs.getInt("net_working_minutes"));
                        if (cols.contains("approved_ot_hours")) a.setApprovedOtHours(rs.getDouble("approved_ot_hours"));
                        if (cols.contains("status")) a.setStatus(rs.getString("status"));
                        attendanceHistory.add(a);
                    }
                }
            } catch (Exception ignored) {}
        }

        // D. Team & Team Members Fallback (Checks both employee.team_id and team_members)
        if (myTeam == null || teamMembers == null) {
            int foundTeamId = 0;

            // Check if employee table stores team_id directly
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT team_id FROM employee WHERE LOWER(TRIM(employee_id)) = LOWER(TRIM(?)) LIMIT 1")) {
                ps.setString(1, empCode);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) foundTeamId = rs.getInt("team_id");
                }
            } catch (Exception ignored) {}

            // Otherwise check team_members mapping table
            if (foundTeamId == 0) {
                try (PreparedStatement ps = conn.prepareStatement("SELECT * FROM team_members")) {
                    try (ResultSet rs = ps.executeQuery()) {
                        ResultSetMetaData md = rs.getMetaData();
                        String empCol = null;
                        for (int i = 1; i <= md.getColumnCount(); i++) {
                            String colName = md.getColumnLabel(i).toLowerCase();
                            if (colName.contains("emp") || colName.contains("member") || colName.contains("user")) {
                                empCol = md.getColumnLabel(i);
                                break;
                            }
                        }
                        if (empCol != null) {
                            while (rs.next()) {
                                String val = String.valueOf(rs.getObject(empCol)).trim();
                                if (val.equalsIgnoreCase(empCode) || val.equals(String.valueOf(empNumericId))) {
                                    foundTeamId = rs.getInt("team_id");
                                    break;
                                }
                            }
                        }
                    }
                } catch (Exception ignored) {}
            }

            if (foundTeamId > 0) {
                if (myTeam == null) {
                    try (PreparedStatement ps = conn.prepareStatement("SELECT * FROM teams WHERE id = ?")) {
                        ps.setInt(1, foundTeamId);
                        try (ResultSet rs = ps.executeQuery()) {
                            if (rs.next()) {
                                myTeam = new Team();
                                myTeam.setId(foundTeamId);
                                myTeam.setTeamName(rs.getString("team_name"));
                            }
                        }
                    } catch (Exception ignored) {}
                }

                if (teamMembers == null) {
                    teamMembers = new ArrayList<>();
                    // Try fetching teammates via employee.team_id first
                    try (PreparedStatement ps = conn.prepareStatement("SELECT * FROM employee WHERE team_id = ?")) {
                        ps.setInt(1, foundTeamId);
                        try (ResultSet rs = ps.executeQuery()) {
                            while (rs.next()) {
                                Employee member = new Employee();
                                member.setId(rs.getInt("id"));
                                member.setEmployeeId(rs.getString("employee_id"));
                                member.setName(rs.getString("name"));
                                member.setRole(rs.getString("role"));
                                member.setEmail(rs.getString("email"));
                                teamMembers.add(member);
                            }
                        }
                    } catch (Exception ignored) {}

                    // If empty, fetch via team_members join
                    if (teamMembers.isEmpty()) {
                        try (PreparedStatement ps = conn.prepareStatement(
                                "SELECT e.* FROM employee e JOIN team_members tm ON " +
                                "(LOWER(TRIM(e.employee_id)) = LOWER(TRIM(CAST(tm.employee_id AS CHAR))) OR CAST(e.id AS CHAR) = CAST(tm.employee_id AS CHAR)) " +
                                "WHERE tm.team_id = ?")) {
                            ps.setInt(1, foundTeamId);
                            try (ResultSet rs = ps.executeQuery()) {
                                while (rs.next()) {
                                    Employee member = new Employee();
                                    member.setId(rs.getInt("id"));
                                    member.setEmployeeId(rs.getString("employee_id"));
                                    member.setName(rs.getString("name"));
                                    member.setRole(rs.getString("role"));
                                    member.setEmail(rs.getString("email"));
                                    teamMembers.add(member);
                                }
                            }
                        } catch (Exception ignored) {}
                    }
                }
            }
        }
    } catch (Exception ignored) {}    // Load Employee Personal Payslips
    PayrollDAO payrollDao = new PayrollDAO();
    List<Payroll> myPayslips = payrollDao.getPayrollHistory(empCode, null, null);

    // Load Employee Overtime History
    List<OvertimeRequest> myOtRequests = new ArrayList<>();
    try (Connection conn = com.Util.DBConnection.getConnection();
         PreparedStatement psOt = conn.prepareStatement(
            "SELECT * FROM overtime_requests WHERE LOWER(TRIM(employee_id)) = LOWER(TRIM(?)) ORDER BY request_date DESC LIMIT 10"
         )) {
        psOt.setString(1, empCode);
        try (ResultSet rsOt = psOt.executeQuery()) {
            while (rsOt.next()) {
                OvertimeRequest otReq = new OvertimeRequest();
                otReq.setId(rsOt.getInt("id"));
                otReq.setEmployeeId(rsOt.getString("employee_id"));
                otReq.setRequestDate(rsOt.getDate("request_date"));
                otReq.setRequestedHours(rsOt.getDouble("requested_hours"));
                otReq.setReason(rsOt.getString("reason"));
                otReq.setStatus(rsOt.getString("status"));
                otReq.setApprovedBy(rsOt.getString("approved_by"));
                myOtRequests.add(otReq);
            }
        }
    } catch (Exception ignored) {}

    boolean checkedIn = (att != null && att.get("clockIn") != null && att.get("clockOut") == null);
    String status = (att != null && att.get("status") != null) ? (String) att.get("status") : "NOT_CHECKED_IN";
    boolean onBreak = "ON_BREAK".equalsIgnoreCase(status);
    String shiftStateText = checkedIn ? (onBreak ? "On Break" : "In-Shift") : ("CHECKED_OUT".equalsIgnoreCase(status) ? "Shift Completed" : "Shift Not Started");

    String toastMsg = (String) session.getAttribute("toastMsg");
    String toastWarn = (String) session.getAttribute("toastWarn");
    String toastErr = (String) session.getAttribute("toastErr");
    session.removeAttribute("toastMsg");
    session.removeAttribute("toastWarn");
    session.removeAttribute("toastErr");

    String empDept = (emp.getDepartment() != null && !emp.getDepartment().isBlank()) ? emp.getDepartment() : "IT";

    int activeTaskCount = 0;
    int completedTaskCount = 0;
    if (myTasks != null) {
        for (Task t : myTasks) {
            if ("COMPLETED".equalsIgnoreCase(t.getStatus())) {
                completedTaskCount++;
            } else {
                activeTaskCount++;
            }
        }
    }
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>Employee Workspace | <%= companyBrandName %></title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@500;600&display=swap" rel="stylesheet">
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
        }

        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: 'Plus Jakarta Sans', sans-serif; background: var(--surface-bg); color: var(--text-main); display: flex; height: 100vh; overflow: hidden; }

        /* SIDEBAR & RESPONSIVE DRAWER */
        .sidebar {
            width: 260px;
            background: var(--sidebar-bg);
            color: #fff;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
            padding: 22px 14px;
            flex-shrink: 0;
            overflow-y: auto;
            transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            z-index: 100;
        }
        .sidebar::-webkit-scrollbar { width: 4px; }
        .sidebar::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.2); border-radius: 4px; }

        .sidebar-overlay {
            display: none;
            position: fixed;
            inset: 0;
            background: rgba(15, 23, 42, 0.6);
            backdrop-filter: blur(4px);
            z-index: 99;
        }

        .logo-area { font-size: 16px; font-weight: 800; letter-spacing: -0.3px; padding-left: 8px; margin-bottom: 22px; display: flex; justify-content: space-between; align-items: center; }
        .close-sidebar-btn { display: none; background: transparent; border: none; color: #fff; font-size: 22px; cursor: pointer; }
        .nav-section-title { font-size: 10.5px; font-weight: 800; text-transform: uppercase; color: #475569; letter-spacing: 0.5px; padding: 10px 12px 4px; }
        .nav-list { display: flex; flex-direction: column; gap: 4px; list-style: none; margin-bottom: 12px; }
        .nav-item { display: flex; align-items: center; gap: 10px; padding: 10px 12px; border-radius: 8px; color: #94a3b8; font-size: 13px; font-weight: 700; cursor: pointer; transition: all 0.2s ease; user-select: none; text-decoration: none; }
        .nav-item:hover { color: #fff; background: rgba(255,255,255,0.06); }
        .nav-item.active { background: var(--brand-primary); color: #fff; box-shadow: 0 4px 12px rgba(37,99,235,0.3); }
        .nav-icon { font-size: 14px; }
        .badge-count { margin-left: auto; background: var(--brand-primary); color: white; padding: 2px 7px; border-radius: 12px; font-size: 10.5px; font-weight: 800; }
        .nav-item.active .badge-count { background: #ffffff; color: var(--brand-primary); }

        .user-badge { padding: 12px; background: rgba(255,255,255,0.05); border-radius: 10px; font-size: 12px; margin-top: 16px; }
        .user-name { font-weight: 700; color: #fff; }
        .user-role { color: #94a3b8; font-size: 11px; margin-top: 2px; }

        /* MAIN WORKSPACE */
        .main-wrapper { flex: 1; min-width: 0; display: flex; flex-direction: column; overflow-y: auto; overflow-x: hidden; }
        .topbar { background: #fff; border-bottom: 1px solid var(--border-subtle); padding: 14px 28px; display: flex; justify-content: space-between; align-items: center; flex-shrink: 0; flex-wrap: wrap; gap: 12px; }
        .mobile-hamburger-btn { display: none; background: #f1f5f9; border: 1px solid var(--border-subtle); padding: 8px 12px; border-radius: 8px; font-size: 18px; cursor: pointer; }

        .content-area { padding: 28px; display: flex; flex-direction: column; gap: 22px; max-width: 1260px; margin: 0 auto; width: 100%; }

        .card { background: var(--surface-card); border: 1px solid var(--border-subtle); border-radius: 16px; padding: 24px; box-shadow: 0 1px 3px rgba(0,0,0,0.02); }
        .grid-2 { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 20px; }
        .grid-3 { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 16px; }
        .ot-form-grid { background: #f8fafc; border: 1px solid var(--border-subtle); padding: 18px; border-radius: 12px; display: grid; grid-template-columns: 1fr 1fr 2fr auto; gap: 14px; align-items: flex-end; }

        .badge-pill { padding: 4px 12px; border-radius: 20px; font-size: 11px; font-weight: 700; display: inline-flex; align-items: center; gap: 4px; white-space: nowrap; }
        .badge-green { background: #ecfdf5; color: #059669; }
        .badge-amber { background: #fef3c7; color: #b45309; }
        .badge-red { background: #fef2f2; color: #dc2626; }
        .badge-gray { background: #f1f5f9; color: #475569; }
        .badge-blue { background: #eff6ff; color: #2563eb; }
        .badge-purple { background: #f5f3ff; color: #7c3aed; }

        .btn { padding: 10px 16px; border-radius: 8px; font-size: 12.5px; font-weight: 700; cursor: pointer; border: 1px solid transparent; text-decoration: none; display: inline-flex; align-items: center; justify-content: center; gap: 6px; transition: all 0.15s ease; font-family: inherit; }
        .btn-blue { background: #2563eb; color: #fff; }
        .btn-blue:hover { background: #1d4ed8; }
        .btn-amber { background: #f59e0b; color: #fff; }
        .btn-amber:hover { background: #d97706; }
        .btn-green { background: #10b981; color: #fff; }
        .btn-green:hover { background: #059669; }
        .btn-purple { background: #7c3aed; color: #fff; }
        .btn-purple:hover { background: #6d28d9; }
        .btn-dark { background: #0f172a; color: #fff; }
        .btn-dark:hover { background: #1e293b; }
        .btn-outline { background: #fff; border: 1px solid var(--border-subtle); color: var(--text-main); }
        .btn:disabled { background: #e2e8f0 !important; color: #94a3b8 !important; cursor: not-allowed; opacity: 0.65; border-color: transparent; }

        .form-input { width: 100%; height: 38px; border: 1px solid var(--border-subtle); border-radius: 8px; padding: 0 12px; font-size: 13px; outline: none; background: #fff; }
        .form-input:focus { border-color: var(--brand-primary); }

        .table-responsive { width: 100%; overflow-x: auto; -webkit-overflow-scrolling: touch; margin-top: 14px; border-radius: 10px; border: 1px solid var(--border-subtle); }
        table { width: 100%; border-collapse: collapse; font-size: 13px; min-width: 640px; }
        th { text-align: left; padding: 12px 14px; background: #f8fafc; color: var(--text-muted); font-weight: 700; font-size: 11px; text-transform: uppercase; border-bottom: 1px solid var(--border-subtle); letter-spacing: 0.3px; white-space: nowrap; }
        td { padding: 13px 14px; border-bottom: 1px solid var(--border-subtle); vertical-align: middle; }
        tr:last-child td { border-bottom: none; }

        .mono { font-family: 'JetBrains Mono', monospace; font-size: 13px; }
        .amount-green { color: #059669; font-weight: 700; }
        .action-link { display: inline-flex; align-items: center; justify-content: center; width: 32px; height: 32px; border-radius: 6px; color: var(--text-main); text-decoration: none; border: 1px solid var(--border-subtle); background: #fff; }
        .action-link:hover { background: #e2e8f0; }

        .alert { padding: 12px 18px; border-radius: 8px; font-size: 13px; font-weight: 600; }
        .alert-success { background: #ecfdf5; color: #065f46; border: 1px solid #a7f3d0; }
        .alert-warning { background: #fffbeb; color: #92400e; border: 1px solid #fde68a; }
        .alert-error { background: #fef2f2; color: #991b1b; border: 1px solid #fecaca; }

        .tab-pane { display: none; }
        .tab-pane.active { display: flex; flex-direction: column; gap: 22px; animation: fadeIn 0.15s ease; }
        @keyframes fadeIn { from { opacity: 0; transform: translateY(4px); } to { opacity: 1; transform: translateY(0); } }

        .embedded-reports-frame { width: 100%; height: 740px; border: 1px solid var(--border-subtle); border-radius: 12px; background: #fff; }

        .modal-overlay { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(15, 23, 42, 0.7); z-index: 1000; justify-content: center; align-items: center; padding: 16px; }
        .modal-content { background: #fff; width: 100%; max-width: 860px; height: 90vh; border-radius: 14px; display: flex; flex-direction: column; overflow: hidden; box-shadow: 0 20px 25px -5px rgba(0,0,0,0.3); }
        .modal-header { padding: 14px 20px; background: #0f172a; color: #fff; display: flex; justify-content: space-between; align-items: center; }
        .modal-iframe { flex: 1; border: none; width: 100%; height: 100%; }

        @media (max-width: 960px) {
            .ot-form-grid { grid-template-columns: 1fr 1fr; }
        }

        @media (max-width: 820px) {
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
            .content-area { padding: 16px 14px; gap: 16px; }
            .card { padding: 18px 16px; border-radius: 12px; }

            .grid-2, .grid-3, .ot-form-grid {
                grid-template-columns: 1fr;
            }
            .date-hide-mobile { display: none; }
            .embedded-reports-frame { height: 600px; }
        }
    </style>
</head>
<body>

    <!-- Mobile Backdrop Overlay -->
    <div id="sidebarOverlay" class="sidebar-overlay" onclick="toggleMobileSidebar()"></div>

    <!-- Left Navigation Sidebar -->
    <aside class="sidebar" id="empSidebar">
        <div>
            <div class="logo-area">
                <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                    <% if (!companyLogoUrl.isEmpty()) { %>
                        <img src="<%= companyLogoUrl %>" alt="Logo" style="width: 30px; height: 30px; border-radius: 6px; object-fit: contain; background: #fff; padding: 2px; flex-shrink: 0;">
                    <% } %>
                    <span style="color: #fff; font-weight: 800; font-size: 14px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;" title="<%= companyBrandName %>">
                        <%= companyBrandName %>
                    </span>
                </div>
                <button type="button" class="close-sidebar-btn" onclick="toggleMobileSidebar()">&times;</button>
            </div>

            <div class="nav-section-title">My Workspace</div>
            <ul class="nav-list">
                <li class="nav-item active" onclick="switchEmpTab('tab-shift', this)">
                    <span class="nav-icon">&#9201;</span> Shift &amp; Attendance
                </li>
                <li class="nav-item" onclick="switchEmpTab('tab-tasks', this)">
                    <span class="nav-icon">&#128203;</span> My Tasks
                    <% if (activeTaskCount > 0) { %>
                        <span class="badge-count"><%= activeTaskCount %></span>
                    <% } %>
                </li>
                <li class="nav-item" onclick="switchEmpTab('tab-payslips', this)">
                    <span class="nav-icon">&#128181;</span> My Payslips
                </li>
            </ul>

            <div class="nav-section-title">Records &amp; Team</div>
            <ul class="nav-list">
                <li class="nav-item" onclick="switchEmpTab('tab-atthistory', this)">
                    <span class="nav-icon">&#128197;</span> Attendance History
                </li>
                <li class="nav-item" onclick="switchEmpTab('tab-team', this)">
                    <span class="nav-icon">&#128101;</span> My Team
                </li>
                <li class="nav-item" onclick="switchEmpTab('tab-reports', this)">
                    <span class="nav-icon">&#128202;</span> Reports Console
                </li>
            </ul>
        </div>

        <div class="user-badge">
            <div class="user-name"><%= emp.getName() %></div>
            <div class="user-role"><%= empCode %> &bull; <%= empDept %></div>
        </div>
    </aside>

    <!-- Main Workspace -->
    <div class="main-wrapper">
        <header class="topbar">
            <div style="display: flex; align-items: center; gap: 10px;">
                <button type="button" class="mobile-hamburger-btn" onclick="toggleMobileSidebar()">☰</button>
                <h2 id="headerTitle" style="font-size: 18px; font-weight: 800;">Shift &amp; Attendance</h2>
            </div>
            <div style="display: flex; align-items: center; gap: 12px; font-size: 13px;">
                <span class="badge-pill <%= checkedIn ? "badge-green" : "badge-gray" %>" style="font-size: 11.5px; padding: 5px 11px;">
                    &bull; <%= shiftStateText %>
                </span>
                <span class="date-hide-mobile" style="color: var(--text-muted);"><%= LocalDate.now().format(java.time.format.DateTimeFormatter.ofPattern("EEEE, d MMM yyyy")) %></span>
                <a href="<%= request.getContextPath() %>/logout" style="color: #ef4444; font-weight: 700; text-decoration: none; padding: 6px 10px; border-radius: 6px; background: #fef2f2;">Sign Out</a>
            </div>
        </header>

        <div class="content-area">
            <% if (toastMsg != null) { %><div class="alert alert-success"><%= toastMsg %></div><% } %>
            <% if (toastWarn != null) { %><div class="alert alert-warning"><%= toastWarn %></div><% } %>
            <% if (toastErr != null) { %><div class="alert alert-error"><%= toastErr %></div><% } %>

            <!-- TAB 1: SHIFT & LEAVE & OVERTIME -->
            <div id="tab-shift" class="tab-pane active">
                <div class="grid-2">
                    <!-- Shift Clock In/Out -->
                    <div class="card">
                        <h3 style="font-size: 15px; font-weight: 800; margin-bottom: 4px;">Attendance &amp; Break Controller</h3>
                        <p style="font-size: 12px; color: var(--text-muted); margin-bottom: 20px;">
                            Standard timing: <strong>09:45 AM</strong> to <strong>06:15 PM</strong> &bull; Auto-checkout shifts when OT is approved.
                        </p>

                        <form action="<%= request.getContextPath() %>/attendance/action" method="post" style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px;">
                            <input type="hidden" name="redirect" value="employee">
                            <button type="submit" name="action" value="CHECK_IN" class="btn btn-blue" <%= checkedIn ? "disabled" : "" %>>Check In</button>
                            <button type="submit" name="action" value="CHECK_OUT" class="btn btn-blue" <%= !checkedIn ? "disabled" : "" %>>Check Out</button>
                            <button type="submit" name="action" value="START_BREAK" class="btn btn-amber" <%= (!checkedIn || onBreak) ? "disabled" : "" %>>Start Break</button>
                            <button type="submit" name="action" value="END_BREAK" class="btn btn-green" <%= !onBreak ? "disabled" : "" %>>End Break</button>
                        </form>
                    </div>

                    <!-- Leave Request -->
                    <div class="card">
                        <h3 style="font-size: 15px; font-weight: 800; margin-bottom: 4px;">Request Absence / Leave</h3>
                        <p style="font-size: 12px; color: var(--text-muted); margin-bottom: 14px;">
                            Tickets route directly to your manager. Approved leaves prevent Loss of Pay (LOP) deductions during payroll.
                        </p>

                        <form action="<%= request.getContextPath() %>/attendance/action" method="post" style="display: flex; flex-direction: column; gap: 12px;">
                            <input type="hidden" name="action" value="APPLY_LEAVE">
                            <input type="hidden" name="redirect" value="employee">
                            <div>
                                <label style="display: block; font-size: 11px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; margin-bottom: 4px;">Effective Date</label>
                                <input type="date" name="effectiveDate" class="form-input" required>
                            </div>
                            <div>
                                <label style="display: block; font-size: 11px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; margin-bottom: 4px;">Reason / Justification</label>
                                <input type="text" name="reason" class="form-input" placeholder="e.g. Sick Leave, Personal Leave" required>
                            </div>
                            <button type="submit" class="btn btn-dark" style="margin-top: 4px; width: 100%;">Submit Leave Application</button>
                        </form>
                    </div>
                </div>

                <!-- OVERTIME (OT) REQUEST & HISTORY CARD -->
                <div class="card">
                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; flex-wrap: wrap; gap: 12px;">
                        <div>
                            <h3 style="font-size: 15px; font-weight: 800; display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
                                Overtime (OT) Request Desk
                                <span class="badge-pill badge-purple">1.5x Pay Multiplier</span>
                            </h3>
                            <p style="font-size: 12px; color: var(--text-muted); margin-top: 2px;">
                                Approved OT automatically extends your auto-checkout past <strong>18:15:00</strong> and credits additional hours to monthly payroll.
                            </p>
                        </div>
                    </div>

                    <form action="<%= request.getContextPath() %>/overtime/apply" method="POST" class="ot-form-grid">
                        <div>
                            <label style="display: block; font-size: 11px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; margin-bottom: 4px;">OT Date</label>
                            <input type="date" name="requestDate" class="form-input" required value="<%= new java.sql.Date(System.currentTimeMillis()) %>">
                        </div>
                        <div>
                            <label style="display: block; font-size: 11px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; margin-bottom: 4px;">Hours</label>
                            <select name="requestedHours" class="form-input" id="otHoursSelect" required>
                                <option value="1.0">1.0 Hr (19:15 Checkout)</option>
                                <option value="1.5">1.5 Hrs (19:45 Checkout)</option>
                                <option value="2.0" selected>2.0 Hrs (20:15 Checkout)</option>
                                <option value="2.5">2.5 Hrs (20:45 Checkout)</option>
                                <option value="3.0">3.0 Hrs (21:15 Checkout)</option>
                                <option value="4.0">4.0 Hrs (22:15 Checkout)</option>
                            </select>
                        </div>
                        <div>
                            <label style="display: block; font-size: 11px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; margin-bottom: 4px;">Task Deliverable / Reason</label>
                            <input type="text" name="reason" class="form-input" placeholder="e.g. Critical production release, server migration..." required>
                        </div>
                        <div>
                            <button type="submit" class="btn btn-purple" style="height: 38px; width: 100%;">Apply for OT</button>
                        </div>
                    </form>

                    <div style="margin-top: 18px;">
                        <h4 style="font-size: 12.5px; font-weight: 800; color: var(--text-muted); text-transform: uppercase; margin-bottom: 8px;">My Recent OT Applications</h4>
                        <div class="table-responsive" style="margin-top: 0;">
                            <table style="margin-top: 0;">
                                <thead>
                                    <tr>
                                        <th>Date</th>
                                        <th>Requested Hours</th>
                                        <th>Adjusted Shift End</th>
                                        <th>Reason</th>
                                        <th>Status</th>
                                        <th>Approved By</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <% if (myOtRequests != null && !myOtRequests.isEmpty()) { 
                                        for (OvertimeRequest otReq : myOtRequests) {
                                            long addMins = Math.round(otReq.getRequestedHours() * 60);
                                            LocalTime newOutTime = LocalTime.of(18, 15).plusMinutes(addMins);
                                            
                                            String badgeCls = "badge-amber";
                                            if ("APPROVED".equalsIgnoreCase(otReq.getStatus())) badgeCls = "badge-green";
                                            else if ("REJECTED".equalsIgnoreCase(otReq.getStatus())) badgeCls = "badge-red";
                                    %>
                                        <tr>
                                            <td><strong><%= otReq.getRequestDate() %></strong></td>
                                            <td><span class="mono"><%= otReq.getRequestedHours() %> hrs</span></td>
                                            <td><span class="badge-pill badge-blue"><%= newOutTime.toString() %></span></td>
                                            <td><%= otReq.getReason() %></td>
                                            <td><span class="badge-pill <%= badgeCls %>">&bull; <%= otReq.getStatus() %></span></td>
                                            <td><%= (otReq.getApprovedBy() != null ? otReq.getApprovedBy() : "--") %></td>
                                        </tr>
                                    <%  } 
                                       } else { %>
                                        <tr>
                                            <td colspan="6" style="text-align: center; color: var(--text-muted); padding: 18px;">
                                                No overtime requests logged yet. Use the form above to apply.
                                            </td>
                                        </tr>
                                    <% } %>
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>

            <!-- TAB 2: MY TASKS -->
            <div id="tab-tasks" class="tab-pane">
                <div class="card">
                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; flex-wrap: wrap; gap: 12px;">
                        <div>
                            <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
                                <h3 style="font-size: 16px; font-weight: 800;">My Assigned Deliverables</h3>
                                <span class="badge-pill badge-blue"><%= activeTaskCount %> Pending</span>
                                <span class="badge-pill badge-green"><%= completedTaskCount %> Done</span>
                            </div>
                        </div>

                        <div style="display: flex; gap: 8px; flex-wrap: wrap; width: 100%; max-width: 340px;">
                            <input type="text" id="empTaskSearch" onkeyup="filterEmployeeTasks()" class="form-input" placeholder="Search task..." style="flex: 1; min-width: 130px;">
                            <select id="empStatusFilter" onchange="filterEmployeeTasks()" class="form-input" style="width: 140px;">
                                <option value="ALL">All Statuses</option>
                                <option value="ASSIGNED">ASSIGNED</option>
                                <option value="IN_PROGRESS">IN_PROGRESS</option>
                                <option value="SUBMITTED_FOR_REVIEW">SUBMITTED</option>
                                <option value="REVISION_NEEDED">REVISION</option>
                                <option value="COMPLETED">COMPLETED</option>
                            </select>
                        </div>
                    </div>

                    <div class="table-responsive" style="margin-top: 0;">
                        <table style="margin-top: 0; min-width: 780px;">
                            <thead>
                                <tr>
                                    <th style="width: 25%;">Task &amp; Briefing</th>
                                    <th style="width: 12%;">Assigned By</th>
                                    <th style="width: 10%;">Priority</th>
                                    <th style="width: 13%;">Due Date</th>
                                    <th style="width: 15%;">Status</th>
                                    <th style="width: 25%;">Submit Completion</th>
                                </tr>
                            </thead>
                            <tbody>
                                <% if (myTasks != null && !myTasks.isEmpty()) { 
                                    for (Task t : myTasks) { 
                                        boolean isDone = "COMPLETED".equalsIgnoreCase(t.getStatus());
                                        String sClass = isDone ? "badge-green" : ("IN_PROGRESS".equalsIgnoreCase(t.getStatus()) ? "badge-blue" : "badge-amber");
                                        String assignedBy = (t.getCreatedByName() != null && !t.getCreatedByName().isBlank()) ? t.getCreatedByName() : "Manager";
                                %>
                                    <tr class="task-row" data-status="<%= t.getStatus() != null ? t.getStatus().toUpperCase() : "" %>">
                                        <td>
                                            <strong><%= t.getTaskTitle() %></strong>
                                            <% if (t.getDescription() != null && !t.getDescription().isBlank()) { %>
                                                <div style="font-size: 11px; color: var(--text-muted); margin-top: 2px;"><%= t.getDescription() %></div>
                                            <% } %>
                                            <% if (t.getTaskFilePath() != null && !t.getTaskFilePath().isBlank()) { %>
                                                <a href="<%= request.getContextPath() %>/uploads/tasks/<%= t.getTaskFilePath() %>" target="_blank" style="color: var(--brand-primary); font-size: 11px; font-weight: 700; text-decoration: none; display: inline-block; margin-top: 4px;">
                                                    &#128206; Briefing Attachment
                                                </a>
                                            <% } %>
                                        </td>
                                        <td><%= assignedBy %></td>
                                        <td><span class="badge-pill badge-gray"><%= t.getPriority() %></span></td>
                                        <td><%= (t.getDueDate() != null ? t.getDueDate().toString() : "--") %></td>
                                        <td>
                                            <span class="badge-pill <%= sClass %>">&bull; <%= t.getStatus() %></span>
                                            <% if (t.getRating() != null && t.getRating() > 0) { %>
                                                <div style="color: #f59e0b; font-weight: 800; font-size: 11px; margin-top: 3px;">
                                                    <%= "★".repeat(t.getRating()) %> (<%= t.getRating() %>/5)
                                                </div>
                                            <% } %>
                                        </td>
                                        <td>
                                            <% if (!isDone) { %>
                                                <form action="<%= request.getContextPath() %>/employee/task/update" method="post" enctype="multipart/form-data" style="display: flex; flex-direction: column; gap: 5px;">
                                                    <input type="hidden" name="taskId" value="<%= t.getId() %>">
                                                    <input type="text" name="employeeSubmissionNote" class="form-input" style="height: 30px; font-size: 11px;" placeholder="Summary / Note..." required>
                                                    <input type="file" name="submissionFile" style="font-size: 11px;" required>
                                                    <button type="submit" class="btn btn-blue" style="padding: 5px 10px; font-size: 11px; align-self: flex-start;">Upload Proof</button>
                                                </form>
                                            <% } else { %>
                                                <span style="color: #059669; font-weight: 700; font-size: 12px;">&#10003; Approved</span>
                                            <% } %>
                                        </td>
                                    </tr>
                                <%  } 
                                   } else { %>
                                    <tr><td colspan="6" style="text-align: center; color: var(--text-muted); padding: 24px;">No tasks currently assigned to you.</td></tr>
                                <% } %>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>

            <!-- TAB 3: MY PAYSLIPS -->
            <div id="tab-payslips" class="tab-pane">
                <div class="card">
                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;">
                        <div>
                            <h3 style="font-size: 16px; font-weight: 800;">My Monthly Payslips</h3>
                            <p style="font-size: 12px; color: var(--text-muted);">View, inspect, and download official monthly compensation vouchers including OT earnings.</p>
                        </div>
                    </div>

                    <div class="table-responsive" style="margin-top: 0;">
                        <table style="margin-top: 0; min-width: 780px;">
                            <thead>
                                <tr>
                                    <th style="width: 45px;">SNO</th>
                                    <th>PAYROLL PERIOD</th>
                                    <th>DAYS</th>
                                    <th>LOP</th>
                                    <th>GROSS SALARY</th>
                                    <th>OT PAY (HRS)</th>
                                    <th>TOTAL DEDUCTIONS</th>
                                    <th>NET PAY</th>
                                    <th style="text-align: center; width: 90px;">ACTIONS</th>
                                </tr>
                            </thead>
                            <tbody>
                                <% if (myPayslips != null && !myPayslips.isEmpty()) { 
                                    int pCount = 1;
                                    for (Payroll p : myPayslips) {
                                        String monthTitle = Month.of(p.getPayrollMonth()).getDisplayName(TextStyle.FULL, Locale.ENGLISH);
                                        double otAmt = (p.getOtAmount() != null) ? p.getOtAmount().doubleValue() : 0.00;
                                        double otHrs = (p.getOtHours() != null) ? p.getOtHours().doubleValue() : 0.00;
                                %>
                                    <tr>
                                        <td><%= pCount++ %></td>
                                        <td><strong><%= monthTitle %> <%= p.getPayrollYear() %></strong></td>
                                        <td><%= p.getWorkingDays() %></td>
                                        <td style="<%= (p.getUnpaidLeaveDays() > 0) ? "color: #dc2626; font-weight: 700;" : "" %>">
                                            <%= p.getUnpaidLeaveDays() %>
                                        </td>
                                        <td class="mono">INR <%= String.format("%.2f", p.getGrossSalary() != null ? p.getGrossSalary() : java.math.BigDecimal.ZERO) %></td>
                                        <td>
                                            <% if (otHrs > 0) { %>
                                                <span class="mono amount-green">+INR <%= String.format("%.2f", otAmt) %></span>
                                                <div style="font-size: 10px; color: var(--text-muted);"><%= otHrs %> hrs @ 1.5x</div>
                                            <% } else { %>
                                                <span style="color: var(--text-muted);">--</span>
                                            <% } %>
                                        </td>
                                        <td class="mono">INR <%= String.format("%.2f", p.getTotalDeductions() != null ? p.getTotalDeductions() : java.math.BigDecimal.ZERO) %></td>
                                        <td class="mono amount-green">INR <%= String.format("%.2f", p.getNetSalary() != null ? p.getNetSalary() : java.math.BigDecimal.ZERO) %></td>
                                        <td style="text-align: center;">
                                            <a href="javascript:void(0)" onclick="openPayslipModal('<%= request.getContextPath() %>/salary-slip.jsp?id=<%= p.getId() %>')" class="action-link" title="Quick View">&#128065;</a>
                                            <a href="<%= request.getContextPath() %>/salary-slip.jsp?id=<%= p.getId() %>" class="action-link" title="Print/Download" target="_blank">&#128229;</a>
                                        </td>
                                    </tr>
                                <%  } 
                                   } else { %>
                                    <tr>
                                        <td colspan="9" style="text-align: center; color: var(--text-muted); padding: 32px;">
                                            No payslips published yet. Monthly salary is generated automatically on the 1st of every month.
                                        </td>
                                    </tr>
                                <% } %>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>

            <!-- TAB 4: ATTENDANCE HISTORY -->
            <div id="tab-atthistory" class="tab-pane">
                <div class="card">
                    <h3 style="font-size: 16px; font-weight: 800; margin-bottom: 4px;">My Attendance History</h3>
                    <p style="font-size: 12px; color: var(--text-muted); margin-bottom: 14px;">Shift timestamps, break logs, and total calculated duration.</p>

                    <div class="table-responsive" style="margin-top: 0;">
                        <table style="margin-top: 0; min-width: 720px;">
                            <thead>
                                <tr>
                                    <th>Date</th>
                                    <th>Clock In</th>
                                    <th>Break 1</th>
                                    <th>Break 2</th>
                                    <th>Clock Out</th>
                                    <th>Approved OT</th>
                                    <th>Working Time</th>
                                    <th>Status</th>
                                </tr>
                            </thead>
                            <tbody>
                                <% if (attendanceHistory != null && !attendanceHistory.isEmpty()) { 
                                    for (Attendance a : attendanceHistory) { 
                                        int totalMins = a.getNetWorkingMinutes();
                                        String duration = "--";
                                        if (totalMins > 0) {
                                            duration = (totalMins / 60) + ":" + String.format("%02d", totalMins % 60);
                                        }
                                %>
                                    <tr>
                                        <td><strong><%= a.getAttendanceDate() %></strong></td>
                                        <td><%= (a.getCheckInTime() != null) ? a.getCheckInTime().toString() : "--" %></td>
                                        <td><%= (a.getBreak1StartTime() != null) ? a.getBreak1StartTime() + " - " + (a.getBreak1EndTime() != null ? a.getBreak1EndTime() : "..") : "--" %></td>
                                        <td><%= (a.getBreak2StartTime() != null) ? a.getBreak2StartTime() + " - " + (a.getBreak2EndTime() != null ? a.getBreak2EndTime() : "..") : "--" %></td>
                                        <td><%= (a.getCheckOutTime() != null) ? a.getCheckOutTime().toString() : "--" %></td>
                                        <td>
                                            <% if (a.getApprovedOtHours() > 0) { %>
                                                <span class="badge-pill badge-green">+<%= a.getApprovedOtHours() %> hrs</span>
                                            <% } else { %>
                                                <span style="color: var(--text-muted);">--</span>
                                            <% } %>
                                        </td>
                                        <td><strong><%= duration %></strong></td>
                                        <td><span class="badge-pill badge-green">&bull; <%= a.getStatus() %></span></td>
                                    </tr>
                                <%  } 
                                   } else { %>
                                    <tr><td colspan="8" style="text-align: center; color: var(--text-muted); padding: 24px;">No attendance logs found.</td></tr>
                                <% } %>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>

            <!-- TAB 5: MY TEAM -->
            <div id="tab-team" class="tab-pane">
                <div class="card">
                    <h3 style="font-size: 16px; font-weight: 800; margin-bottom: 4px;">Team Directory</h3>
                    <p style="font-size: 12px; color: var(--text-muted); margin-bottom: 14px;">
                        <%= (myTeam != null && myTeam.getTeamName() != null) ? "Team: " + myTeam.getTeamName() : "No assigned team." %>
                    </p>

                    <div class="table-responsive" style="margin-top: 0;">
                        <table style="margin-top: 0;">
                            <thead>
                                <tr>
                                    <th>Emp ID</th>
                                    <th>Name</th>
                                    <th>Role</th>
                                    <th>Email</th>
                                </tr>
                            </thead>
                            <tbody>
                                <% if (teamMembers != null && !teamMembers.isEmpty()) { 
                                    for (Employee m : teamMembers) { %>
                                        <tr>
                                            <td><strong><%= m.getEmployeeId() %></strong></td>
                                            <td><%= m.getName() %> <%= (m.getEmployeeId() != null && m.getEmployeeId().equalsIgnoreCase(empCode)) ? "(You)" : "" %></td>
                                            <td><%= m.getRole() %></td>
                                            <td><%= (m.getEmail() != null) ? m.getEmail() : "--" %></td>
                                        </tr>
                                <%  } 
                                   } else { %>
                                    <tr><td colspan="4" style="text-align: center; color: var(--text-muted); padding: 20px;">No team members found.</td></tr>
                                <% } %>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>

            <!-- TAB 6: IN-PAGE REPORTS CONSOLE (EMBEDDED ON SAME PAGE) -->
            <div id="tab-reports" class="tab-pane">
                <div class="card">
                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px; flex-wrap: wrap; gap: 10px;">
                        <div>
                            <h3 style="font-size: 16px; font-weight: 800;">Reports &amp; Analytics Console</h3>
                            <p style="font-size: 12px; color: var(--text-muted);">View your attendance, task completion, and performance metrics directly inside your workspace.</p>
                        </div>
                        <a href="<%= request.getContextPath() %>/reports-dashboard.jsp" target="_blank" style="font-size: 12px; font-weight: 700; color: var(--brand-primary); text-decoration: none;">Open in Full Window &nearr;</a>
                    </div>
                    <iframe id="reportsFrame" data-src="<%= request.getContextPath() %>/reports-dashboard.jsp" src="" class="embedded-reports-frame"></iframe>
                </div>
            </div>

        </div>
    </div>

    <!-- Modal Popup for Instant Payslip View -->
    <div id="payslipModal" class="modal-overlay" onclick="closePayslipModal(event)">
        <div class="modal-content" onclick="event.stopPropagation()">
            <div class="modal-header">
                <h3 style="font-size: 14px; font-weight: 700;">&#128181; Payslip Document View</h3>
                <button type="button" onclick="closePayslipModal()" style="background: transparent; border: none; color: #fff; font-size: 20px; cursor: pointer;">&times;</button>
            </div>
            <iframe id="modalFrame" class="modal-iframe" src=""></iframe>
        </div>
    </div>

    <script>
    function toggleMobileSidebar() {
        var sidebar = document.getElementById('empSidebar');
        var overlay = document.getElementById('sidebarOverlay');
        sidebar.classList.toggle('mobile-open');
        overlay.classList.toggle('active');
    }

    function switchEmpTab(tabId, el) {
        document.querySelectorAll('.tab-pane').forEach(function(pane) {
            pane.classList.remove('active');
        });
        document.querySelectorAll('.nav-item').forEach(function(item) {
            item.classList.remove('active');
        });

        var targetPane = document.getElementById(tabId);
        if (targetPane) targetPane.classList.add('active');
        el.classList.add('active');

        if (tabId === 'tab-reports') {
            var repFrame = document.getElementById('reportsFrame');
            if (repFrame && !repFrame.getAttribute('src')) {
                repFrame.setAttribute('src', repFrame.getAttribute('data-src'));
            }
        }

        var titleText = el.innerText.replace(/[^\w\s&]/gi, '').trim();
        document.getElementById('headerTitle').innerText = titleText;

        if (window.innerWidth <= 820) {
            var sidebar = document.getElementById('empSidebar');
            var overlay = document.getElementById('sidebarOverlay');
            if (sidebar.classList.contains('mobile-open')) {
                sidebar.classList.remove('mobile-open');
                overlay.classList.remove('active');
            }
        }
    }

    function openPayslipModal(url) {
        document.getElementById('modalFrame').src = url;
        document.getElementById('payslipModal').style.display = 'flex';
    }

    function closePayslipModal() {
        document.getElementById('payslipModal').style.display = 'none';
        document.getElementById('modalFrame').src = '';
    }

    function filterEmployeeTasks() {
        var query = document.getElementById('empTaskSearch').value.toLowerCase();
        var statusVal = document.getElementById('empStatusFilter').value.toUpperCase();
        var rows = document.querySelectorAll('.task-row');

        rows.forEach(function(row) {
            var text = row.innerText.toLowerCase();
            var rowStatus = row.getAttribute('data-status');
            var matchSearch = text.includes(query);
            var matchStatus = (statusVal === 'ALL') || (rowStatus === statusVal);

            row.style.display = (matchSearch && matchStatus) ? '' : 'none';
        });
    }
    </script>
</body>
</html>