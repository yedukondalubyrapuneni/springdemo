package com.model;

import java.math.BigDecimal;

public class SalaryComponent {
    private int id;
    private int salaryStructureId;
    private String componentName;
    private String componentType; // EARNING or DEDUCTION
    private String calculationType; // FIXED or PERCENTAGE
    private BigDecimal amount;

    public SalaryComponent() {}

    public int getId() { return id; }
    public void setId(int id) { this.id = id; }

    public int getSalaryStructureId() { return salaryStructureId; }
    public void setSalaryStructureId(int salaryStructureId) { this.salaryStructureId = salaryStructureId; }

    public String getComponentName() { return componentName; }
    public void setComponentName(String componentName) { this.componentName = componentName; }

    public String getComponentType() { return componentType; }
    public void setComponentType(String componentType) { this.componentType = componentType; }

    public String getCalculationType() { return calculationType; }
    public void setCalculationType(String calculationType) { this.calculationType = calculationType; }

    public BigDecimal getAmount() { return amount; }
    public void setAmount(BigDecimal amount) { this.amount = amount; }
}