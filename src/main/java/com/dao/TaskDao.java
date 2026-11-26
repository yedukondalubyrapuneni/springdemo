package com.dao;

import com.model.Task;
import com.Util.DBConnection;

import java.sql.*;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

public class TaskDao {

    // 1. Create Task (Fixes EMP101 & MGR02 saving as "0" and saves team_id)
    public boolean createTask(Task task) {
        String sql = "INSERT INTO tasks (title, description, task_file_path, assigned_to, assigned_by, " +
                     "priority, start_date, due_date, status, team_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {

            // Title
            String title = (task.getTaskTitle() != null && !task.getTaskTitle().isBlank()) 
                           ? task.getTaskTitle() : task.getTitle();
            ps.setString(1, title);
            ps.setString(2, task.getDescription());
            ps.setString(3, task.getTaskFilePath());

            // Read the String employee ID ("EMP101"), NOT the int getter (which is 0)
            String empId = task.getAssignedToName();
            if (empId == null || empId.isBlank() || "0".equals(empId)) {
                empId = task.getAssignedTo() != null ? String.valueOf(task.getAssignedTo()) : "";
            }
            ps.setString(4, empId != null ? empId.trim() : "");

            // Read the String manager ID ("MGR02"), NOT the int getter
            String mgrId = task.getCreatedByName();
            if (mgrId == null || mgrId.isBlank() || "0".equals(mgrId)) {
                mgrId = task.getAssignedBy() != null ? task.getAssignedBy() : String.valueOf(task.getCreatedBy());
            }
            ps.setString(5, mgrId != null ? mgrId.trim() : "");

            ps.setString(6, task.getPriority() != null ? task.getPriority() : "MEDIUM");
            ps.setDate(7, task.getStartDate() != null ? Date.valueOf(task.getStartDate()) : Date.valueOf(LocalDate.now()));

            if (task.getDueDate() != null) {
                ps.setDate(8, Date.valueOf(task.getDueDate()));
            } else {
                ps.setNull(8, Types.DATE);
            }

            ps.setString(9, task.getStatus() != null && !task.getStatus().isBlank() ? task.getStatus() : "ASSIGNED");
            
            // Save team_id so manager dashboard query finds it immediately
            if (task.getTeamId() > 0) {
                ps.setInt(10, task.getTeamId());
            } else {
                ps.setNull(10, Types.INTEGER);
            }

            return ps.executeUpdate() > 0;
        } catch (SQLException e) {
            System.err.println("Error creating task: " + e.getMessage());
            e.printStackTrace();
            return false;
        }
    }

    // 2. Assign individual task with optional briefing attachment
    public void assignTaskToEmployeeWithFile(String title, String description, String taskFilePath, 
                                           String employeeId, String managerId, LocalDate startDate, LocalDate dueDate) {
        String sql = "INSERT INTO tasks (title, description, task_file_path, assigned_to, assigned_by, start_date, due_date, status, priority) " +
                     "VALUES (?, ?, ?, ?, ?, ?, ?, 'ASSIGNED', 'MEDIUM')";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, title);
            ps.setString(2, description);
            ps.setString(3, taskFilePath);
            ps.setString(4, employeeId != null ? employeeId.trim() : "");
            ps.setString(5, managerId != null ? managerId.trim() : "");
            ps.setDate(6, startDate != null ? Date.valueOf(startDate) : Date.valueOf(LocalDate.now()));
            if (dueDate != null) {
                ps.setDate(7, Date.valueOf(dueDate));
            } else {
                ps.setNull(7, Types.DATE);
            }
            ps.executeUpdate();
        } catch (SQLException e) {
            System.err.println("Error assigning task with file: " + e.getMessage());
            e.printStackTrace();
        }
    }

    // 3. Assign task to multiple selected employees
    public void assignTaskToMultipleEmployees(String title, String description, String taskFilePath,
                                              String[] employeeIds, String managerId, LocalDate startDate, LocalDate dueDate, String priority) {
        if (employeeIds == null || employeeIds.length == 0) return;
        String sql = "INSERT INTO tasks (title, description, task_file_path, assigned_to, assigned_by, start_date, due_date, status, priority) " +
                     "VALUES (?, ?, ?, ?, ?, ?, ?, 'ASSIGNED', ?)";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            for (String empId : employeeIds) {
                ps.setString(1, title);
                ps.setString(2, description);
                ps.setString(3, taskFilePath);
                ps.setString(4, empId.trim());
                ps.setString(5, managerId != null ? managerId.trim() : "");
                ps.setDate(6, startDate != null ? Date.valueOf(startDate) : Date.valueOf(LocalDate.now()));
                if (dueDate != null) {
                    ps.setDate(7, Date.valueOf(dueDate));
                } else {
                    ps.setNull(7, Types.DATE);
                }
                ps.setString(8, priority != null ? priority : "MEDIUM");
                ps.addBatch();
            }
            ps.executeBatch();
        } catch (SQLException e) {
            System.err.println("Error assigning task to multiple employees: " + e.getMessage());
            e.printStackTrace();
        }
    }

    // 4. Assign task to entire team
    public void assignTaskToEntireTeamWithFile(String title, String description, String taskFilePath, 
                                               int teamId, String managerId, LocalDate startDate, LocalDate dueDate) {
        String sql = "INSERT INTO tasks (title, description, task_file_path, assigned_to, assigned_by, start_date, due_date, status, team_id, priority) " +
                     "SELECT ?, ?, ?, tm.employee_id, ?, ?, ?, 'ASSIGNED', ?, 'MEDIUM' " +
                     "FROM team_members tm WHERE tm.team_id = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, title + " [Team Task]");
            ps.setString(2, description);
            ps.setString(3, taskFilePath);
            ps.setString(4, managerId != null ? managerId.trim() : "");
            ps.setDate(5, startDate != null ? Date.valueOf(startDate) : Date.valueOf(LocalDate.now()));
            if (dueDate != null) {
                ps.setDate(6, Date.valueOf(dueDate));
            } else {
                ps.setNull(6, Types.DATE);
            }
            ps.setInt(7, teamId);
            ps.setInt(8, teamId);
            ps.executeUpdate();
        } catch (SQLException e) {
            System.err.println("Error assigning team task with file: " + e.getMessage());
            e.printStackTrace();
        }
    }

    // 5. Employee Task Submission
    public boolean submitEmployeeTask(int taskId, String comment, String filePath, String empId) {
        String sql = "UPDATE tasks SET status = 'SUBMITTED_FOR_REVIEW', employee_submission_note = ?, " +
                     "submission_file_path = ? WHERE task_id = ? AND assigned_to = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, comment);
            ps.setString(2, filePath);
            ps.setInt(3, taskId);
            ps.setString(4, empId != null ? empId.trim() : "");
            return ps.executeUpdate() > 0;
        } catch (SQLException e) {
            System.err.println("Error in submitEmployeeTask: " + e.getMessage());
            e.printStackTrace();
            return false;
        }
    }

    public boolean submitEmployeeTask(int taskId, String comment, String filePath, int empId) {
        return submitEmployeeTask(taskId, comment, filePath, String.valueOf(empId));
    }

    public void submitEmployeeTaskWithProof(int taskId, String employeeId, String note, String fileName, String newStatus) {
        String statusToSet = (newStatus != null && !newStatus.isBlank()) ? newStatus : "SUBMITTED_FOR_REVIEW";
        
        // If a file was uploaded, update the file path.
        // If NO file was uploaded, keep the existing submission_file_path!
        String sql;
        if (fileName != null && !fileName.isBlank()) {
            sql = "UPDATE tasks SET status = ?, employee_submission_note = ?, submission_file_path = ? WHERE task_id = ?";
        } else {
            sql = "UPDATE tasks SET status = ?, employee_submission_note = ? WHERE task_id = ?";
        }

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            
            ps.setString(1, statusToSet);
            ps.setString(2, note);
            
            if (fileName != null && !fileName.isBlank()) {
                ps.setString(3, fileName);
                ps.setInt(4, taskId);
            } else {
                ps.setInt(3, taskId);
            }
            
            int rows = ps.executeUpdate();
            System.out.println("DEBUG Task Submit: Task ID " + taskId + " updated, rows affected = " + rows + ", File = " + fileName);
        } catch (SQLException e) {
            System.err.println("Error saving task submission: " + e.getMessage());
            e.printStackTrace();
        }
    }

    // 6. Manager Review
    public boolean reviewTaskByManager(int taskId, String newStatus, int rating, String feedback) {
        String sql = "UPDATE tasks SET status = ?, rating = ?, manager_feedback = ? WHERE task_id = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, newStatus);
            if (rating > 0) {
                ps.setInt(2, rating);
            } else {
                ps.setNull(2, Types.INTEGER);
            }
            ps.setString(3, feedback);
            ps.setInt(4, taskId);
            return ps.executeUpdate() > 0;
        } catch (SQLException e) {
            System.err.println("Error reviewing task by manager: " + e.getMessage());
            e.printStackTrace();
            return false;
        }
    }

    // 7. Delete Task
    public boolean deleteTask(int taskId) {
        String sql = "DELETE FROM tasks WHERE task_id = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, taskId);
            return ps.executeUpdate() > 0;
        } catch (SQLException e) {
            System.err.println("Error deleting task: " + e.getMessage());
            e.printStackTrace();
            return false;
        }
    }

    // 8. Get Task by task_id
    public Task getTaskById(int taskId) {
        String sql = "SELECT * FROM tasks WHERE task_id = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, taskId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) return map(rs);
            }
        } catch (SQLException e) {
            System.err.println("Error getting task by ID: " + e.getMessage());
            e.printStackTrace();
        }
        return null;
    }

    // 9. Get All Tasks (Admin view)
    public List<Task> getAllTasks() {
        List<Task> list = new ArrayList<>();
        String sql = "SELECT * FROM tasks ORDER BY task_id DESC";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) list.add(map(rs));
        } catch (SQLException e) {
            System.err.println("Error getting all tasks: " + e.getMessage());
            e.printStackTrace();
        }
        return list;
    }

    // 10. Find tasks for a specific team
    public List<Task> findTasksByTeam(int teamId) {
        List<Task> list = new ArrayList<>();
        String sql = "SELECT * FROM tasks WHERE team_id = ? OR assigned_to IN " +
                     "(SELECT employee_id FROM team_members WHERE team_id = ?) " +
                     "ORDER BY task_id DESC";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, teamId);
            ps.setInt(2, teamId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(map(rs));
                }
            }
        } catch (SQLException e) {
            System.err.println("Error finding tasks by team: " + e.getMessage());
            e.printStackTrace();
        }
        return list;
    }

    public List<Task> getTasksByEmployee(String employeeId) {
        List<Task> list = new ArrayList<>();
        String sql = "SELECT * FROM tasks WHERE assigned_to = ? " +
                     "OR team_id IN (SELECT team_id FROM team_members WHERE employee_id = ?) " +
                     "ORDER BY task_id DESC";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            String cleanEmpId = (employeeId != null) ? employeeId.trim() : "";
            ps.setString(1, cleanEmpId);
            ps.setString(2, cleanEmpId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(map(rs));
                }
            }
        } catch (SQLException e) {
            System.err.println("Error getting tasks by employee: " + e.getMessage());
            e.printStackTrace();
        }
        return list;
    }

    // 11. Update Task details by Manager (Title, Description, Priority, Due Date - without touching files)
    public boolean updateTaskDetails(int taskId, String title, String description, String priority, LocalDate dueDate) {
        String sql = "UPDATE tasks SET title = ?, description = ?, priority = ?, due_date = ? WHERE task_id = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, title);
            ps.setString(2, description);
            ps.setString(3, priority != null ? priority : "MEDIUM");
            if (dueDate != null) {
                ps.setDate(4, Date.valueOf(dueDate));
            } else {
                ps.setNull(4, Types.DATE);
            }
            ps.setInt(5, taskId);
            return ps.executeUpdate() > 0;
        } catch (SQLException e) {
            System.err.println("Error updating task details: " + e.getMessage());
            e.printStackTrace();
            return false;
        }
    }

    // 12. Fetch the current task file path before replacing
    public String getTaskFilePathById(int taskId) {
        String sql = "SELECT task_file_path FROM tasks WHERE task_id = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, taskId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return rs.getString("task_file_path");
                }
            }
        } catch (SQLException e) {
            System.err.println("Error getting task file path: " + e.getMessage());
            e.printStackTrace();
        }
        return null;
    }

    // 13. Update task details AND replaced file paths
    public boolean updateTaskDetailsWithFiles(int taskId, String title, String description, String priority, LocalDate dueDate, String newFilePath) {
        String sql = "UPDATE tasks SET title = ?, description = ?, priority = ?, due_date = ?, task_file_path = ? WHERE task_id = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, title);
            ps.setString(2, description);
            ps.setString(3, priority != null ? priority : "MEDIUM");
            if (dueDate != null) {
                ps.setDate(4, Date.valueOf(dueDate));
            } else {
                ps.setNull(4, Types.DATE);
            }
            ps.setString(5, newFilePath);
            ps.setInt(6, taskId);
            return ps.executeUpdate() > 0;
        } catch (SQLException e) {
            System.err.println("Error updating task details with files: " + e.getMessage());
            e.printStackTrace();
            return false;
        }
    }

    // 14. Row Mapper preserving String IDs and non-null statuses
    private Task map(ResultSet rs) throws SQLException {
        Task t = new Task();
        t.setId(rs.getInt("task_id"));
        
        String title = rs.getString("title");
        t.setTitle(title);
        t.setTaskTitle(title);
        
        t.setDescription(rs.getString("description"));
        t.setTaskFilePath(rs.getString("task_file_path"));

        String assignedTo = rs.getString("assigned_to");
        t.setAssignedToName(assignedTo != null ? assignedTo : "");
        try {
            t.setAssignedTo(Integer.parseInt(assignedTo));
        } catch (Exception e) {
            t.setAssignedTo(0);
        }

        String assignedBy = rs.getString("assigned_by");
        t.setCreatedByName(assignedBy != null ? assignedBy : "Manager");
        t.setAssignedBy(assignedBy);
        try {
            t.setCreatedBy(Integer.parseInt(assignedBy));
        } catch (Exception e) {
            t.setCreatedBy(0);
        }

        t.setPriority(rs.getString("priority"));

        Date sd = rs.getDate("start_date");
        if (sd != null) t.setStartDate(sd.toLocalDate());

        Date dd = rs.getDate("due_date");
        if (dd != null) t.setDueDate(dd.toLocalDate());

        String st = rs.getString("status");
        t.setStatus(st != null && !st.isBlank() ? st : "ASSIGNED");

        String empNote = rs.getString("employee_submission_note");
        t.setEmployeeComment(empNote);
        t.setEmployeeSubmissionNote(empNote);

        t.setSubmissionFilePath(rs.getString("submission_file_path"));

        int r = rs.getInt("rating");
        if (!rs.wasNull()) {
            t.setRating(r);
        }

        t.setManagerFeedback(rs.getString("manager_feedback"));
        
        try {
            t.setTeamId(rs.getInt("team_id"));
        } catch (Exception ignored) {}

        return t;
    }
}