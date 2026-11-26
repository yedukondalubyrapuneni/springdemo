package com.Util;

import com.itextpdf.text.BaseColor;
import com.itextpdf.text.Document;
import com.itextpdf.text.Element;
import com.itextpdf.text.Font;
import com.itextpdf.text.FontFactory;
import com.itextpdf.text.PageSize;
import com.itextpdf.text.Paragraph;
import com.itextpdf.text.Phrase;
import com.itextpdf.text.pdf.PdfPCell;
import com.itextpdf.text.pdf.PdfPTable;
import com.itextpdf.text.pdf.PdfWriter;
import com.model.Payroll;

import jakarta.activation.CommandMap;
import jakarta.activation.DataHandler;
import jakarta.activation.DataSource;
import jakarta.activation.MailcapCommandMap;
import jakarta.mail.Authenticator;
import jakarta.mail.Message;
import jakarta.mail.Multipart;
import jakarta.mail.PasswordAuthentication;
import jakarta.mail.Session;
import jakarta.mail.Transport;
import jakarta.mail.internet.InternetAddress;
import jakarta.mail.internet.MimeBodyPart;
import jakarta.mail.internet.MimeMessage;
import jakarta.mail.internet.MimeMultipart;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.time.Month;
import java.time.format.TextStyle;
import java.util.Locale;
import java.util.Map;
import java.util.Properties;
import java.util.concurrent.CompletableFuture;

public class EmailService {

    private static final String SMTP_HOST = "smtp.gmail.com";
    private static final String SMTP_PORT = "465"; 
    private static final String SENDER_EMAIL = "byrapuneniyedukondalu@gmail.com";
    private static final String SENDER_APP_PASSWORD = "rsgqlltwxtqljlwk";

    static {
        // Register MIME handlers globally for Jakarta Activation inside Tomcat
        try {
            MailcapCommandMap mc = (MailcapCommandMap) CommandMap.getDefaultCommandMap();
            mc.addMailcap("text/html;; x-java-content-handler=org.eclipse.angus.mail.handlers.text_html");
            mc.addMailcap("text/xml;; x-java-content-handler=org.eclipse.angus.mail.handlers.text_xml");
            mc.addMailcap("text/plain;; x-java-content-handler=org.eclipse.angus.mail.handlers.text_plain");
            mc.addMailcap("multipart/*;; x-java-content-handler=org.eclipse.angus.mail.handlers.multipart_mixed");
            mc.addMailcap("message/rfc822;; x-java-content-handler=org.eclipse.angus.mail.handlers.message_rfc822");
            CommandMap.setDefaultCommandMap(mc);
        } catch (Exception e) {
            System.err.println(">>> [EmailService] Failed to initialize MailcapCommandMap: " + e.getMessage());
        }
    }

