package com.servlet;

import com.Util.DBConnection;
import com.dao.AttendanceDao;
import com.model.Attendance;
import com.model.Employee;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

@WebServlet("/attendance/leave-requests")
public class LeaveApprovalServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;
    private final AttendanceDao attendanceDao = new AttendanceDao();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        Employee loggedIn = (session != null) ? (Employee) session.getAttribute("loggedInEmployee") : null;

        if (loggedIn == null) {
            response.sendRedirect(request.getContextPath() + "/login.jsp");
            return;
        }

        String role = (loggedIn.getRole() != null) ? loggedIn.getRole().trim().toUpperCase() : "";
        boolean isAuthorized = "HR".equals(role) || "ADMIN".equals(role) || "MANAGER".equals(role) || loggedIn.isHrDesignation();

        if (!isAuthorized) {
            response.sendRedirect(request.getContextPath() + "/employeeWorkspace.jsp");
            return;
        }

        List<Attendance> pendingLeaves = attendanceDao.findPendingLeaveRequests();
        request.setAttribute("pendingLeaves", pendingLeaves);
        request.getRequestDispatcher("/leave-requests.jsp").forward(request, response);
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        Employee loggedIn = (session != null) ? (Employee) session.getAttribute("loggedInEmployee") : null;

        if (loggedIn == null) {
            response.sendRedirect(request.getContextPath() + "/login.jsp");
            return;
        }

        String role = (loggedIn.getRole() != null) ? loggedIn.getRole().trim().toUpperCase() : "";
        boolean isAuthorized = "HR".equals(role) || "ADMIN".equals(role) || "MANAGER".equals(role) || loggedIn.isHrDesignation();

        if (!isAuthorized) {
            response.sendRedirect(request.getContextPath() + "/employeeWorkspace.jsp");
            return;
        }

        String attendanceId = request.getParameter("attendanceId");
        String decision = request.getParameter("decision");
        String remarks = request.getParameter("remarks");

        if (attendanceId != null && !attendanceId.isBlank() && decision != null && !decision.isBlank()) {
            String cleanDecision = decision.trim().toUpperCase();
            String finalStatus = cleanDecision.startsWith("APPROV") ? "LEAVE_APPROVED"
                               : (cleanDecision.startsWith("REJECT") ? "LEAVE_REJECTED" : cleanDecision);

            try (Connection conn = DBConnection.getConnection()) {
                Set<String> cols = new HashSet<>();
                try (PreparedStatement psMeta = conn.prepareStatement("SELECT * FROM attendance LIMIT 1");
                     ResultSet rsMeta = psMeta.executeQuery()) {
                    ResultSetMetaData md = rsMeta.getMetaData();
                    for (int i = 1; i <= md.getColumnCount(); i++) {
                        cols.add(md.getColumnLabel(i).toLowerCase());
                    }
                }

                String idCol = cols.contains("attendance_id") ? "attendance_id" : "id";
                StringBuilder sql = new StringBuilder("UPDATE attendance SET status = ?");
                List<Object> params = new ArrayList<>();
                params.add(finalStatus);

                if (remarks != null && !remarks.isBlank()) {
                    if (cols.contains("rejection_reason")) {
                        sql.append(", rejection_reason = ?");
                        params.add(remarks.trim());
                    } else if (cols.contains("remarks")) {
                        sql.append(", remarks = ?");
                        params.add(remarks.trim());
                    }
                }
                if (cols.contains("approved_by")) {
                    sql.append(", approved_by = ?");
                    params.add(loggedIn.getName());
                }

                sql.append(" WHERE CAST(").append(idCol).append(" AS CHAR) = ?");
                params.add(attendanceId.trim());

                try (PreparedStatement ps = conn.prepareStatement(sql.toString())) {
                    for (int i = 0; i < params.size(); i++) {
                        ps.setObject(i + 1, params.get(i));
                    }
                    ps.executeUpdate();
                }

                session.setAttribute("toastMsg", "Leave ticket #" + attendanceId + " updated to " + finalStatus + ".");
            } catch (Exception e) {
                session.setAttribute("toastErr", "Failed to update leave status: " + e.getMessage());
            }
        }

        String redirectTarget = request.getParameter("redirect");
        if ("manager".equalsIgnoreCase(redirectTarget)) {
            response.sendRedirect(request.getContextPath() + "/manager/dashboard");
        } else {
            response.sendRedirect(request.getContextPath() + "/attendance/leave-requests");
        }
    }
}