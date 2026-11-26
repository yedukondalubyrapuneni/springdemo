package com.dao;

import com.Util.DBConnection;
import com.model.Employee;
import com.model.FinanceMISReport;
import com.model.Payroll;
import com.model.SalaryStructure;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.sql.Connection;
import java.sql.Date;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class PayrollDAO {

    /**
     * Checks if a bank account number is already assigned to a DIFFERENT employee.
     * Prevents duplicate account numbers across the company.
     */
    public boolean isAccountNumberAlreadyAssigned(String accountNumber, String currentEmpId) {
        if (accountNumber == null || accountNumber.isBlank()) {
            return false;
        }

        String cleanAcc = accountNumber.trim();
        String cleanEmpId = (currentEmpId != null) ? currentEmpId.trim() : "";

        String sql = "SELECT employee_id FROM employee " +
                     "WHERE TRIM(account_number) = ? " +
                     "AND LOWER(TRIM(employee_id)) != LOWER(TRIM(?)) LIMIT 1";

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {

            ps.setString(1, cleanAcc);
            ps.setString(2, cleanEmpId);

            try (ResultSet rs = ps.executeQuery()) {
                return rs.next(); // true if someone else already holds this account number
            }
        } catch (SQLException e) {
            System.err.println("Error validating unique account number in employee table: " + e.getMessage());
        }
        return false;
    }

    /**
     * Updates or commits the bank name and account number directly into the primary 'employee' table.
     */
    public boolean saveOrUpdateBankDetails(String empId, String bankName, String accountNumber) {
        if (empId == null || empId.isBlank()) return false;

        String cleanEmpId = empId.trim();
        String cleanBank = (bankName != null) ? bankName.trim() : "";
        String cleanAcc = (accountNumber != null) ? accountNumber.trim() : "";

        String sql = "UPDATE employee SET bank_name = ?, account_number = ? WHERE LOWER(TRIM(employee_id)) = LOWER(TRIM(?))";

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {

            ps.setString(1, cleanBank);
            ps.setString(2, cleanAcc);
            ps.setString(3, cleanEmpId);

            return ps.executeUpdate() > 0;
        } catch (SQLException e) {
            System.err.println("Error updating bank details for " + empId + ": " + e.getMessage());
            return false;
        }
    }

    /**
     * Retrieves payroll records filtered by optional employeeId, month, and year.
     */
    public List<Payroll> getPayrollHistory(String employeeId, Integer month, Integer year) {
        List<Payroll> list = new ArrayList<>();

        StringBuilder sql = new StringBuilder(
            "SELECT p.*, " +
            "e.name AS emp_name, " +
            "e.department AS emp_dept " +
            "FROM payroll p " +
            "LEFT JOIN employee e ON LOWER(TRIM(p.employee_id)) = LOWER(TRIM(e.employee_id)) " +
            "WHERE 1=1 "
        );

        if (employeeId != null && !employeeId.isBlank()) {
            sql.append(" AND LOWER(TRIM(p.employee_id)) = LOWER(TRIM(?)) ");
        }
        if (month != null && month > 0) {
            sql.append(" AND p.payroll_month = ? ");
        }
        if (year != null && year > 0) {
            sql.append(" AND p.payroll_year = ? ");
        }

        sql.append(" ORDER BY p.payroll_year DESC, p.payroll_month DESC, p.id DESC");

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {

            int paramIndex = 1;
            if (employeeId != null && !employeeId.isBlank()) {
                ps.setString(paramIndex++, employeeId.trim());
            }
            if (month != null && month > 0) {
                ps.setInt(paramIndex++, month);
            }
            if (year != null && year > 0) {
                ps.setInt(paramIndex++, year);
            }

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Payroll p = new Payroll();
                    p.setId(rs.getInt("id"));
                    p.setEmployeeId(rs.getString("employee_id"));
                    p.setEmployeeName(rs.getString("emp_name"));
                    p.setDepartment(rs.getString("emp_dept"));
                    p.setPayrollMonth(rs.getInt("payroll_month"));
                    p.setPayrollYear(rs.getInt("payroll_year"));
                    p.setWorkingDays(rs.getInt("working_days"));

                    try { p.setPresentDays(rs.getInt("present_days")); } catch (Exception ignored) {}
                    p.setUnpaidLeaveDays(rs.getInt("unpaid_leave_days"));
                    p.setBasicSalary(rs.getBigDecimal("basic_salary"));
                    p.setGrossSalary(rs.getBigDecimal("gross_salary"));
                    p.setTotalDeductions(rs.getBigDecimal("total_deductions"));
                    p.setNetSalary(rs.getBigDecimal("net_salary"));
                    p.setStatus(rs.getString("status"));

                    try { p.setProcessedBy(rs.getString("processed_by")); } catch (Exception ignored) {}

                    list.add(p);
                }
            }
        } catch (SQLException e) {
            System.err.println("Error in getPayrollHistory: " + e.getMessage());
            e.printStackTrace();
        }

        return list;
    }

    /**
     * Calculates total days, present days, and loss-of-pay (LOP) days.
     * Rule: 1 Paid Sick Leave + 1 Paid Casual Leave per month are allowed.
     */
    public int[] computeAttendanceAndLOP(String employeeId, int month, int year) {
        YearMonth ym = YearMonth.of(year, month);
        int totalDays = ym.lengthOfMonth();

        int presentCount = 0;
        int sickApproved = 0;
        int casualApproved = 0;
        int otherApproved = 0;

        // 1. Count Present days from attendance table
        String attSql = "SELECT COUNT(*) FROM attendance WHERE LOWER(TRIM(employee_id)) = LOWER(TRIM(?)) " +
                        "AND MONTH(attendance_date) = ? AND YEAR(attendance_date) = ? " +
                        "AND UPPER(status) IN ('PRESENT', 'HALF_DAY')";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(attSql)) {
            ps.setString(1, employeeId.trim());
            ps.setInt(2, month);
            ps.setInt(3, year);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    presentCount = rs.getInt(1);
                }
            }
        } catch (Exception e) {
            String fallbackSql = "SELECT COUNT(*) FROM attendance WHERE LOWER(TRIM(employee_id)) = LOWER(TRIM(?)) " +
                                 "AND MONTH(date) = ? AND YEAR(date) = ? AND UPPER(status) = 'PRESENT'";
            try (Connection conn = DBConnection.getConnection();
                 PreparedStatement ps = conn.prepareStatement(fallbackSql)) {
                ps.setString(1, employeeId.trim());
                ps.setInt(2, month);
                ps.setInt(3, year);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) presentCount = rs.getInt(1);
                }
            } catch (Exception ignored) {}
        }

        // 2. Count Approved Leaves by category
        String leaveSql = "SELECT UPPER(leave_type), COUNT(*) FROM leaves WHERE LOWER(TRIM(employee_id)) = LOWER(TRIM(?)) " +
                          "AND MONTH(leave_date) = ? AND YEAR(leave_date) = ? AND UPPER(status) = 'APPROVED' " +
                          "GROUP BY UPPER(leave_type)";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(leaveSql)) {
            ps.setString(1, employeeId.trim());
            ps.setInt(2, month);
            ps.setInt(3, year);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    String type = rs.getString(1);
                    int count = rs.getInt(2);
                    if (type != null && type.contains("SICK")) {
                        sickApproved += count;
                    } else if (type != null && type.contains("CASUAL")) {
                        casualApproved += count;
                    } else {
                        otherApproved += count;
                    }
                }
            }
        } catch (Exception ignored) {}

        // Rule: 1 Sick + 1 Casual paid leave allowance
        int paidSick = Math.min(sickApproved, 1);
        int paidCasual = Math.min(casualApproved, 1);
        int paidLeavesTotal = paidSick + paidCasual;

        int unpaidSick = Math.max(0, sickApproved - 1);
        int unpaidCasual = Math.max(0, casualApproved - 1);
        int lopDays = unpaidSick + unpaidCasual + otherApproved;

        // If no attendance records are logged, default to full working days (0 LOP)
        if (presentCount == 0 && sickApproved == 0 && casualApproved == 0) {
            lopDays = 0;
            presentCount = totalDays;
        } else {
            int accountedDays = presentCount + paidLeavesTotal + lopDays;
            if (accountedDays < totalDays) {
                lopDays += (totalDays - accountedDays);
            }
        }

        return new int[] { totalDays, presentCount, lopDays };
    }

    /**
     * Saves or updates a computed payroll cycle record.
     */
    public boolean savePayroll(Payroll payroll) {
        String sql = "INSERT INTO payroll (" +
                     "employee_id, payroll_month, payroll_year, working_days, present_days, unpaid_leave_days, " +
                     "basic_salary, gross_salary, total_deductions, net_salary, status, processed_by" +
                     ") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) " +
                     "ON DUPLICATE KEY UPDATE " +
                     "working_days = VALUES(working_days), " +
                     "present_days = VALUES(present_days), " +
                     "unpaid_leave_days = VALUES(unpaid_leave_days), " +
                     "basic_salary = VALUES(basic_salary), " +
                     "gross_salary = VALUES(gross_salary), " +
                     "total_deductions = VALUES(total_deductions), " +
                     "net_salary = VALUES(net_salary), " +
                     "status = VALUES(status), " +
                     "processed_by = VALUES(processed_by)";

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {

            ps.setString(1, payroll.getEmployeeId());
            ps.setInt(2, payroll.getPayrollMonth());
            ps.setInt(3, payroll.getPayrollYear());
            ps.setInt(4, payroll.getWorkingDays());
            ps.setInt(5, payroll.getPresentDays());
            ps.setInt(6, payroll.getUnpaidLeaveDays());
            ps.setBigDecimal(7, payroll.getBasicSalary());
            ps.setBigDecimal(8, payroll.getGrossSalary());
            ps.setBigDecimal(9, payroll.getTotalDeductions());
            ps.setBigDecimal(10, payroll.getNetSalary());
            ps.setString(11, payroll.getStatus());
            ps.setString(12, payroll.getProcessedBy());

            return ps.executeUpdate() > 0;
        } catch (SQLException e) {
            System.err.println("DB Error in savePayroll: " + e.getMessage());
            e.printStackTrace();
            return false;
        }
    }

    /**
     * Fetches employee demographic, email, banking, and active salary baseline.
     * Selects 'email' explicitly to support automated email dispatch.
     */
    public Map<String, String> getEmployeeProfileForSalary(String empId) {
        Map<String, String> data = new HashMap<>();
        if (empId == null || empId.isBlank()) return data;

        String cleanId = empId.trim();

        String sql = "SELECT employee_id, name, department, role, email, " +
                     "COALESCE(bank_name, '') AS bank_name, " +
                     "COALESCE(account_number, '') AS account_number " +
                     "FROM employee WHERE LOWER(TRIM(employee_id)) = LOWER(TRIM(?)) LIMIT 1";

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {

            ps.setString(1, cleanId);

            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    data.put("empId", rs.getString("employee_id"));
                    data.put("name", rs.getString("name"));
                    data.put("department", rs.getString("department") != null ? rs.getString("department") : "IT");

                    // Read and store email
                    String empEmail = rs.getString("email");
                    data.put("email", (empEmail != null && !empEmail.isBlank()) ? empEmail.trim() : "");

                    String role = rs.getString("role");
                    data.put("designation", (role != null && !role.isBlank()) ? role : "Staff");
                    data.put("joiningDate", "-");

                    String b = rs.getString("bank_name");
                    String a = rs.getString("account_number");

                    data.put("bankName", (b != null && !b.isBlank()) ? b.trim() : "-");
                    data.put("bankAccount", (a != null && !a.isBlank()) ? a.trim() : "-");
                }
            }
        } catch (SQLException e) {
            System.err.println("Error reading profile from employee table: " + e.getMessage());
        }

        // Attach existing active salary baseline if present
        SalaryStructure existingStruct = getActiveSalaryStructure(cleanId);
        if (existingStruct != null && existingStruct.getBasicSalary() != null) {
            data.put("basicSalary", existingStruct.getBasicSalary().toString());
        }

        return data;
    }

    /**
     * Reads all active employees directly from 'employee'.
     */
    public List<Employee> getAllActiveEmployees() {
        List<Employee> list = new ArrayList<>();
        String sql = "SELECT employee_id, name, department, role FROM employee ORDER BY employee_id ASC";

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {

            while (rs.next()) {
                String empId = rs.getString("employee_id");
                if (empId != null && !empId.isBlank()) {
                    Employee emp = new Employee();
                    emp.setEmployeeId(empId.trim());
                    emp.setName(rs.getString("name"));
                    emp.setDepartment(rs.getString("department"));

                    String role = rs.getString("role");
                    emp.setRole(role);
                    emp.setDesignation((role != null && !role.isBlank()) ? role : "Staff");

                    list.add(emp);
                }
            }
        } catch (SQLException e) {
            System.err.println("Error reading from employee table: " + e.getMessage());
        }
        return list;
    }

    /**
     * Retrieves the currently active salary structure for a specific employee.
     */
    public SalaryStructure getActiveSalaryStructure(String employeeId) {
        if (employeeId == null || employeeId.isBlank()) {
            return null;
        }

        String sql = "SELECT * FROM salary_structures " +
                     "WHERE LOWER(TRIM(employee_id)) = LOWER(TRIM(?)) " +
                     "AND (effective_to IS NULL OR effective_to >= CURRENT_DATE) " +
                     "ORDER BY effective_from DESC LIMIT 1";

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {

            ps.setString(1, employeeId.trim());

            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    SalaryStructure struct = new SalaryStructure();
                    struct.setId(rs.getInt("id"));
                    struct.setEmployeeId(rs.getString("employee_id"));
                    struct.setBasicSalary(rs.getBigDecimal("basic_salary"));

                    Date fromDate = rs.getDate("effective_from");
                    if (fromDate != null) {
                        struct.setEffectiveFrom(fromDate.toLocalDate());
                    }

                    Date toDate = rs.getDate("effective_to");
                    if (toDate != null) {
                        struct.setEffectiveTo(toDate.toLocalDate());
                    }

                    return struct;
                }
            }
        } catch (SQLException e) {
            System.err.println("DB Error in getActiveSalaryStructure: " + e.getMessage());
            e.printStackTrace();
        }

        return null;
    }

    /**
     * Retrieves a single payroll record by ID.
     */
    public Payroll getPayrollById(int payrollId) {
        String sql = "SELECT p.*, " +
                     "e.name AS emp_name, " +
                     "e.department AS emp_dept " +
                     "FROM payroll p " +
                     "LEFT JOIN employee e ON LOWER(TRIM(p.employee_id)) = LOWER(TRIM(e.employee_id)) " +
                     "WHERE p.id = ? LIMIT 1";

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {

            ps.setInt(1, payrollId);

            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    Payroll p = new Payroll();
                    p.setId(rs.getInt("id"));
                    p.setEmployeeId(rs.getString("employee_id"));
                    p.setEmployeeName(rs.getString("emp_name"));
                    p.setDepartment(rs.getString("emp_dept"));
                    p.setPayrollMonth(rs.getInt("payroll_month"));
                    p.setPayrollYear(rs.getInt("payroll_year"));
                    p.setWorkingDays(rs.getInt("working_days"));

                    try { p.setPresentDays(rs.getInt("present_days")); } catch (Exception ignored) {}
                    p.setUnpaidLeaveDays(rs.getInt("unpaid_leave_days"));
                    p.setBasicSalary(rs.getBigDecimal("basic_salary"));
                    p.setGrossSalary(rs.getBigDecimal("gross_salary"));
                    p.setTotalDeductions(rs.getBigDecimal("total_deductions"));
                    p.setNetSalary(rs.getBigDecimal("net_salary"));
                    p.setStatus(rs.getString("status"));

                    try { p.setProcessedBy(rs.getString("processed_by")); } catch (Exception ignored) {}
                    return p;
                }
            }
        } catch (SQLException e) {
            System.err.println("DB Error in getPayrollById: " + e.getMessage());
            e.printStackTrace();
        }

        return null;
    }
    /**
     * Generates a consolidated MIS Report and CTC analysis for Finance
     */
    /**
     * Generates a consolidated MIS Report and CTC analysis directly from verified payroll tables
     */
    public FinanceMISReport getFinanceMISReport(int month, int year) {
        FinanceMISReport mis = new FinanceMISReport();
        mis.setPayrollMonth(month);
        mis.setPayrollYear(year);

        // 1. Query payroll table directly (guaranteed to match existing records)
        String sqlPayroll = "SELECT " +
                            "  COUNT(id) AS total_processed, " +
                            "  SUM(CASE WHEN UPPER(TRIM(status)) = 'PAID' THEN 1 ELSE 0 END) AS total_paid, " +
                            "  SUM(CASE WHEN UPPER(TRIM(status)) != 'PAID' OR status IS NULL THEN 1 ELSE 0 END) AS total_pending, " +
                            "  COALESCE(SUM(gross_salary), 0) AS total_gross, " +
                            "  COALESCE(SUM(net_salary), 0) AS total_net, " +
                            "  COALESCE(SUM(total_deductions), 0) AS total_deductions, " +
                            "  COALESCE(SUM(basic_salary), 0) AS total_basic " +
                            "FROM payroll " +
                            "WHERE payroll_month = ? AND payroll_year = ?";

        // 2. Query verified disbursements from payroll_payments
        String sqlDisbursed = "SELECT COALESCE(SUM(amount_paid), 0) AS total_disbursed, COUNT(id) AS disburse_count " +
                              "FROM payroll_payments " +
                              "WHERE payroll_id IN (SELECT id FROM payroll WHERE payroll_month = ? AND payroll_year = ?)";

        try (Connection conn = DBConnection.getConnection()) {
            
            // Execute Payroll Summary
            try (PreparedStatement ps = conn.prepareStatement(sqlPayroll)) {
                ps.setInt(1, month);
                ps.setInt(2, year);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        int processed = rs.getInt("total_processed");
                        mis.setTotalEmployeesProcessed(processed);
                        mis.setPendingDisbursements(rs.getInt("total_pending"));

                        BigDecimal totalGross = rs.getBigDecimal("total_gross");
                        BigDecimal totalNet = rs.getBigDecimal("total_net");
                        BigDecimal totalDeductions = rs.getBigDecimal("total_deductions");
                        BigDecimal totalBasic = rs.getBigDecimal("total_basic");

                        mis.setTotalGrossPayout(totalGross);

                        // Calculate standard statutory pools
                        BigDecimal estimatedPf = totalBasic.multiply(new BigDecimal("0.12"));
                        BigDecimal estimatedPt = new BigDecimal(processed * 200); // Standard ₹200 PT per staff

                        mis.setTotalPfContribution(estimatedPf);
                        mis.setTotalPtDeduction(estimatedPt);

                        BigDecimal lop = totalDeductions.subtract(estimatedPf.add(estimatedPt));
                        mis.setTotalLopDeductions(lop.compareTo(BigDecimal.ZERO) > 0 ? lop : BigDecimal.ZERO);

                        // Estimated Corporate CTC = Gross Salary + 12% Employer PF Match
                        mis.setTotalEstimatedCtc(totalGross.add(estimatedPf));
                    }
                }
            }

            // Execute Settlement & Actual Disbursed Sums
            try (PreparedStatement ps = conn.prepareStatement(sqlDisbursed)) {
                ps.setInt(1, month);
                ps.setInt(2, year);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        BigDecimal actualDisbursed = rs.getBigDecimal("total_disbursed");
                        int count = rs.getInt("disburse_count");
                        
                        mis.setTotalNetDisbursed(actualDisbursed);
                        mis.setTotalDisbursedCount(count);
                    }
                }
            }

        } catch (SQLException e) {
            System.err.println("Error generating Finance MIS report: " + e.getMessage());
        }
        return mis;
    }
    public boolean computeAndCommitPayroll(String employeeId, int month, int year) {
        String attendanceQuery = 
            "SELECT " +
            "  COUNT(CASE WHEN UPPER(status) = 'PRESENT' THEN 1 END) AS present_days, " +
            "  COUNT(CASE WHEN UPPER(status) = 'LEAVE' AND is_paid_leave = 0 THEN 1 END) AS unpaid_leave_days, " +
            "  COALESCE(SUM(approved_ot_hours), 0.0) AS total_ot_hours " +
            "FROM attendance " +
            "WHERE LOWER(TRIM(REPLACE(employee_id, ' ', ''))) = LOWER(TRIM(REPLACE(?, ' ', ''))) " +
            "  AND MONTH(attendance_date) = ? " +
            "  AND YEAR(attendance_date) = ?";

        String salaryStructureQuery = 
            "SELECT basic_salary, gross_salary, total_deductions " +
            "FROM salary_structure " +
            "WHERE LOWER(TRIM(REPLACE(employee_id, ' ', ''))) = LOWER(TRIM(REPLACE(?, ' ', '')))";

        String upsertPayrollSql = 
            "INSERT INTO payroll (" +
            "  employee_id, payroll_month, payroll_year, working_days, present_days, " +
            "  unpaid_leave_days, basic_salary, gross_salary, total_deductions, " +
            "  ot_hours, ot_hourly_rate, ot_amount, net_salary, status" +
            ") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'PROCESSED') " +
            "ON DUPLICATE KEY UPDATE " +
            "  working_days = VALUES(working_days), " +
            "  present_days = VALUES(present_days), " +
            "  unpaid_leave_days = VALUES(unpaid_leave_days), " +
            "  basic_salary = VALUES(basic_salary), " +
            "  gross_salary = VALUES(gross_salary), " +
            "  total_deductions = VALUES(total_deductions), " +
            "  ot_hours = VALUES(ot_hours), " +
            "  ot_hourly_rate = VALUES(ot_hourly_rate), " +
            "  ot_amount = VALUES(ot_amount), " +
            "  net_salary = VALUES(net_salary), " +
            "  status = 'PROCESSED'";

        try (Connection conn = com.Util.DBConnection.getConnection()) {
            int presentDays = 30;
            int unpaidLeaves = 0;
            double otHours = 0.0;

            // 1. Fetch attendance & OT summary
            try (PreparedStatement psAtt = conn.prepareStatement(attendanceQuery)) {
                psAtt.setString(1, employeeId);
                psAtt.setInt(2, month);
                psAtt.setInt(3, year);
                try (ResultSet rsAtt = psAtt.executeQuery()) {
                    if (rsAtt.next()) {
                        int pDays = rsAtt.getInt("present_days");
                        if (pDays > 0) presentDays = pDays;
                        unpaidLeaves = rsAtt.getInt("unpaid_leave_days");
                        otHours = rsAtt.getDouble("total_ot_hours");
                    }
                }
            }

            // 2. Fetch baseline salary structure
            BigDecimal basic = BigDecimal.ZERO;
            BigDecimal gross = BigDecimal.ZERO;
            BigDecimal deductions = BigDecimal.ZERO;

            try (PreparedStatement psSal = conn.prepareStatement(salaryStructureQuery)) {
                psSal.setString(1, employeeId);
                try (ResultSet rsSal = psSal.executeQuery()) {
                    if (rsSal.next()) {
                        basic = rsSal.getBigDecimal("basic_salary");
                        gross = rsSal.getBigDecimal("gross_salary");
                        deductions = rsSal.getBigDecimal("total_deductions");
                    }
                }
            }

            if (gross.compareTo(BigDecimal.ZERO) <= 0) {
                System.err.println("Cannot process payroll: Salary structure missing for " + employeeId);
                return false;
            }

            // 3. Compute 1.5x OT formulas
            BigDecimal otHoursBd = BigDecimal.valueOf(otHours).setScale(2, RoundingMode.HALF_UP);
            BigDecimal otHourlyRate = gross.divide(new BigDecimal("240.0"), 4, RoundingMode.HALF_UP)
                                          .multiply(new BigDecimal("1.5"))
                                          .setScale(2, RoundingMode.HALF_UP);
            BigDecimal otAmount = otHoursBd.multiply(otHourlyRate).setScale(2, RoundingMode.HALF_UP);

            // Net Salary = (Gross + OT) - Deductions - LOP
            BigDecimal lopPerDay = gross.divide(new BigDecimal("30.0"), 2, RoundingMode.HALF_UP);
            BigDecimal totalLop = lopPerDay.multiply(BigDecimal.valueOf(unpaidLeaves));
            BigDecimal finalDeductions = deductions.add(totalLop);

            BigDecimal netSalary = gross.add(otAmount).subtract(finalDeductions).setScale(2, RoundingMode.HALF_UP);

            // 4. Upsert into Payroll Table
            try (PreparedStatement psUp = conn.prepareStatement(upsertPayrollSql)) {
                psUp.setString(1, employeeId);
                psUp.setInt(2, month);
                psUp.setInt(3, year);
                psUp.setInt(4, 30);
                psUp.setInt(5, presentDays);
                psUp.setInt(6, unpaidLeaves);
                psUp.setBigDecimal(7, basic);
                psUp.setBigDecimal(8, gross);
                psUp.setBigDecimal(9, finalDeductions);
                psUp.setBigDecimal(10, otHoursBd);
                psUp.setBigDecimal(11, otHourlyRate);
                psUp.setBigDecimal(12, otAmount);
                psUp.setBigDecimal(13, netSalary);

                return psUp.executeUpdate() > 0;
            }
        } catch (SQLException e) {
            System.err.println("Error computing payroll with OT: " + e.getMessage());
            e.printStackTrace();
            return false;
        }
    }
}