    public static void sendPayslipAsync(Payroll p, Map<String, String> empProfile, String txnId, String paymentMethod) {
        String recipientEmail = (empProfile != null) ? empProfile.get("email") : null;

        // DB fallback lookup with normalized space and case matching
        if (recipientEmail == null || recipientEmail.isBlank() || !recipientEmail.contains("@")) {
            String sqlFindEmail = "SELECT email, name FROM employee WHERE LOWER(TRIM(REPLACE(employee_id, ' ', ''))) = LOWER(TRIM(REPLACE(?, ' ', '')))";
            try (Connection conn = DBConnection.getConnection();
                 PreparedStatement ps = conn.prepareStatement(sqlFindEmail)) {
                ps.setString(1, p.getEmployeeId());
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        String dbEmail = rs.getString("email");
                        if (dbEmail != null && !dbEmail.isBlank()) {
                            recipientEmail = dbEmail.trim();
                            if (empProfile != null && !empProfile.containsKey("name")) {
                                empProfile.put("name", rs.getString("name"));
                            }
                        }
                    }
                }
            } catch (Exception ex) {
                System.err.println(">>> [EmailService] Direct DB email lookup failed: " + ex.getMessage());
            }
        }

        if (recipientEmail == null || recipientEmail.isBlank() || !recipientEmail.contains("@")) {
            System.err.println(">>> [EmailService] ABORT: No valid email address configured for employee: " + p.getEmployeeId());
            return;
        }

        final String cleanRecipient = recipientEmail.trim();
        System.out.println(">>> [EmailService] Initializing payslip email dispatch to: " + cleanRecipient + " for Employee: " + p.getEmployeeId());

        CompletableFuture.runAsync(() -> {
            try {
                // Ensure class loader context is set for background worker threads
                Thread.currentThread().setContextClassLoader(EmailService.class.getClassLoader());

                Properties props = new Properties();
                props.put("mail.smtp.auth", "true");
                props.put("mail.smtp.ssl.enable", "true");
                props.put("mail.smtp.host", SMTP_HOST);
                props.put("mail.smtp.port", SMTP_PORT);
                props.put("mail.smtp.ssl.protocols", "TLSv1.2 TLSv1.3");
                props.put("mail.smtp.ssl.trust", "smtp.gmail.com");
                props.put("mail.smtp.connectiontimeout", "10000");
                props.put("mail.smtp.timeout", "10000");
                props.put("mail.smtp.writetimeout", "10000");

                Session session = Session.getInstance(props, new Authenticator() {
                    @Override
                    protected PasswordAuthentication getPasswordAuthentication() {
                        return new PasswordAuthentication(SENDER_EMAIL.trim(), SENDER_APP_PASSWORD.trim());
                    }
                });

                session.setDebug(true);

                String monthName = Month.of(p.getPayrollMonth()).getDisplayName(TextStyle.FULL, Locale.ENGLISH);
                String period = monthName + " " + p.getPayrollYear();

                Message message = new MimeMessage(session);
                message.setFrom(new InternetAddress(SENDER_EMAIL, "EMS Enterprise HR"));
                message.setRecipients(Message.RecipientType.TO, InternetAddress.parse(cleanRecipient));

                String empDisplayName = (empProfile != null && empProfile.get("name") != null) ? empProfile.get("name") : p.getEmployeeId();
                message.setSubject("Payslip for " + period + " - " + empDisplayName);

                // 1. Email Body Part
                MimeBodyPart messageBodyPart = new MimeBodyPart();
                String htmlContent = buildPayslipHtml(p, empProfile, period, txnId, paymentMethod);
                messageBodyPart.setContent(htmlContent, "text/html; charset=utf-8");

                // 2. Multipart Container
                Multipart multipart = new MimeMultipart();
                multipart.addBodyPart(messageBodyPart);

                // 3. Dynamic PDF Attachment
                byte[] pdfBytes = generatePayslipPdf(p, empProfile, period, txnId, paymentMethod);
                if (pdfBytes != null && pdfBytes.length > 0) {
                    MimeBodyPart attachmentPart = new MimeBodyPart();
                    DataSource source = new InMemoryByteArrayDataSource(pdfBytes, "application/pdf", "Payslip.pdf");
                    attachmentPart.setDataHandler(new DataHandler(source));
                    attachmentPart.setFileName("Payslip_" + p.getEmployeeId().replaceAll("\\s+", "") + "_" + monthName + "_" + p.getPayrollYear() + ".pdf");
                    multipart.addBodyPart(attachmentPart);
                }

                message.setContent(multipart);
                message.saveChanges();

                Transport.send(message);
                System.out.println(">>> [EmailService] SUCCESS: Automated payslip + PDF sent to: " + cleanRecipient);

            } catch (Exception e) {
                System.err.println(">>> [EmailService] SMTP SEND ERROR for " + cleanRecipient + ": " + e.getMessage());
                e.printStackTrace();
            }
        });
    }

    private static byte[] generatePayslipPdf(Payroll p, Map<String, String> profile, String period, String txnId, String paymentMethod) {
        try (ByteArrayOutputStream baos = new ByteArrayOutputStream()) {
            Document doc = new Document(PageSize.A4, 36, 36, 36, 36);
            PdfWriter.getInstance(doc, baos);
            doc.open();

            Font titleFont = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 18, BaseColor.DARK_GRAY);
            Font headerFont = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 11, BaseColor.WHITE);
            Font cellFont = FontFactory.getFont(FontFactory.HELVETICA, 10, BaseColor.BLACK);
            Font boldFont = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 10, BaseColor.BLACK);
            Font otFont = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 10, new BaseColor(5, 150, 105));

            Paragraph title = new Paragraph("EMS ENTERPRISE - SALARY PAYSLIP", titleFont);
            title.setAlignment(Element.ALIGN_CENTER);
            doc.add(title);

            Paragraph sub = new Paragraph("Disbursement Period: " + period + "\n\n", FontFactory.getFont(FontFactory.HELVETICA, 10, BaseColor.GRAY));
            sub.setAlignment(Element.ALIGN_CENTER);
            doc.add(sub);

            PdfPTable empTable = new PdfPTable(2);
            empTable.setWidthPercentage(100);
            empTable.addCell(new Phrase("Employee ID: " + p.getEmployeeId(), boldFont));
            empTable.addCell(new Phrase("Employee Name: " + (profile != null ? profile.getOrDefault("name", "Employee") : "Employee"), boldFont));
            empTable.addCell(new Phrase("Department: " + (profile != null ? profile.getOrDefault("department", "IT") : "IT"), cellFont));
            empTable.addCell(new Phrase("Payment Mode: " + paymentMethod, cellFont));
            empTable.addCell(new Phrase("Reference / UTR: " + txnId, cellFont));
            empTable.addCell(new Phrase("Bank Account: " + (profile != null ? profile.getOrDefault("bankName", "-") + " (" + profile.getOrDefault("bankAccount", "-") + ")" : "-"), cellFont));
            doc.add(empTable);

            doc.add(new Paragraph("\n"));

            PdfPTable table = new PdfPTable(2);
            table.setWidthPercentage(100);

            PdfPCell c1 = new PdfPCell(new Phrase("Description", headerFont));
            c1.setBackgroundColor(new BaseColor(15, 23, 42));
            c1.setPadding(6);
            table.addCell(c1);

            PdfPCell c2 = new PdfPCell(new Phrase("Amount (INR)", headerFont));
            c2.setBackgroundColor(new BaseColor(15, 23, 42));
            c2.setHorizontalAlignment(Element.ALIGN_RIGHT);
            c2.setPadding(6);
            table.addCell(c2);

            BigDecimal gross = p.getGrossSalary() != null ? p.getGrossSalary() : BigDecimal.ZERO;
            BigDecimal deductions = p.getTotalDeductions() != null ? p.getTotalDeductions() : BigDecimal.ZERO;
            BigDecimal net = p.getNetSalary() != null ? p.getNetSalary() : BigDecimal.ZERO;

            BigDecimal otHours = BigDecimal.ZERO;
            BigDecimal otAmount = BigDecimal.ZERO;
            try {
                if (p.getOtHours() != null) otHours = p.getOtHours();
                if (p.getOtAmount() != null) otAmount = p.getOtAmount();
            } catch (Exception ignored) {}

            table.addCell(new Phrase("Gross Salary Baseline", cellFont));
            PdfPCell gCell = new PdfPCell(new Phrase("INR " + String.format("%.2f", gross), boldFont));
            gCell.setHorizontalAlignment(Element.ALIGN_RIGHT);
            table.addCell(gCell);

            if (otHours.compareTo(BigDecimal.ZERO) > 0) {
                PdfPCell otLbl = new PdfPCell(new Phrase("Overtime Pay (" + otHours + " hrs @ 1.5x)", otFont));
                otLbl.setBackgroundColor(new BaseColor(236, 253, 245));
                table.addCell(otLbl);

                PdfPCell otVal = new PdfPCell(new Phrase("+ INR " + String.format("%.2f", otAmount), otFont));
                otVal.setBackgroundColor(new BaseColor(236, 253, 245));
                otVal.setHorizontalAlignment(Element.ALIGN_RIGHT);
                table.addCell(otVal);
            }

            table.addCell(new Phrase("Total Deductions (PT / PF / LOP)", cellFont));
            PdfPCell dCell = new PdfPCell(new Phrase("- INR " + String.format("%.2f", deductions), boldFont));
            dCell.setHorizontalAlignment(Element.ALIGN_RIGHT);
            table.addCell(dCell);

            PdfPCell netLbl = new PdfPCell(new Phrase("Net Take-Home Pay", boldFont));
            netLbl.setBackgroundColor(new BaseColor(236, 253, 245));
            table.addCell(netLbl);

            PdfPCell netVal = new PdfPCell(new Phrase("INR " + String.format("%.2f", net), boldFont));
            netVal.setBackgroundColor(new BaseColor(236, 253, 245));
            netVal.setHorizontalAlignment(Element.ALIGN_RIGHT);
            table.addCell(netVal);

            doc.add(table);

            Paragraph footer = new Paragraph("\nThis is a system-generated document and requires no physical signature.", FontFactory.getFont(FontFactory.HELVETICA_OBLIQUE, 8, BaseColor.GRAY));
            footer.setAlignment(Element.ALIGN_CENTER);
            doc.add(footer);

            doc.close();
            return baos.toByteArray();
        } catch (Exception e) {
            System.err.println("PDF generation error: " + e.getMessage());
            return null;
        }
    }

    private static String buildPayslipHtml(Payroll p, Map<String, String> profile, String period, String txnId, String paymentMethod) {
        String empName = (profile != null) ? profile.getOrDefault("name", "Employee") : "Employee";
        String empId = p.getEmployeeId();
        String dept = (profile != null) ? profile.getOrDefault("department", "IT") : "IT";
        String bank = (profile != null) ? profile.getOrDefault("bankName", "-") + " (" + profile.getOrDefault("bankAccount", "-") + ")" : "-";

        BigDecimal gross = p.getGrossSalary() != null ? p.getGrossSalary() : BigDecimal.ZERO;
        BigDecimal deductions = p.getTotalDeductions() != null ? p.getTotalDeductions() : BigDecimal.ZERO;
        BigDecimal net = p.getNetSalary() != null ? p.getNetSalary() : BigDecimal.ZERO;

        BigDecimal otHours = BigDecimal.ZERO;
        BigDecimal otAmount = BigDecimal.ZERO;
        try {
            if (p.getOtHours() != null) otHours = p.getOtHours();
            if (p.getOtAmount() != null) otAmount = p.getOtAmount();
        } catch (Exception ignored) {}

        String otHtmlRow = "";
        if (otHours.compareTo(BigDecimal.ZERO) > 0) {
            otHtmlRow = "<tr style=\"background: #ecfdf5;\">"
                      + "  <td style=\"padding: 10px; border: 1px solid #e2e8f0; color: #059669; font-weight: bold;\">Overtime Pay (" + otHours + " hrs @ 1.5x)</td>"
                      + "  <td style=\"padding: 10px; border: 1px solid #e2e8f0; text-align: right; color: #059669; font-weight: bold;\">+ &#8377; " + String.format("%.2f", otAmount) + "</td>"
                      + "</tr>";
        }

        return "<div style=\"font-family: Arial, sans-serif; max-width: 650px; margin: 0 auto; background: #ffffff; border: 1px solid #e2e8f0; border-radius: 12px; overflow: hidden;\">"
                + "  <div style=\"background: #0f172a; padding: 22px 28px; color: #ffffff;\">"
                + "    <h2 style=\"margin: 0; font-size: 20px;\"><span style=\"color: #60a5fa;\">EMS</span> Enterprise</h2>"
                + "    <div style=\"font-size: 13px; color: #94a3b8; margin-top: 4px;\">Monthly Salary Disbursement &bull; " + period + "</div>"
                + "  </div>"
                + "  <div style=\"padding: 24px 28px;\">"
                + "    <p style=\"font-size: 14px; color: #334155;\">Dear <strong>" + empName + "</strong>,</p>"
                + "    <p style=\"font-size: 13px; color: #64748b;\">Your monthly salary for <strong>" + period + "</strong> has been credited. Please find your official PDF payslip voucher attached to this email.</p>"
                + "    <div style=\"background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 14px 18px; margin: 20px 0; font-size: 12.5px; line-height: 1.8;\">"
                + "      <div><strong>Employee ID:</strong> " + empId + "</div>"
                + "      <div><strong>Department:</strong> " + dept + "</div>"
                + "      <div><strong>Payment Mode:</strong> " + paymentMethod + "</div>"
                + "      <div><strong>Reference / UTR ID:</strong> <span style=\"font-family: monospace; font-weight: bold;\">" + txnId + "</span></div>"
                + "      <div><strong>Credited Account:</strong> " + bank + "</div>"
                + "    </div>"
                + "    <table style=\"width: 100%; border-collapse: collapse; margin-top: 15px; font-size: 13px;\">"
                + "      <tbody>"
                + "        <tr><td style=\"padding: 10px; border: 1px solid #e2e8f0;\">Gross Earnings</td><td style=\"padding: 10px; border: 1px solid #e2e8f0; text-align: right; font-weight: 600;\">&#8377; " + String.format("%.2f", gross) + "</td></tr>"
                +          otHtmlRow
                + "        <tr><td style=\"padding: 10px; border: 1px solid #e2e8f0;\">Total Deductions</td><td style=\"padding: 10px; border: 1px solid #e2e8f0; text-align: right; color: #dc2626; font-weight: 600;\">- &#8377; " + String.format("%.2f", deductions) + "</td></tr>"
                + "        <tr style=\"background: #ecfdf5;\"><td style=\"padding: 12px; border: 1px solid #a7f3d0; font-weight: bold; color: #065f46;\">Net Disbursed Take-Home</td><td style=\"padding: 12px; border: 1px solid #a7f3d0; text-align: right; font-weight: bold; color: #059669; font-size: 15px;\">&#8377; " + String.format("%.2f", net) + "</td></tr>"
                + "      </tbody>"
                + "    </table>"
                + "    <p style=\"font-size: 11px; color: #94a3b8; margin-top: 24px; text-align: center;\">This is an automated system notification generated by EMS Enterprise.</p>"
                + "  </div>"
                + "</div>";
    }

    private static class InMemoryByteArrayDataSource implements DataSource {
        private final byte[] data;
        private final String type;
        private final String name;

        public InMemoryByteArrayDataSource(byte[] data, String type, String name) {
            this.data = data;
            this.type = type;
            this.name = name;
        }

        @Override
        public InputStream getInputStream() throws IOException {
            return new ByteArrayInputStream(data);
        }

        @Override
        public OutputStream getOutputStream() throws IOException {
            throw new IOException("Writing not supported");
        }

        @Override
        public String getContentType() {
            return type;
        }

        @Override
        public String getName() {
            return name;
        }
    }
}