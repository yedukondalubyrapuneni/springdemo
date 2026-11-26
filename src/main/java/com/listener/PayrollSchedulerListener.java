package com.listener;

import com.Util.DBConnection;
import com.dao.SalaryStructureDao;
import com.model.SalaryStructure;

import jakarta.servlet.ServletContextEvent;
import jakarta.servlet.ServletContextListener;
import jakarta.servlet.annotation.WebListener;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

@WebListener
public class PayrollSchedulerListener implements ServletContextListener {

    private ScheduledExecutorService scheduler;
    private final SalaryStructureDao structureDao = new SalaryStructureDao();

    @Override
    public void contextInitialized(ServletContextEvent sce) {
        scheduler = Executors.newSingleThreadScheduledExecutor();

        // 1. Run immediately on server boot
        scheduler.execute(this::runAutomatedPayrollCycle);

        // 2. Schedule to check every 12 hours for ongoing 1st-of-month cycles
        scheduler.scheduleAtFixedRate(this::runAutomatedPayrollCycle, 12, 12, TimeUnit.HOURS);

        System.out.println(" Automated Payroll Scheduler initialized successfully.");
    }

    @Override
    public void contextDestroyed(ServletContextEvent sce) {
        if (scheduler != null && !scheduler.isShutdown()) {
            scheduler.shutdownNow();
            System.out.println("🛑 Automated Payroll Scheduler stopped.");
        }
    }

    public synchronized void runAutomatedPayrollCycle() {
        LocalDate today = LocalDate.now();
        // Targets completed previous month (e.g., in November, calculates October)
        LocalDate targetCycle = today.minusMonths(1);
        
        int targetMonth = targetCycle.getMonthValue(); // Corrected from today.getMonthValue()
        int targetYear = targetCycle.getYear();         // Corrected from today.getYear()
        int totalDaysInMonth = YearMonth.of(targetYear, targetMonth).lengthOfMonth();

        List<SalaryStructure> activeStructures = structureDao.findAllActiveStructures();
        if (activeStructures == null || activeStructures.isEmpty()) {
            return;
        }

        for (SalaryStructure struct : activeStructures) {
            String empId = struct.getEmployeeId();
            if (empId == null || empId.isBlank()) continue;

            // Compute present days and approved leaves
            int presentDays = countPresentDays(empId, targetMonth, targetYear);
            int approvedSickLeaves = countLeavesByType(empId, targetMonth, targetYear, "SICK");
            int approvedCasualLeaves = countLeavesByType(empId, targetMonth, targetYear, "CASUAL");

            int allowedPaidLeaves = Math.min(1, approvedSickLeaves) + Math.min(1, approvedCasualLeaves);

            // Default fallback: if no daily attendance punches are logged, grant full working days
            int effectivePresent = (presentDays > 0 || approvedSickLeaves > 0 || approvedCasualLeaves > 0)
                                   ? (presentDays + allowedPaidLeaves)
                                   : totalDaysInMonth;

            int unpaidLopDays = totalDaysInMonth - effectivePresent;
            if (unpaidLopDays < 0) unpaidLopDays = 0;

            BigDecimal basic = struct.getBasicSalary() != null ? struct.getBasicSalary() : BigDecimal.ZERO;
            if (basic.compareTo(BigDecimal.ZERO) <= 0) continue;

            // Speshway Compensation Breakdown
            BigDecimal da = basic.multiply(new BigDecimal("0.55")).setScale(2, RoundingMode.HALF_UP);
            BigDecimal hra = basic.multiply(new BigDecimal("0.50")).setScale(2, RoundingMode.HALF_UP);
            BigDecimal conveyance = new BigDecimal("1600.00");
            BigDecimal medical = new BigDecimal("1250.00");
            BigDecimal special = new BigDecimal("6687.00");

            BigDecimal gross = basic.add(da).add(hra).add(conveyance).add(medical).add(special);

            // Loss of Pay computation
            BigDecimal perDayRate = gross.divide(new BigDecimal(totalDaysInMonth), 4, RoundingMode.HALF_UP);
            BigDecimal lopDeduction = perDayRate.multiply(new BigDecimal(unpaidLopDays)).setScale(2, RoundingMode.HALF_UP);

            BigDecimal profTax = new BigDecimal("200.00");
            BigDecimal pf = basic.multiply(new BigDecimal("0.12")).setScale(2, RoundingMode.HALF_UP);
            BigDecimal totalDeductions = profTax.add(pf).add(lopDeduction);

            BigDecimal netSalary = gross.subtract(totalDeductions);
            if (netSalary.compareTo(BigDecimal.ZERO) < 0) netSalary = BigDecimal.ZERO;

            saveOrUpdatePayroll(empId, targetMonth, targetYear, totalDaysInMonth, 
                                unpaidLopDays, basic, gross, totalDeductions, netSalary);
        }
    }

    private int countPresentDays(String empId, int month, int year) {
        String sql = "SELECT COUNT(*) FROM attendance WHERE TRIM(employee_id) = ? " +
                     "AND MONTH(attendance_date) = ? AND YEAR(attendance_date) = ? " +
                     "AND UPPER(status) IN ('PRESENT', 'HALF_DAY')";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, empId.trim());
            ps.setInt(2, month);
            ps.setInt(3, year);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) return rs.getInt(1);
            }
        } catch (Exception ignored) {}
        return 0;
    }

    private int countLeavesByType(String empId, int month, int year, String leaveType) {
        String sql = "SELECT COUNT(*) FROM attendance WHERE TRIM(employee_id) = ? " +
                     "AND MONTH(attendance_date) = ? AND YEAR(attendance_date) = ? " +
                     "AND UPPER(status) = 'LEAVE' AND UPPER(reason) LIKE ? " +
                     "AND UPPER(decision) = 'APPROVED'";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, empId.trim());
            ps.setInt(2, month);
            ps.setInt(3, year);
            ps.setString(4, "%" + leaveType + "%");
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) return rs.getInt(1);
            }
        } catch (Exception ignored) {}
        return 0;
    }

    private void saveOrUpdatePayroll(String empId, int month, int year, int totalDays, 
                                     int lopDays, BigDecimal basic, BigDecimal gross, 
                                     BigDecimal deductions, BigDecimal net) {
        String sql = "INSERT INTO payroll (employee_id, payroll_month, payroll_year, working_days, " +
                     "unpaid_leave_days, basic_salary, gross_salary, total_deductions, net_salary, status) " +
                     "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'PROCESSED') " +
                     "ON DUPLICATE KEY UPDATE " +
                     "working_days = VALUES(working_days), " +
                     "unpaid_leave_days = VALUES(unpaid_leave_days), " +
                     "basic_salary = VALUES(basic_salary), " +
                     "gross_salary = VALUES(gross_salary), " +
                     "total_deductions = VALUES(total_deductions), " +
                     "net_salary = VALUES(net_salary)";

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, empId.trim());
            ps.setInt(2, month);
            ps.setInt(3, year);
            ps.setInt(4, totalDays);
            ps.setInt(5, lopDays);
            ps.setBigDecimal(6, basic);
            ps.setBigDecimal(7, gross);
            ps.setBigDecimal(8, deductions);
            ps.setBigDecimal(9, net);
            ps.executeUpdate();
        } catch (Exception e) {
            System.err.println("Error saving payroll for " + empId + ": " + e.getMessage());
        }
    }
}