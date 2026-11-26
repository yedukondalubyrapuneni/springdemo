package com.service;

import com.dao.AttendanceDao;
import com.model.Attendance;
import com.model.Employee;

import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.YearMonth;
import java.time.format.DateTimeFormatter;
import java.util.List;

public class AttendanceService {

    private final AttendanceDao attendanceDao;
    private final EmployeeService employeeService;

    private static final LocalTime EARLIEST_CHECK_IN = LocalTime.of(9, 45); // 09:45 AM restriction
    private static final DateTimeFormatter TIME_FMT = DateTimeFormatter.ofPattern("hh:mm a");

    public AttendanceService(EmployeeService employeeService) {
        this.employeeService = employeeService;
        this.attendanceDao = new AttendanceDao();
    }

    public AttendanceService(AttendanceDao attendanceDao, EmployeeService employeeService) {
        this.attendanceDao = attendanceDao;
        this.employeeService = employeeService;
    }

    // ============================================================
    // CHECK IN (Enforces 09:45 AM rule & Approved Leave check)
    // ============================================================
    public Attendance checkIn(String employeeId, LocalTime checkInTime) {
        if (checkInTime.isBefore(EARLIEST_CHECK_IN)) {
            throw new IllegalStateException(
                "Check-in is not allowed before 09:45 AM. Current time is " + checkInTime.format(TIME_FMT) + "."
            );
        }

        Employee emp = employeeService.getEmployeeById(employeeId);
        if (emp == null) {
            throw new IllegalArgumentException("Employee not found.");
        }

        if (!"ACTIVE".equalsIgnoreCase(emp.getStatus())) {
            throw new IllegalStateException("Employee account is not ACTIVE.");
        }

        LocalDate today = LocalDate.now();
        Attendance existing = attendanceDao.findRecord(employeeId, today);

        if (existing != null) {
            if ("LEAVE".equalsIgnoreCase(existing.getStatus()) && "APPROVED".equalsIgnoreCase(existing.getLeaveStatus())) {
                throw new IllegalStateException("Check-in blocked: You have an APPROVED leave for today.");
            }
            if ("LEAVE".equalsIgnoreCase(existing.getStatus()) && "PENDING_APPROVAL".equalsIgnoreCase(existing.getLeaveStatus())) {
                throw new IllegalStateException("You have a leave application pending HR approval for today.");
            }
            throw new IllegalStateException(
                "Employee has already been recorded for today (" + existing.getStatus() + ")."
            );
        }

        String attendanceId = String.format("ATT%03d", attendanceDao.getNextAttendanceSequence());

        Attendance attendance = new Attendance();
        attendance.setAttendanceId(attendanceId);
        attendance.setEmployeeId(emp.getEmployeeId());
        attendance.setAttendanceDate(today);
        attendance.setCheckInTime(checkInTime);
        attendance.setStatus("PENDING");

        attendanceDao.save(attendance);
        return attendance;
    }

    // ============================================================
    // UNIFIED SMART BREAK CONTROLS (Single UI action for 2 breaks)
    // ============================================================

    public Attendance startSmartBreak(String employeeId, LocalTime breakTime) {
        LocalDate today = LocalDate.now();
        Attendance record = attendanceDao.findRecord(employeeId, today);

        if (record == null || record.getCheckInTime() == null) {
            throw new IllegalStateException("You must check in first before starting a break.");
        }

        if (record.getCheckOutTime() != null) {
            throw new IllegalStateException("Cannot start break after checking out.");
        }

        // Slot 1: Break 1 has not started yet
        if (record.getBreak1StartTime() == null) {
            return startBreak1(employeeId, breakTime);
        }

        // Break 1 is actively running
        if (record.getBreak1EndTime() == null) {
            throw new IllegalStateException("Break 1 is already in progress. Please end it before starting another.");
        }

        // Slot 2: Break 1 is complete, Break 2 has not started yet
        if (record.getBreak2StartTime() == null) {
            return startBreak2(employeeId, breakTime);
        }

        // Break 2 is actively running
        if (record.getBreak2EndTime() == null) {
            throw new IllegalStateException("Break 2 is already in progress. Please end it before taking further action.");
        }

        // Both breaks have been completed
        throw new IllegalStateException("Daily break limit reached (Maximum 2 breaks allowed per shift).");
    }

