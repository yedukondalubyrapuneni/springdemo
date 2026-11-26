package com.Util;

import com.dao.SystemErrorDAO;
import com.model.SystemError;

public class SystemLogger {
    private static final SystemErrorDAO errorDAO = new SystemErrorDAO();

    public static void logException(String moduleName, String severity, Exception ex, Integer userId) {
        String errType = ex.getClass().getSimpleName();
        String errMsg = ex.getMessage() != null ? ex.getMessage() : "Unknown exception occurred";
        
        SystemError err = new SystemError(moduleName, errType, errMsg, severity, userId);
        errorDAO.recordSystemError(err);
    }
}