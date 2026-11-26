package com.listener;

import com.dao.AttendanceDao;
import jakarta.servlet.ServletContextEvent;
import jakarta.servlet.ServletContextListener;
import jakarta.servlet.annotation.WebListener;

import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

@WebListener
public class AutoCheckoutListener implements ServletContextListener {

    private ScheduledExecutorService scheduler;

    @Override
    public void contextInitialized(ServletContextEvent sce) {
        scheduler = Executors.newSingleThreadScheduledExecutor();
        AttendanceDao attendanceDao = new AttendanceDao();

        // Run immediately on server start, then every 60 seconds
        scheduler.scheduleAtFixedRate(() -> {
            try {
                attendanceDao.autoCheckOutUnclosedShifts();
            } catch (Exception e) {
                System.err.println("Background auto-checkout error: " + e.getMessage());
            }
        }, 0, 60, TimeUnit.SECONDS);

        System.out.println("AutoCheckoutListener started: monitoring 6:15 PM shift closures.");
    }

    @Override
    public void contextDestroyed(ServletContextEvent sce) {
        if (scheduler != null && !scheduler.isShutdown()) {
            scheduler.shutdownNow();
        }
    }
}