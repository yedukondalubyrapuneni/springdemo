<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="com.example.demo.model.Employee" %>
<%
    Employee loggedIn = (Employee) session.getAttribute("loggedInEmployee");
    if (loggedIn == null) {
        response.sendRedirect(request.getContextPath() + "/login.jsp");
        return;
    }

    String role = (loggedIn.getRole() != null) ? loggedIn.getRole().trim().toUpperCase() : "";
    boolean isHr = "HR".equals(role) || loggedIn.isHrDesignation();
    if (!isHr) {
        response.sendRedirect(request.getContextPath() + "/dashboard.jsp?error=Access+Denied:+HR+Only");
        return;
    }

    String msg = request.getParameter("msg");
    String err = request.getParameter("error");
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Compensation Architecture &amp; Baseline Configuration | Speshway HRMS</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@500;600;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --primary: #2563eb;
            --primary-dark: #1d4ed8;
            --primary-light: #eff6ff;
            --secondary: #0f172a;
            --slate-50: #f8fafc;
            --slate-100: #f1f5f9;
            --slate-200: #e2e8f0;
            --slate-300: #cbd5e1;
            --slate-400: #94a3b8;
            --slate-500: #64748b;
            --slate-700: #334155;
            --slate-900: #0f172a;
            --emerald-500: #10b981;
            --emerald-50: #ecfdf5;
            --rose-500: #ef4444;
            --rose-50: #fef2f2;
            --amber-500: #f59e0b;
            --radius-md: 10px;
            --radius-lg: 16px;
            --shadow-subtle: 0 4px 20px -2px rgba(15, 23, 42, 0.05);
            --shadow-card: 0 10px 25px -5px rgba(15, 23, 42, 0.06), 0 8px 10px -6px rgba(15, 23, 42, 0.04);
        }

        * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Plus Jakarta Sans', sans-serif; }
        body { background-color: #f1f5f9; color: var(--slate-900); padding: 40px 20px; line-height: 1.5; }
        .container { max-width: 1080px; margin: 0 auto; }

        /* Navigation Header */
        .page-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 24px;
        }
        .header-title-block h1 {
            font-size: 24px;
            font-weight: 800;
            letter-spacing: -0.02em;
            color: var(--slate-900);
        }
        .header-title-block p {
            font-size: 13.5px;
            color: var(--slate-500);
            margin-top: 4px;
        }
        .header-actions { display: flex; gap: 10px; }

        .btn {
            font-family: inherit;
            font-size: 13px;
            font-weight: 700;
            padding: 10px 18px;
            border-radius: var(--radius-md);
            cursor: pointer;
            text-decoration: none;
            display: inline-flex;
            align-items: center;
            gap: 8px;
            border: 1px solid transparent;
            transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
        }
        .btn-outline { background: #fff; border-color: var(--slate-300); color: var(--slate-700); }
        .btn-outline:hover { background: var(--slate-50); border-color: var(--slate-400); transform: translateY(-1px); }
        .btn-dark { background: var(--secondary); color: #fff; }
        .btn-dark:hover { background: #1e293b; box-shadow: 0 4px 12px rgba(15, 23, 42, 0.15); }

        /* Master Form Card */
        .glass-card {
            background: #ffffff;
            border: 1px solid rgba(226, 232, 240, 0.8);
            border-radius: var(--radius-lg);
            padding: 36px 40px;
            box-shadow: var(--shadow-card);
        }

        /* Hero Target Employee Row */
        .hero-search-box {
            background: linear-gradient(145deg, #f8fafc 0%, #f1f5f9 100%);
            border: 1.5px solid var(--slate-200);
            border-radius: var(--radius-md);
            padding: 24px;
            margin-bottom: 28px;
            display: flex;
            flex-direction: column;
            gap: 12px;
            position: relative;
        }
        .hero-search-label {
            font-size: 12px;
            font-weight: 800;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: var(--primary);
            display: flex;
            align-items: center;
            gap: 6px;
        }

        .input-hero-wrapper {
            position: relative;
            display: flex;
            align-items: center;
        }
        .input-hero-wrapper .search-icon {
            position: absolute;
            left: 16px;
            font-size: 16px;
            color: var(--slate-400);
            pointer-events: none;
        }
        .input-hero {
            width: 100%;
            height: 50px;
            background: #ffffff;
            border: 1.5px solid var(--slate-300);
            border-radius: var(--radius-md);
            padding: 0 16px 0 46px;
            font-size: 15px;
            font-weight: 700;
            color: var(--slate-900);
            outline: none;
            transition: all 0.2s ease;
        }
        .input-hero:focus {
            border-color: var(--primary);
            box-shadow: 0 0 0 4px rgba(37, 99, 235, 0.15);
        }

        .status-capsule {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            font-size: 12.5px;
            font-weight: 700;
            min-height: 20px;
        }

        /* Section Wrappers */
        .section-tag {
            font-size: 12px;
            font-weight: 800;
            text-transform: uppercase;
            letter-spacing: 0.06em;
            color: var(--slate-500);
            margin: 28px 0 14px;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        .section-tag::after { content: ""; flex: 1; height: 1px; background: var(--slate-200); }

        /* Grid Framework */
        .grid-4 { display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; }
        .grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
        .grid-split { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; margin-top: 14px; }

        .field-group { display: flex; flex-direction: column; gap: 6px; }
        .field-label {
            font-size: 11px;
            font-weight: 700;
            color: var(--slate-500);
            text-transform: uppercase;
            letter-spacing: 0.03em;
        }

        .input-base {
            height: 44px;
            border: 1px solid var(--slate-300);
            border-radius: 8px;
            padding: 0 14px;
            font-size: 13.5px;
            background: #fff;
            color: var(--slate-900);
            outline: none;
            transition: all 0.15s ease;
        }
        .input-base:focus {
            border-color: var(--primary);
            box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.1);
        }
        .input-base[readonly] {
            background: var(--slate-100);
            color: var(--slate-700);
            cursor: not-allowed;
            border-color: var(--slate-200);
        }

        .mono-val { font-family: 'JetBrains Mono', monospace; font-weight: 600; }

        /* Package Calculator Strip */
        .calc-strip {
            background: linear-gradient(145deg, #eff6ff 0%, #dbeafe 100%);
            border: 1.5px solid #bfdbfe;
            border-radius: var(--radius-md);
            padding: 22px;
            margin: 20px 0;
        }
        .calc-title {
            font-size: 13.5px;
            font-weight: 800;
            color: var(--primary-dark);
            margin-bottom: 14px;
            display: flex;
            align-items: center;
            gap: 6px;
        }

        /* Compensation Breakdown Columns */
        .breakdown-card {
            background: var(--slate-50);
            border: 1px solid var(--slate-200);
            border-radius: var(--radius-md);
            padding: 20px;
        }
        .breakdown-card-header {
            font-size: 13px;
            font-weight: 800;
            text-transform: uppercase;
            letter-spacing: 0.04em;
            margin-bottom: 16px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .header-earnings { color: var(--emerald-500); }
        .header-deductions { color: var(--rose-500); }

        /* Live Summary Banner */
        .live-summary-bar {
            background: var(--secondary);
            color: #fff;
            border-radius: var(--radius-md);
            padding: 20px 28px;
            margin-top: 28px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            box-shadow: 0 10px 20px -5px rgba(15, 23, 42, 0.2);
        }
        .metric-block { display: flex; flex-direction: column; }
        .metric-block .metric-lbl { font-size: 11px; text-transform: uppercase; color: var(--slate-400); font-weight: 700; letter-spacing: 0.05em; }
        .metric-block .metric-val { font-size: 20px; font-weight: 800; font-family: 'JetBrains Mono', monospace; }
        .metric-takehome { color: #34d399; }

        .btn-submit-master {
            height: 48px;
            padding: 0 32px;
            background: var(--primary);
            color: #fff;
            border: none;
            border-radius: 8px;
            font-size: 14px;
            font-weight: 800;
            cursor: pointer;
            transition: all 0.2s ease;
            box-shadow: 0 4px 12px rgba(37, 99, 235, 0.3);
        }
        .btn-submit-master:hover {
            background: var(--primary-dark);
            transform: translateY(-1px);
            box-shadow: 0 6px 16px rgba(37, 99, 235, 0.4);
        }

        .glow-success {
            animation: fieldGlow 0.9s ease;
        }
        @keyframes fieldGlow {
            0% { background-color: #ecfdf5; border-color: var(--emerald-500); }
            100% { background-color: #f1f5f9; border-color: var(--slate-200); }
        }

        .alert-toast { padding: 12px 18px; border-radius: 8px; font-size: 13px; font-weight: 700; margin-bottom: 20px; }
        .toast-success { background: var(--emerald-50); border: 1px solid #a7f3d0; color: #065f46; }
        .toast-error { background: var(--rose-50); border: 1px solid #fecaca; color: #991b1b; }

        @media (max-width: 860px) {
            .grid-4, .grid-split, .grid-2 { grid-template-columns: 1fr; }
            .live-summary-bar { flex-direction: column; gap: 16px; align-items: flex-start; }
            .btn-submit-master { width: 100%; }
        }
    </style>
</head>
<body>

<div class="container">
    <div class="page-header">
        <div class="header-title-block">
            <h1>Compensation Architecture &amp; Baseline</h1>
            <p>Configure employee packages once. The system automatically reconciles LOP and generates monthly payroll.</p>
        </div>
        <div class="header-actions">
            <button type="button" onclick="history.back()" class="btn btn-outline">&larr; Back</button>
            <a href="<%= request.getContextPath() %>/payroll/history" class="btn btn-dark">&#128203; Salary History</a>
        </div>
    </div>

    <% if (msg != null) { %><div class="alert-toast toast-success">&#10003; <%= msg %></div><% } %>
    <% if (err != null) { %><div class="alert-toast toast-error">&#9888; <%= err %></div><% } %>

    <div class="glass-card">
        <form method="post" action="<%= request.getContextPath() %>/payroll/salary-structure">
            
            <!-- Hero Auto-Fetching Input Row -->
            <div class="hero-search-box">
                <label class="hero-search-label">&#9889; Quick Employee Identity Resolver</label>
                <div class="input-hero-wrapper">
                    <span class="search-icon">&#128100;</span>
                    <input type="text" id="employeeIdInput" name="employeeId" class="input-hero" 
                           placeholder="Type Employee ID (e.g. EMP101, 9147, ADMIN01)..." 
                           oninput="handleEmpIdInput(this.value)" 
                           autocomplete="off" 
                           required>
                </div>
                <div id="fetchStatus" class="status-capsule"></div>
            </div>

            <!-- Auto-populated Profile Row -->
            <div class="section-tag">Identity Profile (Automated Metadata)</div>
            <div class="grid-4">
                <div class="field-group">
                    <label class="field-label">Employee Name</label>
                    <input type="text" id="employeeName" class="input-base" readonly placeholder="Auto-populated">
                </div>
                <div class="field-group">
                    <label class="field-label">Assigned Department</label>
                    <input type="text" id="department" class="input-base" readonly placeholder="Auto-populated">
                </div>
                <div class="field-group">
                    <label class="field-label">Designation / Role</label>
                    <input type="text" id="designation" class="input-base" readonly placeholder="Auto-populated">
                </div>
                <div class="field-group">
                    <label class="field-label">Joining Date</label>
                    <input type="text" id="joiningDate" class="input-base" readonly placeholder="Auto-populated">
                </div>
            </div>

            <!-- Bank Disbursement Details -->
            <div class="section-tag">Disbursement Accounts (HR Configured)</div>
            <div class="grid-2">
                <div class="field-group">
                    <label class="field-label">Disbursement Bank Name</label>
                    <input type="text" id="bankName" name="bankName" class="input-base" placeholder="e.g. HDFC Bank, State Bank of India, ICICI" required>
                </div>
                <div class="field-group">
                    <label class="field-label">Bank Account Number</label>
                    <input type="text" id="bankAccount" name="bankAccount" class="input-base mono-val" placeholder="e.g. 50100870325198" required>
                </div>
            </div>

            <!-- Interactive Package Input Calculator -->
            <div class="calc-strip">
                <div class="calc-title">
                    &#128176; Package Architect (Enter Annual CTC or Monthly Gross)
                </div>
                <div class="grid-2">
                    <div class="field-group">
                        <label class="field-label" style="color: var(--primary);">Annual CTC Package (INR)</label>
                        <input type="number" step="1" id="annualCtc" class="input-base mono-val" placeholder="e.g. 480000" oninput="calculateFromAnnual(this.value)">
                    </div>
                    <div class="field-group">
                        <label class="field-label" style="color: var(--primary);">Monthly Gross Baseline (INR)</label>
                        <input type="number" step="0.01" id="monthlyGross" class="input-base mono-val" placeholder="e.g. 40000" oninput="calculateFromMonthly(this.value)">
                    </div>
                </div>
                <p style="font-size: 11.5px; color: var(--slate-500); margin-top: 10px;">
                    * Proportional Standard Split: Basic (37.15%) | DA (55% of Basic) | HRA (50% of Basic) | Conveyance (₹1,600) | Medical (₹1,250) | Special Allowance (Balance) | PT (₹200) | PF (Standard ₹3,600 or 12%)[cite: 1].
                </p>
            </div>

            <!-- Two-Column Breakdown (Earnings vs Deductions) -->
            <div class="grid-split">
                
                <!-- Earnings Column -->
                <div class="breakdown-card">
                    <div class="breakdown-card-header header-earnings">
                        <span>Earnings Components</span>
                        <span style="font-size: 11px; background: #ecfdf5; padding: 2px 8px; border-radius: 4px;">Credit</span>
                    </div>
                    <div style="display: flex; flex-direction: column; gap: 12px;">
                        <div class="field-group">
                            <label class="field-label">Basic Pay (37.15% Gross)</label>
                            <input type="number" step="0.01" name="basic" id="basic" class="input-base mono-val" oninput="updateLiveBar()" required>
                        </div>
                        <div class="field-group">
                            <label class="field-label">Dearness Allowance (55% Basic)</label>
                            <input type="number" step="0.01" name="da" id="da" class="input-base mono-val" oninput="updateLiveBar()">
                        </div>
                        <div class="field-group">
                            <label class="field-label">House Rent Allowance (50% Basic)</label>
                            <input type="number" step="0.01" name="hra" id="hra" class="input-base mono-val" oninput="updateLiveBar()">
                        </div>
                        <div class="field-group">
                            <label class="field-label">Conveyance Allowance (Fixed)</label>
                            <input type="number" step="0.01" name="conveyance" id="conveyance" class="input-base mono-val" value="1600" oninput="updateLiveBar()">
                        </div>
                        <div class="field-group">
                            <label class="field-label">Medical Allowance (Fixed)</label>
                            <input type="number" step="0.01" name="medical" id="medical" class="input-base mono-val" value="1250" oninput="updateLiveBar()">
                        </div>
                        <div class="field-group">
                            <label class="field-label">Special Allowance (Residual)</label>
                            <input type="number" step="0.01" name="special" id="special" class="input-base mono-val" oninput="updateLiveBar()">
                        </div>
                    </div>
                </div>

                <!-- Deductions Column -->
                <div class="breakdown-card">
                    <div class="breakdown-card-header header-deductions">
                        <span>Statutory Deductions</span>
                        <span style="font-size: 11px; background: #fef2f2; padding: 2px 8px; border-radius: 4px;">Debit</span>
                    </div>
                    <div style="display: flex; flex-direction: column; gap: 12px;">
                        <div class="field-group">
                            <label class="field-label">Professional Tax (Fixed)</label>
                            <input type="number" step="0.01" name="profTax" id="profTax" class="input-base mono-val" value="200" oninput="updateLiveBar()">
                        </div>
                        <div class="field-group">
                            <label class="field-label">Provident Fund (PF)</label>
                            <input type="number" step="0.01" name="pf" id="pf" class="input-base mono-val" value="3600" oninput="updateLiveBar()">
                        </div>
                        
                        <div style="margin-top: 14px; padding: 14px; background: #ffffff; border: 1px dashed var(--slate-300); border-radius: 8px;">
                            <div style="font-size: 11.5px; font-weight: 700; color: var(--slate-700); margin-bottom: 4px;">Automated LOP Notice</div>
                            <div style="font-size: 11px; color: var(--slate-500);">
                                Loss of Pay (LOP) deductions are evaluated automatically during the monthly cycle via attendance &amp; approved leave rosters.
                            </div>
                        </div>
                    </div>
                </div>

            </div>

            <!-- Real-Time Calculation Summary Banner -->
            <div class="live-summary-bar">
                <div class="metric-block">
                    <span class="metric-lbl">Total Monthly Gross</span>
                    <span class="metric-val" id="summaryGross">₹ 0.00</span>
                </div>
                <div class="metric-block">
                    <span class="metric-lbl">Total Deductions</span>
                    <span class="metric-val" style="color: #f87171;" id="summaryDeductions">₹ 0.00</span>
                </div>
                <div class="metric-block">
                    <span class="metric-lbl">Net Estimated Take-Home</span>
                    <span class="metric-val metric-takehome" id="summaryNet">₹ 0.00</span>
                </div>
                <button type="submit" class="btn-submit-master">
                    Commit Structure &amp; Bank Details &rarr;
                </button>
            </div>

        </form>
    </div>
</div>

<script>
let debounceTimer;

function handleEmpIdInput(val) {
    clearTimeout(debounceTimer);
    const cleanId = val.trim();

    if (!cleanId) {
        clearEmployeeFields();
        return;
    }

    const statusDiv = document.getElementById('fetchStatus');
    statusDiv.innerHTML = '<span style="color: var(--primary);">&#9203; Identifying record...</span>';

    debounceTimer = setTimeout(() => {
        executeAutoFetch(cleanId);
    }, 320);
}

function executeAutoFetch(empId) {
    const statusDiv = document.getElementById('fetchStatus');

    fetch('<%= request.getContextPath() %>/api/employee-details?empId=' + encodeURIComponent(empId))
        .then(response => {
            if (!response.ok) throw new Error('Network error');
            return response.json();
        })
        .then(data => {
            if (data && data.empId) {
                applyGlow('employeeName', data.name || '');
                applyGlow('department', data.department || '-');
                applyGlow('designation', data.designation || '-');
                applyGlow('joiningDate', data.joiningDate || '-');

                if (data.bankName && data.bankName !== '-') {
                    applyGlow('bankName', data.bankName);
                }
                if (data.bankAccount && data.bankAccount !== '-') {
                    applyGlow('bankAccount', data.bankAccount);
                }

                statusDiv.innerHTML = '<span style="color: #059669;">&#10003; Verified Profile: ' + data.name + ' (' + data.department + ')</span>';
            } else {
                clearEmployeeFields();
                statusDiv.innerHTML = '<span style="color: #ef4444;">&#9888; Record not found with ID "' + empId + '"</span>';
            }
        })
        .catch(err => {
            console.error('Auto-fetch error:', err);
            statusDiv.innerHTML = '<span style="color: #ef4444;">Error communicating with server</span>';
        });
}

function applyGlow(fieldId, val) {
    const el = document.getElementById(fieldId);
    if (el) {
        el.value = val;
        el.classList.add('glow-success');
        setTimeout(() => el.classList.remove('glow-success'), 900);
    }
}

function clearEmployeeFields() {
    document.getElementById('employeeName').value = '';
    document.getElementById('department').value = '';
    document.getElementById('designation').value = '';
    document.getElementById('joiningDate').value = '';
    document.getElementById('fetchStatus').innerHTML = '';
}

function calculateFromAnnual(annualVal) {
    if (!annualVal || parseFloat(annualVal) <= 0) return;
    const gross = (parseFloat(annualVal) / 12).toFixed(2);
    document.getElementById('monthlyGross').value = gross;
    applyPercentages(parseFloat(gross));
}

function calculateFromMonthly(monthlyVal) {
    if (!monthlyVal || parseFloat(monthlyVal) <= 0) return;
    const gross = parseFloat(monthlyVal);
    document.getElementById('annualCtc').value = Math.round(gross * 12);
    applyPercentages(gross);
}

function applyPercentages(gross) {
    const basic = Math.round(gross * 0.3715);
    document.getElementById('basic').value = basic;

    const da = Math.round(basic * 0.55);
    document.getElementById('da').value = da;

    const hra = Math.round(basic * 0.50);
    document.getElementById('hra').value = hra;

    const conveyance = 1600;
    const medical = 1250;
    document.getElementById('conveyance').value = conveyance;
    document.getElementById('medical').value = medical;

    const sumFixed = basic + da + hra + conveyance + medical;
    let special = Math.round(gross - sumFixed);
    if (special < 0) special = 0;
    document.getElementById('special').value = special;

    document.getElementById('profTax').value = 200;
    if (gross >= 40000) {
        document.getElementById('pf').value = 3600;
    } else {
        document.getElementById('pf').value = Math.round(basic * 0.12);
    }

    updateLiveBar();
}

function updateLiveBar() {
    const b = parseFloat(document.getElementById('basic').value) || 0;
    const d = parseFloat(document.getElementById('da').value) || 0;
    const h = parseFloat(document.getElementById('hra').value) || 0;
    const c = parseFloat(document.getElementById('conveyance').value) || 0;
    const m = parseFloat(document.getElementById('medical').value) || 0;
    const s = parseFloat(document.getElementById('special').value) || 0;

    const pt = parseFloat(document.getElementById('profTax').value) || 0;
    const pf = parseFloat(document.getElementById('pf').value) || 0;

    const totalGross = b + d + h + c + m + s;
    const totalDeductions = pt + pf;
    const netTakeHome = Math.max(0, totalGross - totalDeductions);

    document.getElementById('summaryGross').innerText = '₹ ' + totalGross.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    document.getElementById('summaryDeductions').innerText = '₹ ' + totalDeductions.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    document.getElementById('summaryNet').innerText = '₹ ' + netTakeHome.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}
</script>

</body>
</html>