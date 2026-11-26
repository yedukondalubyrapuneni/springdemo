<%@ page contentType="text/html;charset=UTF-8" %>
<%@ page import="java.sql.Connection, java.sql.PreparedStatement, java.sql.ResultSet" %>
<%
    // =========================================================================
    // DYNAMIC COMPANY BRANDING LOADER (Logo & Company Name)
    // =========================================================================
    String loginLogoUrl = (String) application.getAttribute("COMPANY_LOGO_URL");
    String loginCompanyName = (String) application.getAttribute("COMPANY_NAME");

    try {
        String propsPath = application.getRealPath("/WEB-INF/branding.properties");
        java.io.File propFile = new java.io.File(propsPath);
        if (propFile.exists()) {
            java.util.Properties props = new java.util.Properties();
            try (java.io.FileInputStream fis = new java.io.FileInputStream(propFile)) {
                props.load(fis);
            }
            if (loginLogoUrl == null || loginLogoUrl.isBlank()) {
                loginLogoUrl = props.getProperty("COMPANY_LOGO_URL", "");
            }
            if (loginCompanyName == null || loginCompanyName.isBlank()) {
                loginCompanyName = props.getProperty("COMPANY_NAME", "");
            }
        }
    } catch (Exception ignored) {}

    // Fallback to database system_settings if COMPANY_NAME is not yet cached
    if (loginCompanyName == null || loginCompanyName.isBlank()) {
        try (Connection conn = com.Util.DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(
                 "SELECT setting_value FROM system_settings WHERE setting_key = 'COMPANY_NAME' LIMIT 1");
             ResultSet rs = ps.executeQuery()) {
            if (rs.next()) {
                String v = rs.getString("setting_value");
                if (v != null && !v.isBlank()) {
                    loginCompanyName = v.trim();
                    application.setAttribute("COMPANY_NAME", loginCompanyName);
                }
            }
        } catch (Exception ignored) {}
    }

    if (loginLogoUrl == null) loginLogoUrl = "";
    if (loginCompanyName == null || loginCompanyName.isBlank()) loginCompanyName = "EMS Enterprise Suite";
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sign In | <%= loginCompanyName %></title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        :root {
            --brand-primary: #2563eb;
            --brand-gradient: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
            --surface-bg: #f8fafc;
            --surface-card: #ffffff;
            --border-subtle: #e2e8f0;
            --text-primary: #0f172a;
            --text-secondary: #475569;
            --text-muted: #94a3b8;
            --emerald: #10b981;
            --emerald-surface: #ecfdf5;
            --rose: #f43f5e;
            --rose-surface: #fff1f2;
            --shadow-card: 0 20px 25px -5px rgb(0 0 0 / 0.05), 0 8px 10px -6px rgb(0 0 0 / 0.03);
        }

        * { box-sizing: border-box; margin: 0; padding: 0; }

        body {
            font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, sans-serif;
            background-color: #0b0f19;
            color: var(--text-primary);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 24px;
            background-image: 
                radial-gradient(at 0% 0%, rgba(37, 99, 235, 0.15) 0px, transparent 50%),
                radial-gradient(at 100% 100%, rgba(16, 185, 129, 0.1) 0px, transparent 50%);
        }

        .auth-container {
            width: 100%;
            max-width: 980px;
            background: var(--surface-card);
            border-radius: 20px;
            display: grid;
            grid-template-columns: 1.15fr 1fr;
            box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
            overflow: hidden;
            border: 1px solid rgba(255, 255, 255, 0.1);
        }

        /* Left Side: Modern Interactive Form */
        .auth-form-side {
            padding: 48px 44px;
            display: flex;
            flex-direction: column;
            justify-content: center;
        }

        .brand-header {
            margin-bottom: 28px;
        }

        .brand-logo-wrap {
            display: flex;
            align-items: center;
            gap: 12px;
            margin-bottom: 16px;
        }

        .brand-logo-img {
            height: 46px;
            max-width: 150px;
            object-fit: contain;
            border-radius: 8px;
        }

        .brand-icon {
            width: 42px;
            height: 42px;
            background: var(--brand-gradient);
            border-radius: 12px;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            color: #ffffff;
            font-weight: 800;
            font-size: 20px;
            box-shadow: 0 4px 12px rgba(37, 99, 235, 0.3);
            flex-shrink: 0;
        }

        .brand-company-name {
            font-size: 14px;
            font-weight: 800;
            color: var(--brand-primary);
            letter-spacing: -0.01em;
        }

        .brand-header h1 {
            font-size: 24px;
            font-weight: 800;
            letter-spacing: -0.02em;
            color: var(--text-primary);
        }

        .brand-header p {
            font-size: 13px;
            color: var(--text-secondary);
            margin-top: 4px;
        }

        /* Toast Notifications */
        .alert-box {
            padding: 12px 16px;
            border-radius: 10px;
            font-size: 13px;
            font-weight: 600;
            display: flex;
            align-items: center;
            gap: 10px;
            margin-bottom: 20px;
        }
        .alert-success { background: var(--emerald-surface); border: 1px solid #a7f3d0; color: #065f46; }
        .alert-error   { background: var(--rose-surface); border: 1px solid #fecdd3; color: #9f1239; }

        /* Form Inputs */
        .form-group {
            margin-bottom: 18px;
        }

        .form-label {
            display: block;
            font-size: 11px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: var(--text-secondary);
            margin-bottom: 6px;
        }

        .input-wrapper {
            position: relative;
        }

        .form-input {
            width: 100%;
            height: 46px;
            border: 1px solid var(--border-subtle);
            border-radius: 10px;
            padding: 0 14px;
            font-size: 14px;
            font-family: inherit;
            color: var(--text-primary);
            background: var(--surface-bg);
            outline: none;
            transition: all 0.2s ease;
        }

        .form-input:focus {
            background: #ffffff;
            border-color: var(--brand-primary);
            box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.15);
        }

        .toggle-password {
            position: absolute;
            right: 14px;
            top: 50%;
            transform: translateY(-50%);
            background: none;
            border: none;
            color: var(--text-muted);
            cursor: pointer;
            font-size: 12px;
            font-weight: 600;
            user-select: none;
        }
        .toggle-password:hover { color: var(--text-primary); }

        .btn-submit {
            width: 100%;
            height: 48px;
            background: var(--brand-gradient);
            color: #ffffff;
            border: none;
            border-radius: 10px;
            font-size: 14px;
            font-weight: 700;
            cursor: pointer;
            margin-top: 10px;
            box-shadow: 0 4px 12px rgba(37, 99, 235, 0.25);
            transition: all 0.2s ease;
        }

        .btn-submit:hover {
            transform: translateY(-1.5px);
            box-shadow: 0 6px 16px rgba(37, 99, 235, 0.35);
        }

        .btn-submit:active { transform: translateY(0); }

        .auth-footer {
            margin-top: 24px;
            padding-top: 20px;
            border-top: 1px solid var(--border-subtle);
            text-align: center;
            font-size: 13px;
            color: var(--text-secondary);
        }

        .auth-footer a {
            color: var(--brand-primary);
            text-decoration: none;
            font-weight: 700;
        }

        /* Right Side: Enterprise Presentation Banner */
        .auth-showcase-side {
            background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
            padding: 48px 40px;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
            color: #ffffff;
            position: relative;
            overflow: hidden;
        }

        .auth-showcase-side::after {
            content: '';
            position: absolute;
            width: 250px;
            height: 250px;
            background: radial-gradient(circle, rgba(37, 99, 235, 0.3) 0%, transparent 70%);
            top: -50px;
            right: -50px;
        }

        .showcase-content h2 {
            font-size: 22px;
            font-weight: 800;
            letter-spacing: -0.02em;
            line-height: 1.35;
            margin-bottom: 12px;
        }

        .showcase-content p {
            font-size: 13px;
            color: #94a3b8;
            line-height: 1.6;
        }

        .feature-list {
            list-style: none;
            margin-top: 28px;
            display: flex;
            flex-direction: column;
            gap: 14px;
        }

        .feature-item {
            display: flex;
            align-items: center;
            gap: 12px;
            font-size: 13px;
            font-weight: 500;
            color: #e2e8f0;
        }

        .check-badge {
            width: 20px;
            height: 20px;
            background: rgba(16, 185, 129, 0.2);
            color: var(--emerald);
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 11px;
            font-weight: bold;
        }

        .showcase-badge {
            background: rgba(255, 255, 255, 0.08);
            border: 1px solid rgba(255, 255, 255, 0.12);
            padding: 12px 16px;
            border-radius: 12px;
            font-size: 12px;
            color: #cbd5e1;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }

        @media (max-width: 820px) {
            .auth-container { grid-template-columns: 1fr; max-width: 460px; }
            .auth-showcase-side { display: none; }
            .auth-form-side { padding: 36px 28px; }
        }
    </style>
</head>
<body>

<div class="auth-container">
    <!-- Left: Login Form -->
    <div class="auth-form-side">
        <div class="brand-header">
            <div class="brand-logo-wrap">
                <% if (!loginLogoUrl.isEmpty()) { %>
                    <img src="<%= loginLogoUrl %>" alt="<%= loginCompanyName %> Logo" class="brand-logo-img">
                <% } else { %>
                    <div class="brand-icon"><%= loginCompanyName.substring(0, 1).toUpperCase() %></div>
                <% } %>
                <span class="brand-company-name"><%= loginCompanyName %></span>
            </div>
            <h1>Welcome Back</h1>
            <p>Sign in with your Employee ID or registered Email</p>
        </div>

        <!-- Success Toast (Displays auto-generated ID after registration) -->
        <% if (request.getAttribute("successMessage") != null) { %>
            <div class="alert-box alert-success">
                <span>✔</span>
                <div><%= request.getAttribute("successMessage") %></div>
            </div>
        <% } %>

        <!-- Error Toast -->
        <% if (request.getAttribute("error") != null) { %>
            <div class="alert-box alert-error">
                <span>⚠</span>
                <div><%= request.getAttribute("error") %></div>
            </div>
        <% } %>

        <form action="<%= request.getContextPath() %>/login" method="post" autocomplete="off">
            <div class="form-group">
                <label class="form-label" for="identifier">Employee ID or Email Address</label>
                <div class="input-wrapper">
                    <input type="text" id="identifier" name="identifier" class="form-input" 
                           placeholder="e.g. EMP101 or name@company.com" required autofocus>
                </div>
            </div>

            <div class="form-group">
                <label class="form-label" for="password">Security Password</label>
                <div class="input-wrapper">
                    <input type="password" id="password" name="password" class="form-input" 
                           placeholder="Enter your account password" required>
                    <button type="button" class="toggle-password" onclick="togglePasswordVisibility()">Show</button>
                </div>
            </div>

            <button type="submit" class="btn-submit">Sign In to Workspace</button>
        </form>

        <div class="auth-footer">
            Don't have an enterprise account? 
            <a href="<%= request.getContextPath() %>/register">Register New Account</a>
        </div>
    </div>

    <!-- Right: Enterprise Feature Showcase -->
    <div class="auth-showcase-side">
        <div class="showcase-content">
            <h2>Next-Generation Workforce Attendance & Leaves</h2>
            <p>A unified management portal designed with precise punch policies, smart breaks, and real-time administrative auditing.</p>

            <ul class="feature-list">
                <li class="feature-item">
                    <span class="check-badge">✔</span>
                    Strict 09:45 AM policy & automatic 6:15 PM shift closure
                </li>
                <li class="feature-item">
                    <span class="check-badge">✔</span>
                    Smart 2-break allowance with real-time overage alarms
                </li>
                <li class="feature-item">
                    <span class="check-badge">✔</span>
                    Integrated HR leave approvals with rejection feedback
                </li>
            </ul>
        </div>

        <div class="showcase-badge">
            <span>Shift Guard Status</span>
            <span style="color: var(--emerald); font-weight: 700;">● Policy Active</span>
        </div>
    </div>
</div>

<script>
    function togglePasswordVisibility() {
        const passInput = document.getElementById("password");
        const toggleBtn = document.querySelector(".toggle-password");
        if (passInput.type === "password") {
            passInput.type = "text";
            toggleBtn.textContent = "Hide";
        } else {
            passInput.type = "password";
            toggleBtn.textContent = "Show";
        }
    }
</script>

</body>
</html>