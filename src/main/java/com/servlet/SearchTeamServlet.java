package com.servlet;

import com.dao.EmployeeDao;
import com.dao.TeamDao;
import com.model.Employee;
import com.model.Team;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.util.List;

@WebServlet({"/teams/search", "/teams/manage"})
public class SearchTeamServlet extends HttpServlet {
    private final TeamDao teamDao = new TeamDao();
    private final EmployeeDao employeeDao = new EmployeeDao();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {

        String keyword = request.getParameter("keyword");
        String deptIdParam = request.getParameter("departmentId");
        String status = request.getParameter("status");
        String managerIdParam = request.getParameter("managerId");

        Integer deptId = null;
        if (deptIdParam != null && !deptIdParam.isBlank()) {
            try {
                deptId = Integer.parseInt(deptIdParam.trim());
            } catch (NumberFormatException ignored) {}
        }

        Integer managerId = null;
        if (managerIdParam != null && !managerIdParam.isBlank()) {
            try {
                // Strip non-numeric characters so codes like "MGR01" resolve to 1
                String numericStr = managerIdParam.replaceAll("[^0-9]", "");
                if (!numericStr.isEmpty()) {
                    managerId = Integer.parseInt(numericStr);
                }
            } catch (NumberFormatException ignored) {}
        }

        List<Team> teams = teamDao.searchAndFilterTeams(keyword, deptId, status, managerId);
        List<Employee> allEmployees = employeeDao.getAllEmployees();

        request.setAttribute("teams", teams);
        request.setAttribute("allEmployees", allEmployees);
        request.setAttribute("keyword", keyword);
        request.setAttribute("departmentId", deptId);
        request.setAttribute("status", status);
        request.setAttribute("managerId", managerId);

        // Forward to the actual JSP file in webapp
        request.getRequestDispatcher("/manageTeams.jsp").forward(request, response);
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        doGet(request, response);
    }
}