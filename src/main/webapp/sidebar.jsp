<%@ page contentType="text/html;charset=UTF-8" %>
<%@ page import="com.example.demo.model.Employee" %>
<%
    Employee loggedUser = (Employee) session.getAttribute("loggedInEmployee");
    String userName = (loggedUser != null && loggedUser.getName() != null) ? loggedUser.getName() : "Administrator";
    String userRole = (loggedUser != null && loggedUser.getRole() != null) ? loggedUser.getRole() : "ADMIN";
    String empId = (loggedUser != null && loggedUser.getEmployeeId() != null) ? loggedUser.getEmployeeId() : "";
%>
<aside class="sidebar">
    <div>
        <div class="logo-area">
            <span style="color: #60a5fa;">EMS</span> Enterprise
        </div>
        <ul class="nav-list">
            <li class="nav-item active" onclick="switchAdminTab('tab-overview', this)">
                <span class="nav-icon">📊</span> Overview
            </li>
            <li class="nav-item" onclick="switchAdminTab('tab-taskmonitor', this)">
                <span class="nav-icon">📋</span> Task Audit
            </li>
            <li class="nav-item" onclick="switchAdminTab('tab-attendance', this)">
                <span class="nav-icon">⏱️</span> Attendance Reports
            </li>
            <li class="nav-item" onclick="switchAdminTab('tab-reportscenter', this)">
                <span class="nav-icon">📈</span> Reports Console
            </li>
            <li class="nav-item" onclick="switchAdminTab('tab-operations', this)">
                <span class="nav-icon">⚙️</span> Operations & Teams
            </li>
        </ul>
    </div>
    
    <div class="user-badge">
        <div class="user-name"><%= userName %></div>
        <div class="user-role"><%= empId.isEmpty() ? "" : empId + " • " %><%= userRole %></div>
    </div>
</aside>