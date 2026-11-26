package com.servlet;

import com.model.Employee;
import com.service.EmployeeService;
import com.Util.DBConnection;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;
import java.sql.*;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

@WebServlet("/login")
public class LoginServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;
    private EmployeeService employeeService;

    @Override
    public void init() {
        employeeService = (EmployeeService) getServletContext().getAttribute("employeeService");
        if (employeeService == null) {
            employeeService = new EmployeeService();
        }
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        
        HttpSession session = request.getSession(false);
        if (session != null && session.getAttribute("loggedInEmployee") != null) {
            Employee loggedIn = (Employee) session.getAttribute("loggedInEmployee");
            redirectByRole(loggedIn, request, response);
            return;
        }

        request.getRequestDispatcher("/login.jsp").forward(request, response);
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {

        String identifier = request.getParameter("identifier");
        if (identifier == null || identifier.isBlank()) {
            identifier = request.getParameter("employeeId");
        }
        
        String password = request.getParameter("password");
        String finalIdentifier = (identifier != null) ? identifier.trim() : "Unknown";
        String clientIp = getClientIp(request);

        try {
            if (identifier == null || identifier.isBlank() || password == null || password.isBlank()) {
                throw new IllegalArgumentException("Employee ID / Email and password are required.");
            }

            // 1. Read Live Governance Settings from system_settings
            int maxFailedAttempts = 3;
            int lockoutMinutes = 5;
            try (Connection conn = DBConnection.getConnection();
                 PreparedStatement psCfg = conn.prepareStatement(
                     "SELECT setting_key, setting_value FROM system_settings WHERE setting_key IN ('MAX_FAILED_ATTEMPTS', 'LOCKOUT_DURATION_MINUTES')");
                 ResultSet rsCfg = psCfg.executeQuery()) {
                while (rsCfg.next()) {
                    String k = rsCfg.getString("setting_key");
                    String v = rsCfg.getString("setting_value");
                    if ("MAX_FAILED_ATTEMPTS".equalsIgnoreCase(k) && v != null) {
                        maxFailedAttempts = Integer.parseInt(v.replaceAll("[^0-9]", ""));
                    } else if ("LOCKOUT_DURATION_MINUTES".equalsIgnoreCase(k) && v != null) {
                        lockoutMinutes = Integer.parseInt(v.replaceAll("[^0-9]", ""));
                    }
                }
            } catch (Exception ignored) {}

            // 2. Check Pre-Login Account Lockout State (using employee_id / email)
            String matchedEmpCode = null;
            String matchedEmpEmail = null;
            int currentFailures = 0;
            Timestamp lockUntilTs = null;

            try (Connection conn = DBConnection.getConnection();
                 PreparedStatement psCheck = conn.prepareStatement(
                     "SELECT * FROM employee WHERE LOWER(TRIM(employee_id)) = LOWER(?) OR LOWER(TRIM(email)) = LOWER(?) LIMIT 1")) {
                psCheck.setString(1, finalIdentifier);
                psCheck.setString(2, finalIdentifier);
                try (ResultSet rs = psCheck.executeQuery()) {
                    if (rs.next()) {
                        matchedEmpCode = rs.getString("employee_id");
                        matchedEmpEmail = rs.getString("email");
                        try { currentFailures = rs.getInt("failed_attempts"); } catch (Exception ignored) {}
                        try { lockUntilTs = rs.getTimestamp("lock_until"); } catch (Exception ignored) {}

                        if (lockUntilTs != null) {
                            LocalDateTime lockExpiry = lockUntilTs.toLocalDateTime();
                            LocalDateTime now = LocalDateTime.now();
                            if (now.isBefore(lockExpiry)) {
                                long secsRemaining = Duration.between(now, lockExpiry).getSeconds();
                                long minsRemaining = Math.max(1, (secsRemaining + 59) / 60);

                                recordLoginHistory(null, matchedEmpEmail != null ? matchedEmpEmail : matchedEmpCode, "LOCKED_BLOCKED", request);
                                recordSystemError("SECURITY_LOCKOUT_BLOCKED", "AUTHENTICATION",
                                    "Blocked login attempt for locked account [" + matchedEmpCode + "]. Cooldown: " + minsRemaining + " min(s) remaining.",
                                    matchedEmpCode, clientIp, "HIGH");

                                request.setAttribute("error", "Account locked after " + maxFailedAttempts + " failed attempts. Try again in " + minsRemaining + " minute(s).");
                                request.getRequestDispatcher("/login.jsp").forward(request, response);
                                return;
                            } else {
                                // Cooldown expired -> auto-reset
                                currentFailures = 0;
                                updateLockoutState(matchedEmpCode, 0, null);
                            }
                        }
                    }
                }
            } catch (Exception ignored) {}

            // 3. Authenticate via EmployeeService
            Employee employee = null;
            String authFailReason = "Invalid Employee ID / Email or password.";
            try {
                employee = employeeService.login(finalIdentifier, password.trim());
            } catch (Exception serviceEx) {
                authFailReason = serviceEx.getMessage();
            }

            if (employee == null) {
                if (matchedEmpCode != null) {
                    int newFailures = currentFailures + 1;
                    if (newFailures >= maxFailedAttempts) {
                        Timestamp lockExpiry = Timestamp.valueOf(LocalDateTime.now().plusMinutes(lockoutMinutes));
                        updateLockoutState(matchedEmpCode, newFailures, lockExpiry);

                        recordLoginHistory(null, matchedEmpEmail != null ? matchedEmpEmail : matchedEmpCode, "ACCOUNT_LOCKED", request);
                        recordAuditTrail(null, "AUTHENTICATION", "ACCOUNT_LOCKED", matchedEmpCode,
                            "Account locked for " + lockoutMinutes + " min(s) after " + newFailures + " failed attempts",
                            "{\"employee_id\":\"" + matchedEmpCode + "\",\"lockout_minutes\":" + lockoutMinutes + "}");
                        recordSystemError("SECURITY_ACCOUNT_LOCKOUT", "AUTHENTICATION",
                            "Account [" + matchedEmpCode + "] locked for " + lockoutMinutes + " minute(s) after " + newFailures + "/" + maxFailedAttempts + " failed password attempts.",
                            matchedEmpCode, clientIp, "CRITICAL");

                        request.setAttribute("error", "Maximum failed attempts (" + maxFailedAttempts + ") reached. Account locked for " + lockoutMinutes + " minute(s).");
                    } else {
                        updateLockoutState(matchedEmpCode, newFailures, null);
                        int left = maxFailedAttempts - newFailures;

                        recordLoginHistory(null, matchedEmpEmail != null ? matchedEmpEmail : matchedEmpCode, "FAILED_LOGIN", request);
                        recordAuditTrail(null, "AUTHENTICATION", "FAILED_LOGIN", matchedEmpCode,
                            "Failed password attempt (" + newFailures + " of " + maxFailedAttempts + ")",
                            "{\"employee_id\":\"" + matchedEmpCode + "\",\"attempt\":" + newFailures + "}");
                        recordSystemError("AUTH_FAILED_PASSWORD", "AUTHENTICATION",
                            "Failed login for [" + matchedEmpCode + "] (Attempt " + newFailures + " of " + maxFailedAttempts + "): " + authFailReason,
                            matchedEmpCode, clientIp, "MEDIUM");

                        request.setAttribute("error", authFailReason + " (" + left + " attempt(s) remaining before lockout)");
                    }
                } else {
                    recordLoginHistory(null, finalIdentifier, "FAILED_LOGIN", request);
                    recordAuditTrail(null, "AUTHENTICATION", "FAILED_LOGIN", finalIdentifier,
                        "Failed authentication attempt for unknown identifier",
                        "{\"attempted_identifier\":\"" + finalIdentifier + "\"}");
                    recordSystemError("AUTH_UNKNOWN_USER", "AUTHENTICATION",
                        "Failed sign-in attempt for unrecognized ID/Email: " + finalIdentifier,
                        finalIdentifier, clientIp, "MEDIUM");

                    request.setAttribute("error", authFailReason);
                }

                request.getRequestDispatcher("/login.jsp").forward(request, response);
                return;
            }

            // 4. Successful Login -> Reset Failed Attempts & Bind Session
            updateLockoutState(employee.getEmployeeId(), 0, null);

            HttpSession session = request.getSession(true);
            session.setAttribute("loggedInEmployee", employee);
            session.setAttribute("role", employee.getRole());

            Integer safeUserId = (employee.getId() > 0) ? employee.getId() : null;
            recordLoginHistory(safeUserId, employee.getEmail(), "LOGIN", request);
            recordAuditTrail(safeUserId, "AUTHENTICATION", "LOGIN", employee.getEmployeeId(), 
                "User successfully logged into the system", 
                "{\"employee_id\":\"" + employee.getEmployeeId() + "\",\"role\":\"" + employee.getRole() + "\"}");

            redirectByRole(employee, request, response);

        } catch (Exception e) {
            System.err.println(">>> Authentication Failure for [" + finalIdentifier + "]: " + e.getMessage());
            recordLoginHistory(null, finalIdentifier, "FAILED_LOGIN", request);
            recordSystemError("AUTH_SYSTEM_ERROR", "AUTHENTICATION",
                "Authentication exception for [" + finalIdentifier + "]: " + e.getMessage(),
                finalIdentifier, clientIp, "HIGH");

            request.setAttribute("error", e.getMessage());
            request.getRequestDispatcher("/login.jsp").forward(request, response);
        }
    }

    private void redirectByRole(Employee employee, HttpServletRequest request, HttpServletResponse response) 
            throws IOException {
        if (employee == null) {
            response.sendRedirect(request.getContextPath() + "/login.jsp");
            return;
        }

        String rawRole = (employee.getRole() != null) ? employee.getRole().trim().toUpperCase() : "";
        String dept = (employee.getDepartment() != null) ? employee.getDepartment().trim().toUpperCase() : "";
        boolean isHr = "HR".equals(rawRole) || rawRole.contains("HR") || dept.contains("HUMAN") || employee.isHrDesignation();

        if ("ADMIN".equals(rawRole) || isHr) {
            response.sendRedirect(request.getContextPath() + "/dashboard.jsp");
        } else if ("MANAGER".equals(rawRole)) {
            response.sendRedirect(request.getContextPath() + "/managerDashboard.jsp");
        } else {
            response.sendRedirect(request.getContextPath() + "/employeeWorkspace.jsp");
        }
    }

    private void updateLockoutState(String empCode, int attempts, Timestamp lockUntil) {
        if (empCode == null || empCode.isBlank()) return;
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(
                 "UPDATE employee SET failed_attempts = ?, lock_until = ? WHERE LOWER(TRIM(employee_id)) = LOWER(TRIM(?))")) {
            ps.setInt(1, attempts);
            ps.setTimestamp(2, lockUntil);
            ps.setString(3, empCode);
            ps.executeUpdate();
        } catch (Exception ignored) {}
    }

    private String getClientIp(HttpServletRequest request) {
        String clientIp = request.getHeader("X-Forwarded-For");
        if (clientIp == null || clientIp.isBlank() || "unknown".equalsIgnoreCase(clientIp)) {
            return request.getRemoteAddr();
        }
        return clientIp.split(",")[0].trim();
    }

    private void recordLoginHistory(Integer userId, String email, String activityType, HttpServletRequest request) {
        String clientIp = getClientIp(request);
        String userAgent = request.getHeader("User-Agent");
        if (userAgent == null || userAgent.isBlank()) userAgent = "Unknown Client";

        String sql = "INSERT INTO login_history (user_id, email, activity_type, ip_address, user_agent, created_at) " +
                     "VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)";

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            if (userId != null && userId > 0) ps.setInt(1, userId);
            else ps.setNull(1, java.sql.Types.INTEGER);
            ps.setString(2, (email != null && !email.isBlank()) ? email : "unknown");
            ps.setString(3, activityType);
            ps.setString(4, clientIp);
            ps.setString(5, userAgent);
            ps.executeUpdate();
        } catch (Exception e) {
            System.err.println("Failed to insert into login_history: " + e.getMessage());
        }
    }

    private void recordAuditTrail(Integer userId, String module, String action, String recordId, String desc, String payload) {
        String sql = "INSERT INTO audit_logs (user_id, module_name, action_type, record_id, description, new_values, created_at) " +
                     "VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)";

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            if (userId != null && userId > 0) ps.setInt(1, userId);
            else ps.setNull(1, java.sql.Types.INTEGER);
            ps.setString(2, module);
            ps.setString(3, action);
            ps.setString(4, recordId);
            ps.setString(5, desc);
            ps.setString(6, payload);
            ps.executeUpdate();
        } catch (Exception e) {
            System.err.println("Failed to insert into audit_logs: " + e.getMessage());
        }
    }

    // Schema-adaptive insert into system_errors so it appears in the Errors dashboard regardless of column names
    private void recordSystemError(String errorType, String moduleName, String message, String userId, String ip, String severity) {
        try (Connection conn = DBConnection.getConnection()) {
            Set<String> cols = new HashSet<>();
            try (PreparedStatement psMeta = conn.prepareStatement("SELECT * FROM system_errors LIMIT 1");
                 ResultSet rsMeta = psMeta.executeQuery()) {
                ResultSetMetaData md = rsMeta.getMetaData();
                for (int i = 1; i <= md.getColumnCount(); i++) {
                    cols.add(md.getColumnLabel(i).toLowerCase());
                }
            }

            List<String> colNames = new ArrayList<>();
            List<Object> values = new ArrayList<>();

            if (cols.contains("error_type")) { colNames.add("error_type"); values.add(errorType); }
            else if (cols.contains("exception_type")) { colNames.add("exception_type"); values.add(errorType); }

            if (cols.contains("module_name")) { colNames.add("module_name"); values.add(moduleName); }
            else if (cols.contains("source")) { colNames.add("source"); values.add(moduleName); }
            else if (cols.contains("page_url")) { colNames.add("page_url"); values.add("/login"); }

            if (cols.contains("error_message")) { colNames.add("error_message"); values.add(message); }
            else if (cols.contains("message")) { colNames.add("message"); values.add(message); }

            if (cols.contains("user_identifier")) { colNames.add("user_identifier"); values.add(userId); }
            else if (cols.contains("employee_id")) { colNames.add("employee_id"); values.add(userId); }

            if (cols.contains("ip_address")) { colNames.add("ip_address"); values.add(ip); }
            if (cols.contains("severity")) { colNames.add("severity"); values.add(severity); }
            if (cols.contains("status")) { colNames.add("status"); values.add("OPEN"); }

            if (!colNames.isEmpty()) {
                StringBuilder sql = new StringBuilder("INSERT INTO system_errors (");
                sql.append(String.join(", ", colNames)).append(") VALUES (");
                for (int i = 0; i < values.size(); i++) {
                    sql.append(i > 0 ? ", ?" : "?");
                }
                sql.append(")");

                try (PreparedStatement ps = conn.prepareStatement(sql.toString())) {
                    for (int i = 0; i < values.size(); i++) {
                        ps.setObject(i + 1, values.get(i));
                    }
                    ps.executeUpdate();
                }
            }
        } catch (Exception e) {
            System.err.println("Failed to insert into system_errors: " + e.getMessage());
        }
    }
}