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
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@WebServlet("/reports/tasks")
public class TaskReportServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;
    private final ReportDAO reportDao = new ReportDAO();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        HttpSession session = req.getSession(false);
        Employee user = (session != null) ? (Employee) session.getAttribute("loggedInEmployee") : null;
        if (user == null) {
            resp.sendRedirect(req.getContextPath() + "/login.jsp");
            return;
        }

        String role = (user.getRole() != null) ? user.getRole().trim().toUpperCase() : "EMPLOYEE";
        if ("EMPLOYEE".equals(role)) {
            resp.sendRedirect(req.getContextPath() + "/employeeWorkspace.jsp");
            return;
        }

        String empId = req.getParameter("employeeId");
        String status = req.getParameter("status");
        String fromDate = req.getParameter("fromDate");
        String toDate = req.getParameter("toDate");

        int page = 1;
        int limit = 10;
        try {
            if (req.getParameter("page") != null) {
                page = Math.max(1, Integer.parseInt(req.getParameter("page")));
            }
            if (req.getParameter("limit") != null) {
                limit = Math.max(5, Integer.parseInt(req.getParameter("limit")));
            }
        } catch (NumberFormatException ignored) {}

        int offset = (page - 1) * limit;

        int totalRecords = reportDao.countTasks(role, user.getEmployeeId(), empId, status, fromDate, toDate);
        int totalPages = (int) Math.ceil((double) totalRecords / (double) limit);

        Map<String, Integer> summary = new HashMap<>();
        reportDao.getTaskReport(role, user.getEmployeeId(), empId, status, fromDate, toDate, summary);
        List<ReportItem> records = reportDao.getTaskReportPaginated(role, user.getEmployeeId(), empId, status, fromDate, toDate, offset, limit);

        req.setAttribute("records", records);
        req.setAttribute("summary", summary);
        req.setAttribute("employeeId", empId);
        req.setAttribute("status", status);
        req.setAttribute("fromDate", fromDate);
        req.setAttribute("toDate", toDate);
        req.setAttribute("currentPage", page);
        req.setAttribute("pageSize", limit);
        req.setAttribute("totalPages", totalPages);
        req.setAttribute("totalRecords", totalRecords);
        req.setAttribute("userRole", role);

        req.getRequestDispatcher("/task-report.jsp").forward(req, resp);
    }
}