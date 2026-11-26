<%@ page contentType="text/html;charset=UTF-8" %>
<%@ page import="java.util.List" %>
<%@ page import="com.example.demo.model.Attendance" %>
<%@ page import="com.example.demo.model.Employee" %>

<!DOCTYPE html>
<html>

<head>

    <title>Attendance History</title>

    <style>

        body {
            font-family: Arial, sans-serif;
            background: #f5f7fa;
            padding: 30px;
        }

        .container {
            max-width: 1000px;
            margin: auto;
            background: white;
            padding: 30px;
            border-radius: 10px;
        }

        .search {
            text-align: center;
            margin-bottom: 25px;
        }

        input {
            padding: 10px;
            width: 250px;
        }

        button {
            padding: 10px 20px;
            background: #007bff;
            color: white;
            border: none;
            cursor: pointer;
            border-radius: 4px;
        }

        button:hover {
            background: #0056b3;
        }

        table {
            width: 100%;
            border-collapse: collapse;
        }

        th, td {
            padding: 12px;
            border: 1px solid #ddd;
            text-align: center;
        }

        th {
            background: #007bff;
            color: white;
        }

        .summary {
            margin-top: 20px;
            display: flex;
            justify-content: space-around;
        }

        .error {
            background: #f8d7da;
            padding: 15px;
            color: #721c24;
            border-radius: 5px;
            margin-bottom: 20px;
        }

        .back-btn {
            display: inline-block;
            margin-top: 30px;
            padding: 10px 16px;
            background: #007bff;
            color: white;
            text-decoration: none;
            border-radius: 5px;
            font-weight: bold;
            font-size: 14px;
        }

        .back-btn:hover {
            background: #0056b3;
        }

    </style>

</head>

<body>

<div class="container">

    <h1>ATTENDANCE HISTORY</h1>

    <div class="search">

        <form method="get"
              action="<%= request.getContextPath() %>/attendance/history">

            <input type="text"
                   name="employeeId"
                   placeholder="Enter Employee ID"
                   required>

            <button type="submit">
                Search
            </button>

        </form>

    </div>

    <% if (request.getAttribute("error") != null) { %>

        <div class="error">
            <%= request.getAttribute("error") %>
        </div>

    <% } %>

    <%
        Employee employee =
                (Employee)
                        request.getAttribute("employee");

        List<Attendance> history =
                (List<Attendance>)
                        request.getAttribute("history");
    %>

    <% if (employee != null) { %>

        <h2>
            Employee:
            <%= employee.getName() %>
        </h2>

        <p>
            Employee ID:
            <strong><%= employee.getEmployeeId() %></strong>
        </p>

        <p>
            Department:
            <strong><%= employee.getDepartment() %></strong>
        </p>

        <table>

            <tr>
                <th>Date</th>
                <th>Check-In</th>
                <th>Check-Out</th>
                <th>Status</th>
            </tr>

            <%
                if (history != null) {
                    for (Attendance a : history) {
            %>

            <tr>

                <td>
                    <%= a.getFormattedDate() %>
                </td>

                <td>
                    <%= a.getFormattedCheckInTime() %>
                </td>

                <td>
                    <%= a.getFormattedCheckOutTime() %>
                </td>

                <td>
                    <%= a.getStatus() %>
                </td>

            </tr>

            <%
                    }
                }
            %>

        </table>

        <div class="summary">

            <div>
                Total Present:
                <strong>
                    <%= request.getAttribute("presentCount") %>
                </strong>
            </div>

            <div>
                Total Absent:
                <strong>
                    <%= request.getAttribute("absentCount") %>
                </strong>
            </div>

            <div>
                Total Leave:
                <strong>
                    <%= request.getAttribute("leaveCount") %>
                </strong>
            </div>

        </div>

    <% } %>

    <div>
        <a class="back-btn" href="<%= request.getContextPath() %>/attendance/dashboard">
            Back to Attendance Dashboard
        </a>
    </div>

</div>

</body>

</html>