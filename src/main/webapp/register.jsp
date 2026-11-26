<%@ page contentType="text/html;charset=UTF-8" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Employee Registration | EMS Enterprise</title>
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
            grid-template-columns: 1.2fr 1fr;
            box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
            overflow: hidden;
            border: 1px solid rgba(255, 255, 255, 0.1);
        }

        .auth-form-side {
            padding: 44px 44px;
            display: flex;
            flex-direction: column;
            justify-content: center;
        }

        .brand-header {
            margin-bottom: 22px;
        }

        .brand-icon {
            width: 40px;
            height: 40px;
            background: var(--brand-gradient);
            border-radius: 12px;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            color: #ffffff;
            font-weight: 800;
            font-size: 20px;
            box-shadow: 0 4px 12px rgba(37, 99, 235, 0.3);
            margin-bottom: 12px;
        }

        .brand-header h1 {
            font-size: 22px;
            font-weight: 800;
            letter-spacing: -0.02em;
            color: var(--text-primary);
        }

        .brand-header p {
            font-size: 13px;
            color: var(--text-secondary);
            margin-top: 3px;
        }

        .alert-box {
            padding: 12px 16px;
            border-radius: 10px;
            font-size: 13px;
            font-weight: 600;
            display: flex;
            align-items: center;
            gap: 10px;
            margin-bottom: 16px;
        }
        .alert-error { background: var(--rose-surface); border: 1px solid #fecdd3; color: #9f1239; }

        .form-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 14px;
        }

        .form-group {
            margin-bottom: 14px;
        }

        .form-group.full-width {
            grid-column: span 2;
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

        .form-input {
            width: 100%;
            height: 44px;
            border: 1px solid var(--border-subtle);
            border-radius: 10px;
            padding: 0 14px;
            font-size: 13px;
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
            margin-top: 6px;
            box-shadow: 0 4px 12px rgba(37, 99, 235, 0.25);
            transition: all 0.2s ease;
        }

        .btn-submit:hover {
            transform: translateY(-1.5px);
            box-shadow: 0 6px 16px rgba(37, 99, 235, 0.35);
        }

        .auth-footer {
            margin-top: 20px;
            padding-top: 16px;
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

        /* Right Side: Feature Presentation */
        .auth-showcase-side {
            background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
            padding: 44px 38px;
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
            margin-top: 24px;
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

        @media (max-width: 860px) {
            .auth-container { grid-template-columns: 1fr; max-width: 480px; }
            .auth-showcase-side { display: none; }
            .auth-form-side { padding: 34px 26px; }
            .form-grid { grid-template-columns: 1fr; }
            .form-group.full-width { grid-column: span 1; }
        }
    </style>
</head>
<body>

<div class="auth-container">
    <div class="auth-form-side">
        <div class="brand-header">
            <div class="brand-icon">E</div>
            <h1>Create Account</h1>
            <p>Enroll as an employee to track shifts and submit leaves</p>
        </div>

        <% if (request.getAttribute("error") != null) { %>
            <div class="alert-box alert-error">
                <span>&#9888;</span>
                <div><%= request.getAttribute("error") %></div>
            </div>
        <% } %>

        <form id="regForm" action="<%= request.getContextPath() %>/register" method="post" autocomplete="off">
            <div class="form-grid">
                <div class="form-group full-width">
                    <label class="form-label">Full Name</label>
                    <input type="text" name="name" class="form-input" placeholder="e.g. Rahul Sharma" required autofocus>
                </div>

                <div class="form-group">
                    <label class="form-label">Mobile Number</label>
                    <input type="tel" name="mobile" class="form-input" placeholder="e.g. 9876543210" required>
                </div>

                <div class="form-group">
                    <label class="form-label">Email Address</label>
                    <input type="email" name="email" class="form-input" placeholder="name@company.com" required>
                </div>

                <div class="form-group">
                    <label class="form-label">Password</label>
                    <input type="password" id="password" name="password" class="form-input" placeholder="Min. 6 characters" required>
                </div>

                <div class="form-group">
                    <label class="form-label">Confirm Password</label>
                    <input type="password" id="confirmPassword" name="confirmPassword" class="form-input" placeholder="Re-enter password" required>
                </div>
            </div>

            <button type="submit" class="btn-submit">Generate Employee ID & Register</button>
        </form>

        <div class="auth-footer">
            Already have an enterprise ID? 
            <a href="<%= request.getContextPath() %>/login">Sign In</a>
        </div>
    </div>

    <div class="auth-showcase-side">
        <div class="showcase-content">
            <h2>Automated ID Generation & Shift Security</h2>
            <p>Once registered, our database assigns your sequential Employee ID. You can sign in using either that ID or your registered email address.</p>

            <ul class="feature-list">
                <li class="feature-item">
                    <span class="check-badge">&#10004;</span>
                    Automated sequential EMP ID allocation
                </li>
                <li class="feature-item">
                    <span class="check-badge">&#10004;</span>
                    Dual credential sign-in (ID or Work Email)
                </li>
                <li class="feature-item">
                    <span class="check-badge">&#10004;</span>
                    Zero-hassle attendance and smart break tracking
                </li>
            </ul>
        </div>

        <div class="showcase-badge">
            <span>Registration Node</span>
            <span style="color: var(--emerald); font-weight: 700;">&#9679; Online</span>
        </div>
    </div>
</div>

<script>
    document.getElementById("regForm").addEventListener("submit", function(e) {
        const pass = document.getElementById("password").value;
        const confirm = document.getElementById("confirmPassword").value;
        if (pass !== confirm) {
            e.preventDefault();
            alert("Passwords do not match. Please ensure both fields match exactly.");
        }
    });
</script>

</body>
</html>