package com.Util;


import com.model.Payroll;
import com.model.SalaryComponent;
import com.model.SalaryStructure;

import java.math.BigDecimal;
import java.math.RoundingMode;

public class PayrollCalculator {

    public static Payroll compute(SalaryStructure structure, int month, int year, int totalDays, int presentDays, int unpaidLeaveDays) {
        Payroll p = new Payroll();
        p.setEmployeeId(structure.getEmployeeId());
        p.setPayrollMonth(month);
        p.setPayrollYear(year);
        p.setWorkingDays(totalDays);
        p.setPresentDays(presentDays);
        p.setUnpaidLeaveDays(unpaidLeaveDays);

        BigDecimal base = structure.getBasicSalary();
        
        // Attendance pro-rata deduction if unpaid leaves exist
        BigDecimal effectiveBasic = base;
        if (totalDays > 0 && unpaidLeaveDays > 0) {
            BigDecimal perDay = base.divide(BigDecimal.valueOf(totalDays), 4, RoundingMode.HALF_UP);
            BigDecimal lossOfPay = perDay.multiply(BigDecimal.valueOf(unpaidLeaveDays)).setScale(2, RoundingMode.HALF_UP);
            effectiveBasic = base.subtract(lossOfPay).max(BigDecimal.ZERO);
        }
        p.setBasicSalary(effectiveBasic);

        BigDecimal totalEarnings = effectiveBasic;
        BigDecimal totalDeductions = BigDecimal.ZERO;

        for (SalaryComponent c : structure.getComponents()) {
            BigDecimal val;
            if ("PERCENTAGE".equalsIgnoreCase(c.getCalculationType())) {
                val = base.multiply(c.getAmount())
                          .divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);
            } else {
                val = c.getAmount();
            }

            if ("EARNING".equalsIgnoreCase(c.getComponentType())) {
                totalEarnings = totalEarnings.add(val);
            } else if ("DEDUCTION".equalsIgnoreCase(c.getComponentType())) {
                totalDeductions = totalDeductions.add(val);
            }
        }

        p.setGrossSalary(totalEarnings.setScale(2, RoundingMode.HALF_UP));
        p.setTotalDeductions(totalDeductions.setScale(2, RoundingMode.HALF_UP));
        p.setNetSalary(totalEarnings.subtract(totalDeductions).max(BigDecimal.ZERO).setScale(2, RoundingMode.HALF_UP));
        p.setStatus("DRAFT");

        return p;
    }
}