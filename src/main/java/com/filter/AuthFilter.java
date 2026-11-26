package com.filter;

import com.model.Employee;
import jakarta.servlet.*;
import jakarta.servlet.annotation.WebFilter;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;

@WebFilter("/*")
public class AuthFilter implements Filter {

    @Override
    public void doFilter(ServletRequest req, ServletResponse res, FilterChain chain)
            throws IOException, ServletException {

        HttpServletRequest request = (HttpServletRequest) req;
        HttpServletResponse response = (HttpServletResponse) res;

        String path = request.getRequestURI().substring(request.getContextPath().length());

        // 1. Allow public routes: Login, Self-Registration, Logout, and Static Assets
        if (path.equals("/login") || path.equals("/login.jsp")
                || path.equals("/register") || path.equals("/register.jsp")
                || path.equals("/logout")
                || path.startsWith("/css") || path.startsWith("/js") || path.startsWith("/images")) {
            chain.doFilter(req, res);
            return;
        }

        // 2. Validate session authentication
        HttpSession session = request.getSession(false);
        Employee user = (session != null) ? (Employee) session.getAttribute("loggedInEmployee") : null;

        if (user == null) {
            response.sendRedirect(request.getContextPath() + "/login");
            return;
        }

        // 3. Company Reports, Dashboards & Daily Rosters: Accessible ONLY to HR designations
        if ((path.startsWith("/attendance/dashboard") 
                || path.startsWith("/attendance/daily") 
                || path.startsWith("/attendance/monthly")) 
                && !user.isHrDesignation()) {
            
            // Standard employees attempting to view overall company reports are redirected
            response.sendRedirect(request.getContextPath() + "/attendance/action");
            return;
        }

        // 4. /attendance/action remains accessible to all authenticated users (EMPLOYEE and HR)
        // allowing everyone to self-record check-in, breaks, checkout, and personal history
        chain.doFilter(req, res);
    }
}