package com.model;



import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

public class SalaryStructure {
    private int id;
    private String employeeId;
    private BigDecimal basicSalary;
    private LocalDate effectiveFrom;
    private LocalDate effectiveTo;
    private List<SalaryComponent> components = new ArrayList<>();

    public SalaryStructure() {}

    public int getId() { return id; }
    public void setId(int id) { this.id = id; }

    public String getEmployeeId() { return employeeId; }
    public void setEmployeeId(String employeeId) { this.employeeId = employeeId; }

    public BigDecimal getBasicSalary() { return basicSalary; }
    public void setBasicSalary(BigDecimal basicSalary) { this.basicSalary = basicSalary; }

    public LocalDate getEffectiveFrom() { return effectiveFrom; }
    public void setEffectiveFrom(LocalDate effectiveFrom) { this.effectiveFrom = effectiveFrom; }

    public LocalDate getEffectiveTo() { return effectiveTo; }
    public void setEffectiveTo(LocalDate effectiveTo) { this.effectiveTo = effectiveTo; }

    public List<SalaryComponent> getComponents() { return components; }
    public void setComponents(List<SalaryComponent> components) { this.components = components; }
}