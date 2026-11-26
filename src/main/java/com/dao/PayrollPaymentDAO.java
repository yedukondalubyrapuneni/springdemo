package com.dao;

import com.Util.DBConnection;
import com.model.PayrollPayment;

import java.sql.Connection;
import java.sql.Date;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.List;

public class PayrollPaymentDAO {

    /**
     * Transactionally inserts a disbursement record into `payroll_payments`
     * and automatically updates the corresponding `payroll` row status to 'PAID'.
     */
    public boolean recordPayment(PayrollPayment payment) {
        String insertPaymentSql = "INSERT INTO payroll_payments (payroll_id, payment_date, payment_method, reference_number, amount_paid) " +
                                  "VALUES (?, ?, ?, ?, ?)";
        String updatePayrollSql = "UPDATE payroll SET status = 'PAID' WHERE id = ?";

        Connection conn = null;
        try {
            conn = DBConnection.getConnection();
            conn.setAutoCommit(false); // Begin transaction

            // 1. Insert payment transaction record
            try (PreparedStatement psInsert = conn.prepareStatement(insertPaymentSql, Statement.RETURN_GENERATED_KEYS)) {
                psInsert.setInt(1, payment.getPayrollId());
                psInsert.setDate(2, Date.valueOf(payment.getPaymentDate()));
                psInsert.setString(3, payment.getPaymentMethod());
                
                String ref = payment.getReferenceNumber();
                psInsert.setString(4, (ref != null && !ref.isBlank()) ? ref.trim() : null);
                
                psInsert.setBigDecimal(5, payment.getAmountPaid());
                psInsert.executeUpdate();

                try (ResultSet rs = psInsert.getGeneratedKeys()) {
                    if (rs.next()) {
                        payment.setId(rs.getInt(1));
                    }
                }
            }

            // 2. Transition payroll entry status to 'PAID'
            try (PreparedStatement psUpdate = conn.prepareStatement(updatePayrollSql)) {
                psUpdate.setInt(1, payment.getPayrollId());
                psUpdate.executeUpdate();
            }

            conn.commit(); // Commit transaction
            return true;

        } catch (SQLException e) {
            if (conn != null) {
                try {
                    conn.rollback(); // Rollback if any step fails
                } catch (SQLException rollbackEx) {
                    rollbackEx.printStackTrace();
                }
            }
            System.err.println("DB Error in recordPayment: " + e.getMessage());
            e.printStackTrace();
            return false;
        } finally {
            if (conn != null) {
                try {
                    conn.setAutoCommit(true);
                    conn.close();
                } catch (SQLException closeEx) {
                    closeEx.printStackTrace();
                }
            }
        }
    }

    /**
     * Retrieves all recorded disbursements for a given payroll record ID.
     */
    public List<PayrollPayment> getPaymentsByPayrollId(int payrollId) {
        List<PayrollPayment> list = new ArrayList<>();
        String sql = "SELECT * FROM payroll_payments WHERE payroll_id = ? ORDER BY payment_date DESC, id DESC";

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {

            ps.setInt(1, payrollId);

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    PayrollPayment p = new PayrollPayment();
                    p.setId(rs.getInt("id"));
                    p.setPayrollId(rs.getInt("payroll_id"));

                    Date pd = rs.getDate("payment_date");
                    if (pd != null) {
                        p.setPaymentDate(pd.toLocalDate());
                    }

                    p.setPaymentMethod(rs.getString("payment_method"));
                    p.setReferenceNumber(rs.getString("reference_number"));
                    p.setAmountPaid(rs.getBigDecimal("amount_paid"));

                    Timestamp ts = rs.getTimestamp("created_at");
                    if (ts != null) {
                        p.setCreatedAt(ts.toLocalDateTime());
                    }

                    list.add(p);
                }
            }
        } catch (SQLException e) {
            System.err.println("DB Error in getPaymentsByPayrollId: " + e.getMessage());
            e.printStackTrace();
        }

        return list;
    }

    /**
     * Checks if a payroll record already has at least one recorded payment.
     */
    public boolean isPayrollPaid(int payrollId) {
        String sql = "SELECT 1 FROM payroll_payments WHERE payroll_id = ? LIMIT 1";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {

            ps.setInt(1, payrollId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next();
            }
        } catch (SQLException e) {
            System.err.println("DB Error in isPayrollPaid: " + e.getMessage());
            e.printStackTrace();
        }
        return false;
    }
    public List<PayrollPayment> getAllDisbursements() {
        List<PayrollPayment> list = new ArrayList<>();
        String sql = "SELECT pp.id, pp.payroll_id, pp.payment_date, pp.payment_method, pp.reference_number, pp.amount_paid, pp.created_at, " +
                     "p.employee_id, e.name AS emp_name, p.payroll_month, p.payroll_year " +
                     "FROM payroll_payments pp " +
                     "INNER JOIN payroll p ON pp.payroll_id = p.id " +
                     "LEFT JOIN employee e ON LOWER(TRIM(p.employee_id)) = LOWER(TRIM(e.employee_id)) " +
                     "ORDER BY pp.payment_date DESC, pp.id DESC LIMIT 50";

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {

            while (rs.next()) {
                PayrollPayment p = new PayrollPayment();
                p.setId(rs.getInt("id"));
                p.setPayrollId(rs.getInt("payroll_id"));

                Date d = rs.getDate("payment_date");
                if (d != null) {
                    p.setPaymentDate(d.toLocalDate());
                }

                p.setPaymentMethod(rs.getString("payment_method"));
                p.setReferenceNumber(rs.getString("reference_number"));
                p.setAmountPaid(rs.getBigDecimal("amount_paid"));

                Timestamp ts = rs.getTimestamp("created_at");
                if (ts != null) {
                    p.setCreatedAt(ts.toLocalDateTime());
                }

                // Joined employee & period details
                p.setEmployeeId(rs.getString("employee_id"));
                p.setEmployeeName(rs.getString("emp_name"));

                int m = rs.getInt("payroll_month");
                int y = rs.getInt("payroll_year");
                p.setPayrollPeriod(java.time.Month.of(m).getDisplayName(java.time.format.TextStyle.SHORT, java.util.Locale.ENGLISH) + " " + y);

                list.add(p);
            }
        } catch (SQLException e) {
            System.err.println("Error reading audit logs: " + e.getMessage());
        }
        return list;
    }
}