    public Attendance endSmartBreak(String employeeId, LocalTime breakTime) {
        LocalDate today = LocalDate.now();
        Attendance record = attendanceDao.findRecord(employeeId, today);

        if (record == null) {
            throw new IllegalStateException("No active attendance record found for today.");
        }

        // Check if Break 1 is the currently active break
        if (record.getBreak1StartTime() != null && record.getBreak1EndTime() == null) {
            return endBreak1(employeeId, breakTime);
        }

        // Check if Break 2 is the currently active break
        if (record.getBreak2StartTime() != null && record.getBreak2EndTime() == null) {
            return endBreak2(employeeId, breakTime);
        }

        throw new IllegalStateException("No break is currently in progress to end.");
    }

    // ============================================================
    // BREAK 1 MANAGEMENT
    // ============================================================
    public Attendance startBreak1(String employeeId, LocalTime breakStart) {
        LocalDate today = LocalDate.now();
        Attendance record = attendanceDao.findRecord(employeeId, today);

        if (record == null || record.getCheckInTime() == null) {
            throw new IllegalStateException("You must check in first before starting a break.");
        }

        if (record.getCheckOutTime() != null) {
            throw new IllegalStateException("Cannot start break after checking out.");
        }

        if (record.getBreak1StartTime() != null && record.getBreak1EndTime() == null) {
            throw new IllegalStateException("Break 1 is already active.");
        }

        if (record.getBreak1EndTime() != null) {
            throw new IllegalStateException("Break 1 has already been completed today.");
        }

        attendanceDao.updateBreak1Start(record.getAttendanceId(), breakStart);
        record.setBreak1StartTime(breakStart);
        return record;
    }

    public Attendance endBreak1(String employeeId, LocalTime breakEnd) {
        LocalDate today = LocalDate.now();
        Attendance record = attendanceDao.findRecord(employeeId, today);

        if (record == null || record.getBreak1StartTime() == null) {
            throw new IllegalStateException("Break 1 has not been started yet.");
        }

        if (record.getBreak1EndTime() != null) {
            throw new IllegalStateException("Break 1 has already been ended.");
        }

        if (breakEnd.isBefore(record.getBreak1StartTime())) {
            throw new IllegalArgumentException("Break end time cannot be before break start time.");
        }

        attendanceDao.updateBreak1End(record.getAttendanceId(), breakEnd);
        record.setBreak1EndTime(breakEnd);
        return record;
    }

    // ============================================================
    // BREAK 2 MANAGEMENT
    // ============================================================
    public Attendance startBreak2(String employeeId, LocalTime breakStart) {
        LocalDate today = LocalDate.now();
        Attendance record = attendanceDao.findRecord(employeeId, today);

        if (record == null || record.getCheckInTime() == null) {
            throw new IllegalStateException("You must check in first before starting a break.");
        }

        if (record.getCheckOutTime() != null) {
            throw new IllegalStateException("Cannot start break after checking out.");
        }

        if (record.getBreak1EndTime() == null) {
            throw new IllegalStateException("You must start and complete Break 1 before starting Break 2.");
        }

        if (record.getBreak2StartTime() != null && record.getBreak2EndTime() == null) {
            throw new IllegalStateException("Break 2 is already active.");
        }

        if (record.getBreak2EndTime() != null) {
            throw new IllegalStateException("Break 2 has already been completed today.");
        }

        attendanceDao.updateBreak2Start(record.getAttendanceId(), breakStart);
        record.setBreak2StartTime(breakStart);
        return record;
    }

