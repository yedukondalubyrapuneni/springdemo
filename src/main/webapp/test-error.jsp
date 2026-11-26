<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" errorPage="error.jsp" %>
<%
    // Force a runtime NullPointerException
    String test = null;
    test.length();
%>