package com.servlet;

import com.dao.LoginHistoryDAO;
import com.model.LoginHistory;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.util.List;

@WebServlet("/admin/login-history")
public class LoginHistoryServlet extends HttpServlet {
    private final LoginHistoryDAO dao = new LoginHistoryDAO();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        String email = request.getParameter("email");
        String activityType = request.getParameter("activityType");
        
        int page = 1;
        int pageSize = 20;
        try {
            if (request.getParameter("page") != null) {
                page = Integer.parseInt(request.getParameter("page"));
            }
        } catch (NumberFormatException ignored) {}

        int offset = (page - 1) * pageSize;
        List<LoginHistory> historyList = dao.getFilteredHistory(email, activityType, pageSize, offset);

        request.setAttribute("historyList", historyList);
        request.setAttribute("currentPage", page);
        request.setAttribute("selectedEmail", email);
        request.setAttribute("selectedActivity", activityType);

        request.getRequestDispatcher("/admin/login-history.jsp").forward(request, response);
    }
}