    public Attendance endBreak2(String employeeId, LocalTime breakEnd) {
        LocalDate today = LocalDate.now();
        Attendance record = attendanceDao.findRecord(employeeId, today);

        if (record == null || record.getBreak2StartTime() == null) {
            throw new IllegalStateException("Break 2 has not been started yet.");
        }

        if (record.getBreak2EndTime() != null) {
            throw new IllegalStateException("Break 2 has already been ended.");
        }

        if (breakEnd.isBefore(record.getBreak2StartTime())) {
            throw new IllegalArgumentException("Break end time cannot be before break start time.");
        }

        attendanceDao.updateBreak2End(record.getAttendanceId(), breakEnd);
        record.setBreak2EndTime(breakEnd);
        return record;
    }

    public Attendance startBreak(String employeeId, LocalTime breakStart) {
        return startSmartBreak(employeeId, breakStart);
    }

    public Attendance endBreak(String employeeId, LocalTime breakEnd) {
        return endSmartBreak(employeeId, breakEnd);
    }

    // ============================================================
    // CHECK OUT
    // ============================================================
    public Attendance checkOut(String employeeId, LocalTime checkOutTime) {
        Employee emp = employeeService.getEmployeeById(employeeId);
        if (emp == null) {
            throw new IllegalArgumentException("Employee not found.");
        }

        LocalDate today = LocalDate.now();
        Attendance record = attendanceDao.findRecord(employeeId, today);

        if (record == null || record.getCheckInTime() == null) {
            throw new IllegalStateException("Employee must check in first before checking out.");
        }

        if (record.getCheckOutTime() != null) {
            throw new IllegalStateException("Employee has already checked out today.");
        }

        if (checkOutTime.isBefore(record.getCheckInTime())) {
            throw new IllegalArgumentException("Check-out time must be after check-in time.");
        }

        if (record.getBreak1StartTime() != null && record.getBreak1EndTime() == null) {
            attendanceDao.updateBreak1End(record.getAttendanceId(), checkOutTime);
            record.setBreak1EndTime(checkOutTime);
        }
        if (record.getBreak2StartTime() != null && record.getBreak2EndTime() == null) {
            attendanceDao.updateBreak2End(record.getAttendanceId(), checkOutTime);
            record.setBreak2EndTime(checkOutTime);
        }

        long grossMinutes = Duration.between(record.getCheckInTime(), checkOutTime).toMinutes();
        long totalBreakMinutes = record.getBreak1DurationMinutes() + record.getBreak2DurationMinutes();
        long netMinutes = Math.max(0, grossMinutes - totalBreakMinutes);

        String finalStatus;
        if (netMinutes >= 480) {
            finalStatus = "PRESENT";
        } else if (netMinutes >= 240) {
            finalStatus = "HALF_DAY";
        } else {
            finalStatus = "ABSENT";
        }

        record.setCheckOutTime(checkOutTime);
        record.setStatus(finalStatus);
        record.setNetWorkingMinutes((int) netMinutes);

        attendanceDao.updateCheckOutWithMetrics(
                record.getAttendanceId(),
                checkOutTime,
                finalStatus,
                (int) netMinutes
        );

        return record;
    }

    public String calculateWorkingHours(LocalTime checkIn, LocalTime checkOut) {
        if (checkIn == null || checkOut == null) {
            return "0 Hours 0 Minutes";
        }
        Duration duration = Duration.between(checkIn, checkOut);
        long hours = duration.toHours();
        long minutes = duration.toMinutesPart();
        return hours + " Hours " + minutes + " Minutes";
    }

    public String formatNetWorkingHours(long netMinutes) {
        long hours = netMinutes / 60;
        long minutes = netMinutes % 60;
        return hours + " hrs " + minutes + " mins";
    }

