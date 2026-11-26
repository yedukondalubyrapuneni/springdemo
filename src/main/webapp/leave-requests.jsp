<%@ page contentType="text/html;charset=UTF-8" %>
<%@ page import="com.example.demo.model.Attendance" %>
<%@ page import="java.util.List" %>
<%
    // Safely retrieve the pending leaves passed by LeaveApprovalServlet
    List<Attendance> pendingLeaves = (List<Attendance>) request.getAttribute("pendingLeaves");
    String toastMsg = (String) session.getAttribute("toastMsg");
    if (toastMsg == null) toastMsg = request.getParameter("msg");
    session.removeAttribute("toastMsg");

    String toastErr = (String) session.getAttribute("toastErr");
    if (toastErr == null) toastErr = request.getParameter("error");
    session.removeAttribute("toastErr");
%>
<!DOCTYPE html>
<html>
<head>
    <title>HR - Manage Leave Requests</title>
    <style>
        body { font-family: sans-serif; background: #f4f6f8; padding: 30px; margin: 0; }
        .box { max-width: 950px; margin: 0 auto; background: #fff; padding: 25px; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
        .header-bar { display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px; }
        .back-link { text-decoration: none; color: #007bff; font-weight: bold; font-size: 14px; }
        .back-link:hover { text-decoration: underline; }
        table { width: 100%; border-collapse: collapse; margin-top: 15px; font-size: 14px; }
        th, td { padding: 12px; border-bottom: 1px solid #ddd; text-align: left; vertical-align: middle; }
        th { background: #f0f4f8; font-size: 12px; text-transform: uppercase; color: #495057; }
        .badge-type { background: #fff3cd; color: #856404; padding: 3px 8px; border-radius: 4px; font-size: 12px; font-weight: bold; }
        .btn-approve { background: #28a745; color: #fff; border: none; padding: 6px 14px; border-radius: 4px; cursor: pointer; font-weight: bold; }
        .btn-approve:hover { background: #218838; }
        .btn-reject { background: #dc3545; color: #fff; border: none; padding: 6px 14px; border-radius: 4px; cursor: pointer; font-weight: bold; margin-left: 6px; }
        .btn-reject:hover { background: #c82333; }
        .toast { background: #d4edda; color: #155724; padding: 10px 14px; border-radius: 4px; margin-bottom: 15px; font-weight: bold; }
        .toast-err { background: #f8d7da; color: #721c24; padding: 10px 14px; border-radius: 4px; margin-bottom: 15px; font-weight: bold; }
    </style>
</head>
<body>
<div class="box">
    <div class="header-bar">
        <h2 style="margin: 0;">Pending Leave Requests</h2>
        <a href="<%= request.getContextPath() %>/dashboard.jsp" class="back-link">&larr; Back to Dashboard</a>
    </div>

    <% if (toastMsg != null && !toastMsg.isBlank()) { %>
        <div class="toast">✔ <%= toastMsg %></div>
    <% } %>
    <% if (toastErr != null && !toastErr.isBlank()) { %>
        <div class="toast-err">⚠ <%= toastErr %></div>
    <% } %>

    <table>
        <thead>
            <tr>
                <th style="width: 25%;">Employee</th>
                <th style="width: 15%;">Leave Type</th>
                <th style="width: 20%;">Date</th>
                <th style="width: 25%;">Reason</th>
                <th style="width: 15%; text-align: center;">Action</th>
            </tr>
        </thead>
        <tbody>
            <% if (pendingLeaves != null && !pendingLeaves.isEmpty()) { 
                for (Attendance att : pendingLeaves) { 
                    String empName = (att.getEmployeeName() != null && !att.getEmployeeName().isBlank()) 
                                     ? att.getEmployeeName() 
                                     : att.getEmployeeId();
                    String leaveDate = att.getFormattedDate();
            %>
                    <tr>
                        <td>
                            <strong><%= empName %></strong>
                            <div style="font-size: 12px; color: #6c757d;"><%= att.getEmployeeId() %></div>
                        </td>
                        <td>
                            <span class="badge-type">LEAVE</span>
                        </td>
                        <td>
                            <strong><%= leaveDate %></strong>
                        </td>
                        <td><%= (att.getReason() != null ? att.getReason() : "--") %></td>
                        <td style="text-align: center;">
                            <div style="display: inline-flex; align-items: center; justify-content: center;">
                                <!-- Approve Form -->
                                <form action="<%= request.getContextPath() %>/attendance/leave-requests" method="post" style="display:inline; margin: 0;">
                                    <input type="hidden" name="attendanceId" value="<%= att.getAttendanceId() %>">
                                    <input type="hidden" name="decision" value="APPROVED">
                                    <button type="submit" class="btn-approve">Approve</button>
                                </form>

                                <!-- Reject Form with Mandatory Rejection Reason -->
                                <form id="rejectForm_<%= att.getAttendanceId() %>" action="<%= request.getContextPath() %>/attendance/leave-requests" method="post" style="display:inline; margin: 0;" onsubmit="return promptRejectionReason('<%= att.getAttendanceId() %>');">
                                    <input type="hidden" name="attendanceId" value="<%= att.getAttendanceId() %>">
                                    <input type="hidden" name="decision" value="REJECTED">
                                    <input type="hidden" name="rejectionReason" id="rejectReason_<%= att.getAttendanceId() %>">
                                    <button type="submit" class="btn-reject">Reject</button>
                                </form>
                            </div>
                        </td>
                    </tr>
            <%  } 
               } else { %>
                <tr>
                    <td colspan="5" style="text-align: center; color: #6c757d; padding: 25px;">
                        No pending leave requests found in the database.
                    </td>
                </tr>
            <% } %>
        </tbody>
    </table>
</div>

<script>
function promptRejectionReason(recordId) {
    const reason = prompt("Enter rejection reason for the employee:");
    if (reason === null) {
        // User clicked cancel
        return false;
    }
    if (reason.trim() === "") {
        alert("A rejection reason is mandatory when rejecting a leave request.");
        return false;
    }
    document.getElementById("rejectReason_" + recordId).value = reason.trim();
    return true;
}
</script>
</body>
</html>