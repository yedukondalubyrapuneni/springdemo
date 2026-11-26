package com.servlet;

import com.dao.PayrollDAO;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.io.PrintWriter;
import java.util.Map;

@WebServlet("/api/employee-details")
public class EmployeeDetailsApiServlet extends HttpServlet {
    private final PayrollDAO dao = new PayrollDAO();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        String empId = request.getParameter("empId");
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        PrintWriter out = response.getWriter();
        if (empId == null || empId.isBlank()) {
            out.print("{}");
            return;
        }

        Map<String, String> data = dao.getEmployeeProfileForSalary(empId.trim());
        StringBuilder json = new StringBuilder("{");
        int i = 0;
        for (Map.Entry<String, String> entry : data.entrySet()) {
            if (i++ > 0) json.append(",");
            json.append("\"").append(entry.getKey()).append("\":\"").append(entry.getValue() != null ? entry.getValue() : "").append("\"");
        }
        json.append("}");
        out.print(json.toString());
    }
}