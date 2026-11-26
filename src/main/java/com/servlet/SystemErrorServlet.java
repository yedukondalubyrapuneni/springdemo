package com.servlet;

import com.dao.SystemErrorDAO;
import com.model.SystemError;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.util.List;

@WebServlet("/admin/system-errors")
public class SystemErrorServlet extends HttpServlet {
    private final SystemErrorDAO errorDAO = new SystemErrorDAO();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        String severity = request.getParameter("severity");
        String module = request.getParameter("module");

        List<SystemError> errors = errorDAO.getFilteredErrors(severity, module, 50);

        request.setAttribute("errorList", errors);
        request.setAttribute("selectedSeverity", severity);
        request.setAttribute("selectedModule", module);

        request.getRequestDispatcher("/admin/system-errors.jsp").forward(request, response);
    }
}