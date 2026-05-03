package api

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os/exec"
	"os/user"
	"regexp"
	"strings"
	"time"
)

// CronJob represents a cron job entry
type CronJob struct {
	Expression  string `json:"expression"`
	Command     string `json:"command"`
	Description string `json:"description"`
}

// CronResponse wraps the list of cron jobs
type CronResponse struct {
	Entries []CronJob `json:"entries"`
}

// CronWriteRequest represents a request to update crontab
type CronWriteRequest struct {
	Entries []CronJob `json:"entries"`
}

var cronRegex = regexp.MustCompile(`^([^\s]+\s+[^\s]+\s+[^\s]+\s+[^\s]+\s+[^\s]+)\s+(.+)$`)

// GetCronJobs handles GET /cron - reads current crontab
func GetCronJobs(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodGet {
		readCrontab(w, r)
	} else if r.Method == http.MethodPost {
		writeCrontab(w, r)
	} else {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

// readCrontab reads and parses the current user's crontab
func readCrontab(w http.ResponseWriter, r *http.Request) {
	// Get current user
	currentUser, err := user.Current()
	if err != nil {
		log.Printf("[ERROR] Failed to get current user: %v", err)
		http.Error(w, "Failed to get current user", http.StatusInternalServerError)
		return
	}

	// Read crontab
	cmd := exec.Command("crontab", "-l")
	output, err := cmd.Output()
	if err != nil {
		// If crontab doesn't exist, return empty list
		if strings.Contains(err.Error(), "no crontab") {
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(CronResponse{Entries: []CronJob{}})
			return
		}
		log.Printf("[ERROR] Failed to read crontab: %v", err)
		http.Error(w, fmt.Sprintf("Failed to read crontab: %v", err), http.StatusInternalServerError)
		return
	}

	// Parse crontab entries
	var entries []CronJob
	lines := strings.Split(string(output), "\n")

	for _, line := range lines {
		line = strings.TrimSpace(line)
		
		// Skip empty lines and comments
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		// Parse cron expression and command
		matches := cronRegex.FindStringSubmatch(line)
		if len(matches) == 3 {
			expression := matches[1]
			command := matches[2]
			
			entries = append(entries, CronJob{
				Expression:  expression,
				Command:     command,
				Description: parseCronExpression(expression),
			})
		}
	}

	log.Printf("[INFO] Read %d cron jobs for user %s", len(entries), currentUser.Username)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(CronResponse{Entries: entries})
}

// writeCrontab writes new crontab entries
func writeCrontab(w http.ResponseWriter, r *http.Request) {
	var req CronWriteRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	// Validate all cron expressions
	for i, entry := range req.Entries {
		if !validateCronExpression(entry.Expression) {
			http.Error(w, fmt.Sprintf("Invalid cron expression at entry %d: %s", i, entry.Expression), http.StatusBadRequest)
			return
		}
	}

	// Build crontab content
	var buffer bytes.Buffer
	buffer.WriteString("# Crontab managed by Orbiter Agent\n")
	buffer.WriteString(fmt.Sprintf("# Updated: %s\n\n", time.Now().Format(time.RFC3339)))

	for _, entry := range req.Entries {
		buffer.WriteString(fmt.Sprintf("%s %s\n", entry.Expression, entry.Command))
	}

	// Write to crontab
	cmd := exec.Command("crontab", "-")
	cmd.Stdin = strings.NewReader(buffer.String())
	
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	
	if err := cmd.Run(); err != nil {
		log.Printf("[ERROR] Failed to write crontab: %v - %s", err, stderr.String())
		http.Error(w, fmt.Sprintf("Failed to write crontab: %v", err), http.StatusInternalServerError)
		return
	}

	log.Printf("[INFO] Crontab updated with %d entries", len(req.Entries))

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":  "success",
		"message": fmt.Sprintf("Crontab updated with %d entries", len(req.Entries)),
		"entries": len(req.Entries),
	})
}

// validateCronExpression validates a cron expression format
func validateCronExpression(expr string) bool {
	// Basic validation: should have 5 fields (minute hour day month weekday)
	fields := strings.Fields(expr)
	if len(fields) != 5 {
		return false
	}

	// Each field should be valid
	for _, field := range fields {
		if !isValidCronField(field) {
			return false
		}
	}

	return true
}

// isValidCronField checks if a cron field is valid
func isValidCronField(field string) bool {
	// Allow: numbers, *, -, /, ,
	validPattern := regexp.MustCompile(`^[\d\*\-\/\,]+$`)
	return validPattern.MatchString(field)
}

// parseCronExpression converts cron expression to human-readable description
func parseCronExpression(expr string) string {
	fields := strings.Fields(expr)
	if len(fields) != 5 {
		return "Invalid cron expression"
	}

	minute := fields[0]
	hour := fields[1]
	day := fields[2]
	month := fields[3]
	weekday := fields[4]

	// Simple parsing for common patterns
	if minute == "*" && hour == "*" && day == "*" && month == "*" && weekday == "*" {
		return "Every minute"
	}

	if strings.HasPrefix(minute, "*/") && hour == "*" && day == "*" && month == "*" && weekday == "*" {
		interval := strings.TrimPrefix(minute, "*/")
		return fmt.Sprintf("Every %s minutes", interval)
	}

	if hour == "*" && day == "*" && month == "*" && weekday == "*" {
		if minute == "0" {
			return "Every hour"
		}
		return fmt.Sprintf("Every hour at minute %s", minute)
	}

	if day == "*" && month == "*" && weekday == "*" {
		return fmt.Sprintf("Every day at %s:%s", hour, minute)
	}

	if month == "*" && weekday == "*" {
		return fmt.Sprintf("Every month on day %s at %s:%s", day, hour, minute)
	}

	if day == "*" && month == "*" {
		weekdayName := getWeekdayName(weekday)
		return fmt.Sprintf("Every %s at %s:%s", weekdayName, hour, minute)
	}

	// Default description
	return fmt.Sprintf("At %s:%s on day %s of month %s, weekday %s", hour, minute, day, month, weekday)
}

// getWeekdayName converts weekday number to name
func getWeekdayName(weekday string) string {
	weekdays := map[string]string{
		"0": "Sunday",
		"1": "Monday",
		"2": "Tuesday",
		"3": "Wednesday",
		"4": "Thursday",
		"5": "Friday",
		"6": "Saturday",
		"7": "Sunday",
	}
	
	if name, ok := weekdays[weekday]; ok {
		return name
	}
	return "weekday " + weekday
}

// Made with Bob
