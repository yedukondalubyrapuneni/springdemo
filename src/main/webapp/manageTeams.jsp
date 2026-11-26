<%@ page contentType="text/html;charset=UTF-8" %>
<%@ page import="com.example.demo.model.Employee, com.dao.ReportDAO" %>
<%@ page import="java.util.List, java.util.Map, java.util.Set, java.util.TreeSet" %>
<%
    Employee loggedIn = (Employee) session.getAttribute("loggedInEmployee");
    if (loggedIn == null) {
        response.sendRedirect(request.getContextPath() + "/login.jsp");
        return;
    }

    ReportDAO reportDao = new ReportDAO();
    List<Map<String, Object>> teams = reportDao.getFullTeamsCatalog();

    Set<String> departments = new TreeSet<>();
    Set<String> managers = new TreeSet<>();
    Set<String> statuses = new TreeSet<>();

    if (teams != null) {
        for (Map<String, Object> t : teams) {
            if (t.get("department") != null) departments.add((String) t.get("department"));
            if (t.get("manager_name") != null && !"Unassigned".equals(t.get("manager_name"))) {
                managers.add((String) t.get("manager_name"));
            }
            if (t.get("status") != null) statuses.add((String) t.get("status"));
        }
    }
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Search & Filter Teams | EMS Enterprise</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        :root {
            --brand-primary: #2563eb;
            --brand-hover: #1d4ed8;
            --surface-bg: #f8fafc;
            --border-subtle: #e2e8f0;
            --text-main: #0f172a;
            --text-muted: #64748b;
        }

        * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Plus Jakarta Sans', sans-serif; }
        body { background: var(--surface-bg); color: var(--text-main); padding: 36px 32px; -webkit-font-smoothing: antialiased; }
        .container { max-width: 1300px; margin: 0 auto; display: flex; flex-direction: column; gap: 24px; }

        .page-header { display: flex; justify-content: space-between; align-items: center; }
        .page-title { font-size: 24px; font-weight: 800; color: #0f172a; letter-spacing: -0.3px; }
        .header-actions { display: flex; align-items: center; gap: 10px; }
        .btn-header { height: 38px; padding: 0 18px; border-radius: 8px; font-size: 13px; font-weight: 700; text-decoration: none; display: inline-flex; align-items: center; justify-content: center; transition: all 0.15s ease; border: none; cursor: pointer; }
        .btn-header-back { background: #334155; color: #fff; }
        .btn-header-back:hover { background: #1e293b; }
        .btn-header-create { background: var(--brand-primary); color: #fff; }
        .btn-header-create:hover { background: var(--brand-hover); }
        .btn-header-analytics { background: #0f172a; color: #fff; }
        .btn-header-analytics:hover { background: #020617; }

        .card-filter { background: #fff; border: 1px solid var(--border-subtle); border-radius: 14px; padding: 22px 24px; box-shadow: 0 1px 3px rgba(0,0,0,0.02); }
        .filter-row { display: grid; grid-template-columns: 2.2fr 1.6fr 1.4fr 1.6fr auto; gap: 14px; align-items: flex-end; }
        .filter-col { display: flex; flex-direction: column; gap: 6px; }
        .filter-label { font-size: 11px; font-weight: 800; text-transform: uppercase; color: var(--text-muted); letter-spacing: 0.3px; }
        .filter-input { height: 42px; border: 1px solid var(--border-subtle); border-radius: 8px; padding: 0 14px; font-size: 13px; outline: none; background: #fff; width: 100%; transition: border-color 0.15s ease; }
        .filter-input:focus { border-color: var(--brand-primary); }
        .btn-filter { height: 42px; background: var(--brand-primary); color: #fff; border: none; padding: 0 24px; border-radius: 8px; font-weight: 700; font-size: 13px; cursor: pointer; transition: background 0.15s ease; }
        .btn-filter:hover { background: var(--brand-hover); }

        .card-table { background: #fff; border: 1px solid var(--border-subtle); border-radius: 14px; padding: 8px 24px 20px 24px; box-shadow: 0 1px 3px rgba(0,0,0,0.02); }
        table { width: 100%; border-collapse: collapse; font-size: 13px; }
        th { text-align: left; padding: 16px 12px; color: var(--text-muted); font-size: 11px; font-weight: 800; text-transform: uppercase; border-bottom: 1px solid var(--border-subtle); letter-spacing: 0.3px; }
        td { padding: 18px 12px; border-bottom: 1px solid #f1f5f9; vertical-align: middle; }

        .team-id-badge { font-weight: 800; color: #0f172a; }
        .status-dot { color: #10b981; font-weight: 800; font-size: 12px; display: inline-flex; align-items: center; gap: 4px; }
        .status-dot.inactive { color: #ef4444; }

        .actions-group { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
        .btn-act { padding: 6px 12px; border-radius: 6px; font-size: 12px; font-weight: 700; text-decoration: none; display: inline-flex; align-items: center; transition: all 0.15s ease; border: none; cursor: pointer; }
        .btn-act-roster { background: #eff6ff; color: #2563eb; }
        .btn-act-roster:hover { background: #dbeafe; }
        .btn-act-add { background: #ecfdf5; color: #059669; }
        .btn-act-add:hover { background: #d1fae5; }
        .btn-act-edit { background: #fefce8; color: #b45309; }
        .btn-act-edit:hover { background: #fef9c3; }
        .btn-act-del { background: #fef2f2; color: #dc2626; }
        .btn-act-del:hover { background: #fee2e2; }
    </style>
</head>
<body>

<div class="container">

    <div class="page-header">
        <h1 class="page-title">Enterprise Teams Catalog</h1>
        <div class="header-actions">
            <a href="<%= request.getContextPath() %>/dashboard.jsp" class="btn-header btn-header-back">&larr; Back to Dashboard</a>
            <a href="<%= request.getContextPath() %>/createTeam.jsp" class="btn-header btn-header-create">+ Create Team</a>
            <a href="<%= request.getContextPath() %>/teams/dashboard" class="btn-header btn-header-analytics">Analytics Dashboard</a>
        </div>
    </div>

    <div class="card-filter">
        <div class="filter-row">
            <div class="filter-col">
                <label class="filter-label">Search Term</label>
                <input type="text" id="searchTerm" onkeyup="filterTeams()" class="filter-input" placeholder="Search by ID, Name or Manager...">
            </div>

            <div class="filter-col">
                <label class="filter-label">Department</label>
                <select id="filterDept" onchange="filterTeams()" class="filter-input">
                    <option value="ALL">All Departments</option>
                    <% for (String dept : departments) { %>
                        <option value="<%= dept.toLowerCase() %>"><%= dept %></option>
                    <% } %>
                </select>
            </div>

            <div class="filter-col">
                <label class="filter-label">Status</label>
                <select id="filterStatus" onchange="filterTeams()" class="filter-input">
                    <option value="ALL">All Statuses</option>
                    <option value="ACTIVE">Active</option>
                    <option value="INACTIVE">Inactive</option>
                </select>
            </div>

            <div class="filter-col">
                <label class="filter-label">Manager</label>
                <select id="filterMgr" onchange="filterTeams()" class="filter-input">
                    <option value="ALL">All Managers</option>
                    <% for (String mgr : managers) { %>
                        <option value="<%= mgr.toLowerCase() %>"><%= mgr %></option>
                    <% } %>
                </select>
            </div>

            <button type="button" class="btn-filter" onclick="filterTeams()">Filter</button>
        </div>
    </div>

    <div class="card-table">
        <table>
            <thead>
                <tr>
                    <th style="width: 14%;">Team ID</th>
                    <th style="width: 18%;">Team Name</th>
                    <th style="width: 15%;">Department</th>
                    <th style="width: 18%;">Manager</th>
                    <th style="width: 12%;">Status</th>
                    <th style="width: 23%;">Actions</th>
                </tr>
            </thead>
            <tbody id="teamsTbody">
                <% if (teams != null && !teams.isEmpty()) { 
                    for (Map<String, Object> t : teams) { 
                        int rawId = (Integer) t.get("id");
                        String formattedId = String.format("TEAM%03d", rawId);
                        String tName = (String) t.get("team_name");
                        String dept = (String) t.get("department");
                        String mgr = (String) t.get("manager_name");
                        String st = (String) t.get("status");
                        boolean isActive = "ACTIVE".equalsIgnoreCase(st);
                %>
                        <tr class="team-row" 
                            data-search="<%= (formattedId + " " + tName + " " + mgr).toLowerCase() %>"
                            data-dept="<%= dept != null ? dept.toLowerCase() : "" %>"
                            data-status="<%= st != null ? st.toUpperCase() : "ACTIVE" %>"
                            data-mgr="<%= mgr != null ? mgr.toLowerCase() : "" %>">
                            <td class="team-id-badge"><%= formattedId %></td>
                            <td><strong><%= tName %></strong></td>
                            <td><%= (dept != null ? dept : "IT") %></td>
                            <td><%= (mgr != null ? mgr : "Unassigned") %></td>
                            <td>
                                <span class="status-dot <%= isActive ? "" : "inactive" %>">
                                    &bull; <%= isActive ? "ACTIVE" : "INACTIVE" %>
                                </span>
                            </td>
                            <td>
                                <div class="actions-group">
                                    <a href="<%= request.getContextPath() %>/teams/view?id=<%= rawId %>" class="btn-act btn-act-roster">View Roster</a>
            
                                    <a href="<%= request.getContextPath() %>/teams/edit?id=<%= rawId %>" class="btn-act btn-act-edit">Edit</a>
                                    <a href="<%= request.getContextPath() %>/teams/delete?id=<%= rawId %>" class="btn-act btn-act-del" onclick="return confirm('Are you sure you want to delete <%= tName %>?');">Delete</a>
                                </div>
                            </td>
                        </tr>
                <%  } 
                   } else { %>
                    <tr><td colspan="6" style="text-align: center; color: var(--text-muted); padding: 32px;">No teams found.</td></tr>
                <% } %>
            </tbody>
        </table>
    </div>

</div>

<script>
function filterTeams() {
    var search = document.getElementById('searchTerm').value.toLowerCase().trim();
    var dept = document.getElementById('filterDept').value.toLowerCase().trim();
    var status = document.getElementById('filterStatus').value.toUpperCase().trim();
    var mgr = document.getElementById('filterMgr').value.toLowerCase().trim();

    var rows = document.querySelectorAll('.team-row');
    rows.forEach(function(row) {
        var rowSearch = row.getAttribute('data-search');
        var rowDept = row.getAttribute('data-dept');
        var rowStatus = row.getAttribute('data-status');
        var rowMgr = row.getAttribute('data-mgr');

        var mSearch = (search === '') || rowSearch.includes(search);
        var mDept = (dept === 'all') || (rowDept === dept);
        var mStatus = (status === 'ALL') || (rowStatus === status);
        var mMgr = (mgr === 'all') || (rowMgr === mgr);

        if (mSearch && mDept && mStatus && mMgr) {
            row.style.display = '';
        } else {
            row.style.display = 'none';
        }
    });
}
</script>

</body>
</html>