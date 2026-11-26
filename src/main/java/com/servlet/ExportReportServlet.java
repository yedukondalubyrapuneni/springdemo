package com.servlet;

import com.dao.ReportDAO;
import com.model.Employee;
import com.model.ReportItem;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;
import java.io.PrintWriter;
import java.util.HashMap;
import java.util.List;

@WebServlet("/reports/export")
public class ExportReportServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;
    private final ReportDAO reportDAO = new ReportDAO();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        Employee user = (session != null) ? (Employee) session.getAttribute("loggedInEmployee") : null;
        if (user == null) {
            response.sendRedirect(request.getContextPath() + "/login.jsp");
            return;
        }

        String type = request.getParameter("type");
        if (type == null) type = "attendance";

        response.setContentType("text/csv; charset=UTF-8");
        String filename = "EMS_" + type.toUpperCase() + "_EXPORT_" + System.currentTimeMillis() + ".csv";
        response.setHeader("Content-Disposition", "attachment; filename=\"" + filename + "\"");

        try (PrintWriter writer = response.getWriter()) {
            switch (type.toLowerCase()) {
                case "attendance":
                    exportAttendance(request, user, writer);
                    break;
                case "leaves":
                    exportLeaves(request, user, writer);
                    break;
                case "tasks":
                    if (!"EMPLOYEE".equalsIgnoreCase(user.getRole())) {
                        exportTasks(request, user, writer);
                    } else {
                        writer.println("Access Denied: Standard employees cannot export organization task data.");
                    }
                    break;
                default:
                    writer.println("Error: Unknown report export type.");
            }
        }
    }

    private void exportAttendance(HttpServletRequest request, Employee user, PrintWriter writer) {
        String empId = "EMPLOYEE".equalsIgnoreCase(user.getRole()) 
                       ? user.getEmployeeId() 
                       : request.getParameter("employeeId");
        String fromDate = request.getParameter("fromDate");
        String toDate = request.getParameter("toDate");
        List<ReportItem> list = reportDAO.getAttendanceReport(user.getRole(), user.getEmployeeId(), empId, fromDate, toDate, new HashMap<>());

        writer.println("Record ID,Date,Employee ID,Employee Name,Shift Log,Status");
        for (ReportItem r : list) {
            writer.printf("\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\"%n",
                clean(r.getId()), r.getRecordDate(), clean(r.getEmployeeId()),
                clean(r.getEmployeeName()), clean(r.getDetails()), clean(r.getStatus()));
        }
    }

    private void exportLeaves(HttpServletRequest request, Employee user, PrintWriter writer) {
        String empId = "EMPLOYEE".equalsIgnoreCase(user.getRole()) 
                       ? user.getEmployeeId() 
                       : request.getParameter("employeeId");
        String status = request.getParameter("status");
        String fromDate = request.getParameter("fromDate");
        String toDate = request.getParameter("toDate");
        List<ReportItem> list = reportDAO.getLeaveReport(user.getRole(), user.getEmployeeId(), empId, status, fromDate, toDate, new HashMap<>());

        writer.println("Ticket ID,Employee ID,Employee Name,Leave Type,Start Date,End Date,Reason,Status");
        for (ReportItem r : list) {
            writer.printf("\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\"%n",
                clean(r.getId()), clean(r.getEmployeeId()), clean(r.getEmployeeName()),
                clean(r.getTitle()), r.getStartDate(), r.getEndDate(), clean(r.getDetails()), clean(r.getStatus()));
        }
    }

    private void exportTasks(HttpServletRequest request, Employee user, PrintWriter writer) {
        String empId = request.getParameter("employeeId");
        String status = request.getParameter("status");
        String fromDate = request.getParameter("fromDate");
        String toDate = request.getParameter("toDate");
        List<ReportItem> list = reportDAO.getTaskReport(user.getRole(), user.getEmployeeId(), empId, status, fromDate, toDate, new HashMap<>());

        writer.println("Task ID,Title,Assignee ID,Assignee Name,Start Date,Due Date,Priority,Status");
        for (ReportItem r : list) {
            writer.printf("\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\"%n",
                clean(r.getId()), clean(r.getTitle()), clean(r.getEmployeeId()),
                clean(r.getEmployeeName()), r.getStartDate(), r.getEndDate(), clean(r.getExtra()), clean(r.getStatus()));
        }
    }

    private String clean(String val) {
        return (val != null) ? val.replace("\"", "\"\"") : "";
    }
}