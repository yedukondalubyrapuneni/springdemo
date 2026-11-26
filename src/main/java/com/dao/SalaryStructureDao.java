package com.dao;

import com.Util.DBConnection;
import com.model.SalaryComponent;
import com.model.SalaryStructure;

import java.math.BigDecimal;
import java.sql.*;
import java.util.ArrayList;
import java.util.List;

public class SalaryStructureDao {

	public int saveSalaryStructure(SalaryStructure struct) {
	    if (struct == null || struct.getEmployeeId() == null) return -1;

	    String empId = struct.getEmployeeId().trim();

	    // 1. Check if an active structure already exists for this employee
	    String checkSql = "SELECT id FROM salary_structures " +
	                      "WHERE LOWER(TRIM(employee_id)) = LOWER(TRIM(?)) " +
	                      "AND (effective_to IS NULL OR effective_to >= CURRENT_DATE) LIMIT 1";

	    int existingStructureId = -1;
	    try (Connection conn = DBConnection.getConnection();
	         PreparedStatement ps = conn.prepareStatement(checkSql)) {
	        ps.setString(1, empId);
	        try (ResultSet rs = ps.executeQuery()) {
	            if (rs.next()) {
	                existingStructureId = rs.getInt("id");
	            }
	        }
	    } catch (SQLException e) {
	        System.err.println("Error checking existing structure: " + e.getMessage());
	    }

	    try (Connection conn = DBConnection.getConnection()) {
	        conn.setAutoCommit(false);

	        int structureId;

	        if (existingStructureId > 0) {
	            // A. UPDATE existing structure
	            String updateSql = "UPDATE salary_structures SET basic_salary = ?, effective_from = ? WHERE id = ?";
	            try (PreparedStatement ps = conn.prepareStatement(updateSql)) {
	                ps.setBigDecimal(1, struct.getBasicSalary());
	                ps.setDate(2, java.sql.Date.valueOf(struct.getEffectiveFrom()));
	                ps.setInt(3, existingStructureId);
	                ps.executeUpdate();
	            }
	            structureId = existingStructureId;

	            // Delete old components to replace with updated toggles
	            String delComponentsSql = "DELETE FROM salary_components WHERE salary_structure_id = ?";
	            try (PreparedStatement ps = conn.prepareStatement(delComponentsSql)) {
	                ps.setInt(1, structureId);
	                ps.executeUpdate();
	            }
	        } else {
	            // B. INSERT new structure
	            String insertSql = "INSERT INTO salary_structures (employee_id, basic_salary, effective_from) VALUES (?, ?, ?)";
	            try (PreparedStatement ps = conn.prepareStatement(insertSql, PreparedStatement.RETURN_GENERATED_KEYS)) {
	                ps.setString(1, empId);
	                ps.setBigDecimal(2, struct.getBasicSalary());
	                ps.setDate(3, java.sql.Date.valueOf(struct.getEffectiveFrom()));
	                ps.executeUpdate();
	                try (ResultSet rs = ps.getGeneratedKeys()) {
	                    if (rs.next()) structureId = rs.getInt(1);
	                    else throw new SQLException("Failed to get generated structure ID");
	                }
	            }
	        }

	        // C. Insert the new/updated components (DA, HRA, PF, etc.)
	        if (struct.getComponents() != null && !struct.getComponents().isEmpty()) {
	            String insertCompSql = "INSERT INTO salary_components (salary_structure_id, component_name, component_type, calculation_type, amount) " +
	                                  "VALUES (?, ?, ?, ?, ?)";
	            try (PreparedStatement ps = conn.prepareStatement(insertCompSql)) {
	                for (SalaryComponent c : struct.getComponents()) {
	                    ps.setInt(1, structureId);
	                    ps.setString(2, c.getComponentName());
	                    ps.setString(3, c.getComponentType());
	                    ps.setString(4, c.getCalculationType() != null ? c.getCalculationType() : "FIXED");
	                    ps.setBigDecimal(5, c.getAmount());
	                    ps.addBatch();
	                }
	                ps.executeBatch();
	            }
	        }

	        conn.commit();
	        return structureId;

	    } catch (SQLException e) {
	        System.err.println("Error saving/updating salary structure: " + e.getMessage());
	        e.printStackTrace();
	        return -1;
	    }
	}
    // 2. Fetch Active Salary Structure with Components for an Employee
    public SalaryStructure findActiveStructureByEmployee(String employeeId) {
        String sql = "SELECT * FROM salary_structures " +
                     "WHERE TRIM(REPLACE(employee_id, ' ', '')) = TRIM(REPLACE(?, ' ', '')) " +
                     "  AND (effective_to IS NULL OR effective_to >= CURDATE()) " +
                     "ORDER BY effective_from DESC LIMIT 1";

        SalaryStructure struct = null;
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, employeeId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    struct = new SalaryStructure();
                    struct.setId(rs.getInt("id"));
                    struct.setEmployeeId(rs.getString("employee_id"));
                    struct.setBasicSalary(rs.getBigDecimal("basic_salary"));
                    Date ef = rs.getDate("effective_from");
                    if (ef != null) struct.setEffectiveFrom(ef.toLocalDate());
                    Date et = rs.getDate("effective_to");
                    if (et != null) struct.setEffectiveTo(et.toLocalDate());
                }
            }

            if (struct != null) {
                struct.setComponents(getComponentsForStructure(struct.getId(), conn));
            }
        } catch (SQLException e) {
            System.err.println("Error fetching active salary structure: " + e.getMessage());
            e.printStackTrace();
        }
        return struct;
    }

    // 3. Helper to populate components
    private List<SalaryComponent> getComponentsForStructure(int structureId, Connection conn) throws SQLException {
        List<SalaryComponent> list = new ArrayList<>();
        String sql = "SELECT * FROM salary_components WHERE salary_structure_id = ? ORDER BY component_type DESC, id ASC";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, structureId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    SalaryComponent c = new SalaryComponent();
                    c.setId(rs.getInt("id"));
                    c.setSalaryStructureId(rs.getInt("salary_structure_id"));
                    c.setComponentName(rs.getString("component_name"));
                    c.setComponentType(rs.getString("component_type"));
                    c.setCalculationType(rs.getString("calculation_type"));
                    c.setAmount(rs.getBigDecimal("amount"));
                    list.add(c);
                }
            }
        }
        return list;
    }

    // 4. Fetch All Active Employee Structures for Listing View
    public List<SalaryStructure> findAllActiveStructures() {
        List<SalaryStructure> list = new ArrayList<>();
        String sql = "SELECT s.* " +
                     "FROM salary_structures s " +
                     "INNER JOIN ( " +
                     "    SELECT employee_id, MAX(effective_from) as max_date " +
                     "    FROM salary_structures " +
                     "    GROUP BY employee_id " +
                     ") latest ON s.employee_id = latest.employee_id AND s.effective_from = latest.max_date " +
                     "WHERE s.effective_to IS NULL OR s.effective_to >= CURDATE() " +
                     "ORDER BY s.employee_id ASC";

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                SalaryStructure s = new SalaryStructure();
                s.setId(rs.getInt("id"));
                s.setEmployeeId(rs.getString("employee_id"));
                s.setBasicSalary(rs.getBigDecimal("basic_salary"));
                Date ef = rs.getDate("effective_from");
                if (ef != null) s.setEffectiveFrom(ef.toLocalDate());
                Date et = rs.getDate("effective_to");
                if (et != null) s.setEffectiveTo(et.toLocalDate());
                list.add(s);
            }
        } catch (SQLException e) {
            System.err.println("Error in findAllActiveStructures: " + e.getMessage());
        }
        return list;
    }
}