    // ============================================================
    // ABSENT & LEAVE
    // ============================================================
    public Attendance markAbsent(String employeeId) {
        Employee emp = employeeService.getEmployeeById(employeeId);
        if (emp == null) {
            throw new IllegalArgumentException("Employee not found.");
        }

        LocalDate today = LocalDate.now();
        Attendance existing = attendanceDao.findRecord(employeeId, today);
        if (existing != null) {
            throw new IllegalStateException("Attendance record already exists for today.");
        }

        String attendanceId = String.format("ATT%03d", attendanceDao.getNextAttendanceSequence());
        Attendance record = new Attendance();
        record.setAttendanceId(attendanceId);
        record.setEmployeeId(emp.getEmployeeId());
        record.setAttendanceDate(today);
        record.setStatus("ABSENT");

        attendanceDao.save(record);
        return record;
    }

    public Attendance markLeave(String employeeId) {
        Employee emp = employeeService.getEmployeeById(employeeId);
        if (emp == null) {
            throw new IllegalArgumentException("Employee not found.");
        }

        LocalDate today = LocalDate.now();
        Attendance existing = attendanceDao.findRecord(employeeId, today);
        if (existing != null) {
            throw new IllegalStateException("Attendance record already exists for today.");
        }

        String attendanceId = String.format("ATT%03d", attendanceDao.getNextAttendanceSequence());
        Attendance record = new Attendance();
        record.setAttendanceId(attendanceId);
        record.setEmployeeId(emp.getEmployeeId());
        record.setAttendanceDate(today);
        record.setStatus("LEAVE");
        record.setLeaveStatus("PENDING_APPROVAL");

        attendanceDao.save(record);
        return record;
    }

    // ============================================================
    // RETRIEVAL & SUMMARY (With 6:15 PM auto check-out trigger)
    // ============================================================
    public List<Attendance> getDailyAttendance(LocalDate date) {
        attendanceDao.autoCheckOutUnclosedShifts();
        return attendanceDao.findByDate(date);
    }

    public List<Attendance> getEmployeeAttendance(String employeeId) {
        attendanceDao.autoCheckOutUnclosedShifts();
        return attendanceDao.findByEmployeeId(employeeId);
    }

    public MonthlySummary getMonthlySummary(String employeeId, YearMonth yearMonth, int workingDays) {
        attendanceDao.autoCheckOutUnclosedShifts();
        List<Attendance> records = attendanceDao.findByEmployeeAndMonth(employeeId, yearMonth);

        long present = records.stream()
                .filter(a -> "PRESENT".equalsIgnoreCase(a.getStatus()))
                .count();

        long halfDay = records.stream()
                .filter(a -> "HALF_DAY".equalsIgnoreCase(a.getStatus()))
                .count();

        long absent = records.stream()
                .filter(a -> "ABSENT".equalsIgnoreCase(a.getStatus()))
                .count();

        long leave = records.stream()
                .filter(a -> "LEAVE".equalsIgnoreCase(a.getStatus()))
                .count();

        double effectivePresent = present + (halfDay * 0.5);

        double percentage = workingDays > 0
                ? (effectivePresent / workingDays) * 100.0
                : 0.0;

        return new MonthlySummary(
                workingDays,
                (int) present,
                (int) halfDay,
                (int) absent,
                (int) leave,
                percentage
        );
    }

    public static class MonthlySummary {
        public final int workingDays;
        public final int presentDays;
        public final int halfDays;
        public final int absentDays;
        public final int leaveDays;
        public final double percentage;

        public MonthlySummary(int workingDays, int presentDays, int halfDays, int absentDays, int leaveDays, double percentage) {
            this.workingDays = workingDays;
            this.presentDays = presentDays;
            this.halfDays = halfDays;
            this.absentDays = absentDays;
            this.leaveDays = leaveDays;
            this.percentage = percentage;
        }

        public int getWorkingDays() { return workingDays; }
        public int getPresentDays() { return presentDays; }
        public int getHalfDays() { return halfDays; }
        public int getAbsentDays() { return absentDays; }
        public int getLeaveDays() { return leaveDays; }
        public double getPercentage() { return percentage; }
    }
}