package com.Util;

import jakarta.mail.*;
import jakarta.mail.internet.InternetAddress;
import jakarta.mail.internet.MimeMessage;
import java.util.Properties;

public class EmailUtil {

    private static final String SMTP_HOST = "smtp.gmail.com";
    private static final String SMTP_PORT = "465"; 
    private static final String SENDER_EMAIL = "byrapuneniyedukondalu@gmail.com";
    private static final String SENDER_APP_PASSWORD = "mcifnigiozbddqjq"; 

    public static void sendManagerCredentials(String recipientEmail, String managerName, String managerId, String plainPassword) {
        if (recipientEmail == null || recipientEmail.isBlank()) {
            System.err.println("Email dispatch skipped: No recipient email provided for " + managerId);
            return;
        }

        Properties props = new Properties();
        props.put("mail.smtp.host", SMTP_HOST);
        props.put("mail.smtp.port", SMTP_PORT);
        props.put("mail.smtp.auth", "true");
        props.put("mail.smtp.ssl.enable", "true");
        props.put("mail.smtp.ssl.protocols", "TLSv1.2 TLSv1.3");
        props.put("mail.smtp.ssl.trust", "smtp.gmail.com");
        props.put("mail.smtp.socketFactory.port", SMTP_PORT);
        props.put("mail.smtp.socketFactory.class", "javax.net.ssl.SSLSocketFactory");
        props.put("mail.smtp.connectiontimeout", "10000"); // 10s timeout
        props.put("mail.smtp.timeout", "10000");

        Session session = Session.getInstance(props, new Authenticator() {
            @Override
            protected PasswordAuthentication getPasswordAuthentication() {
                return new PasswordAuthentication(SENDER_EMAIL, SENDER_APP_PASSWORD);
            }
        });

        // Prints the real-time SMTP handshake directly in Eclipse Console
        session.setDebug(true);

        new Thread(() -> {
            try {
                Message message = new MimeMessage(session);
                message.setFrom(new InternetAddress(SENDER_EMAIL, "EMS Enterprise Admin"));
                message.setRecipients(Message.RecipientType.TO, InternetAddress.parse(recipientEmail.trim()));
                message.setSubject("Welcome to EMS Enterprise - Manager Account Credentials");

                String emailBody = "<div style='font-family: Arial, sans-serif; padding: 20px; color: #333;'>"
                        + "<h2 style='color: #2563eb;'>EMS Enterprise Portal</h2>"
                        + "<p>Dear <strong>" + managerName + "</strong>,</p>"
                        + "<p>Your executive Manager account has been provisioned by the System Administrator.</p>"
                        + "<div style='background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 15px; margin: 20px 0;'>"
                        + "<p style='margin: 6px 0;'><strong>Manager ID:</strong> <code style='font-size: 15px; color: #0f172a;'>" + managerId + "</code></p>"
                        + "<p style='margin: 6px 0;'><strong>Temporary Password:</strong> <code style='font-size: 15px; color: #0f172a;'>" + plainPassword + "</code></p>"
                        + "<p style='margin: 6px 0;'><strong>Assigned Role:</strong> MANAGER</p>"
                        + "</div>"
                        + "<p>You can sign in to view your assigned teams and supervise shifts here:</p>"
                        + "<p><a href='http://localhost:8080/EmployeeManagementSystem1/login' style='background: #2563eb; color: #fff; text-decoration: none; padding: 10px 20px; border-radius: 6px; display: inline-block; font-weight: bold;'>Log In to EMS Portal</a></p>"
                        + "<br><hr style='border: none; border-top: 1px solid #e2e8f0;'>"
                        + "<small style='color: #64748b;'>This is an automated system notification. Please do not reply directly to this email.</small>"
                        + "</div>";

                message.setContent(emailBody, "text/html; charset=utf-8");
                Transport.send(message);
                System.out.println(">>> SUCCESS: Credentials email dispatched to " + recipientEmail);
            } catch (Exception e) {
                System.err.println(">>> FAILED to send email to " + recipientEmail + ": " + e.getMessage());
                e.printStackTrace(); // Prints exact line of failure
            }
        }).start();
    }

    // Direct standalone test runner
    public static void main(String[] args) {
        System.out.println("Initiating test email...");
        sendManagerCredentials("byrapuneniyedukondalu@gmail.com", "Yedukondalu", "MGR01", "TestPass@123");
    }
}