package api

import (
	"bufio"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"regexp"
	"strings"
	"time"

	"github.com/gorilla/websocket"
)

var logsUpgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true // Allow all origins for development
	},
}

// LogEntry represents a single log entry
type LogEntry struct {
	Timestamp string `json:"timestamp"`
	Source    string `json:"source"`
	Level     string `json:"level"`
	Message   string `json:"message"`
}

var logLevelRegex = regexp.MustCompile(`(?i)\b(ERROR|WARN|WARNING|INFO|DEBUG|FATAL|CRITICAL)\b`)

// GetLogs handles both HTTP GET and WebSocket connections for log streaming
func GetLogs(w http.ResponseWriter, r *http.Request) {
	// Check if this is a WebSocket upgrade request
	if r.Header.Get("Upgrade") == "websocket" {
		StreamLogs(w, r)
		return
	}

	// Regular HTTP GET - return recent logs
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	logPath := r.URL.Query().Get("path")
	if logPath == "" {
		http.Error(w, "Missing 'path' query parameter", http.StatusBadRequest)
		return
	}

	// Read last N lines
	lines := 100
	logs, err := readLastLines(logPath, lines)
	if err != nil {
		log.Printf("[ERROR] Failed to read log file %s: %v", logPath, err)
		http.Error(w, fmt.Sprintf("Failed to read log file: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"logs": logs,
	})
}

// StreamLogs handles WebSocket connections for real-time log streaming
func StreamLogs(w http.ResponseWriter, r *http.Request) {
	conn, err := logsUpgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("[ERROR] WebSocket upgrade failed: %v", err)
		return
	}
	defer conn.Close()

	logPath := r.URL.Query().Get("path")
	service := r.URL.Query().Get("service")
	keyword := r.URL.Query().Get("keyword")

	log.Printf("[INFO] Log streaming WebSocket connected from %s (path=%s, service=%s, keyword=%s)",
		r.RemoteAddr, logPath, service, keyword)

	// Determine log source
	var cmd *exec.Cmd
	var source string

	if service != "" {
		// Stream from systemd journal
		source = fmt.Sprintf("journalctl:%s", service)
		cmd = exec.Command("journalctl", "-u", service, "-f", "-n", "0", "--no-pager")
	} else if logPath != "" {
		// Stream from file
		source = logPath
		
		// Check if file exists
		if _, err := os.Stat(logPath); os.IsNotExist(err) {
			conn.WriteJSON(LogEntry{
				Timestamp: time.Now().UTC().Format(time.RFC3339),
				Source:    source,
				Level:     "ERROR",
				Message:   fmt.Sprintf("Log file not found: %s", logPath),
			})
			return
		}
		
		cmd = exec.Command("tail", "-f", "-n", "0", logPath)
	} else {
		conn.WriteJSON(LogEntry{
			Timestamp: time.Now().UTC().Format(time.RFC3339),
			Source:    "error",
			Level:     "ERROR",
			Message:   "Either 'path' or 'service' parameter is required",
		})
		return
	}

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		log.Printf("[ERROR] Failed to create stdout pipe: %v", err)
		return
	}

	if err := cmd.Start(); err != nil {
		log.Printf("[ERROR] Failed to start log streaming command: %v", err)
		conn.WriteJSON(LogEntry{
			Timestamp: time.Now().UTC().Format(time.RFC3339),
			Source:    source,
			Level:     "ERROR",
			Message:   fmt.Sprintf("Failed to start log streaming: %v", err),
		})
		return
	}

	// Ensure command is killed when done
	defer func() {
		if cmd.Process != nil {
			cmd.Process.Kill()
		}
	}()

	scanner := bufio.NewScanner(stdout)
	for scanner.Scan() {
		line := scanner.Text()

		// Filter by keyword if specified
		if keyword != "" && !strings.Contains(strings.ToLower(line), strings.ToLower(keyword)) {
			continue
		}

		logEntry := LogEntry{
			Timestamp: time.Now().UTC().Format(time.RFC3339),
			Source:    source,
			Level:     detectLogLevel(line),
			Message:   line,
		}

		if err := conn.WriteJSON(logEntry); err != nil {
			log.Printf("[ERROR] Failed to send log entry: %v", err)
			return
		}
	}

	if err := scanner.Err(); err != nil {
		log.Printf("[ERROR] Scanner error: %v", err)
	}
}

// readLastLines reads the last N lines from a file
func readLastLines(filePath string, n int) ([]LogEntry, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	// Get file size
	stat, err := file.Stat()
	if err != nil {
		return nil, err
	}

	// Read from end of file
	bufferSize := int64(4096)
	if stat.Size() < bufferSize {
		bufferSize = stat.Size()
	}

	buffer := make([]byte, bufferSize)
	_, err = file.ReadAt(buffer, stat.Size()-bufferSize)
	if err != nil {
		return nil, err
	}

	lines := strings.Split(string(buffer), "\n")
	
	// Get last N lines
	start := len(lines) - n
	if start < 0 {
		start = 0
	}
	
	var logEntries []LogEntry
	for _, line := range lines[start:] {
		if line == "" {
			continue
		}
		
		logEntries = append(logEntries, LogEntry{
			Timestamp: time.Now().UTC().Format(time.RFC3339),
			Source:    filePath,
			Level:     detectLogLevel(line),
			Message:   line,
		})
	}

	return logEntries, nil
}

// detectLogLevel detects the log level from a log message
func detectLogLevel(message string) string {
	matches := logLevelRegex.FindStringSubmatch(message)
	if len(matches) > 1 {
		level := strings.ToUpper(matches[1])
		// Normalize WARNING to WARN
		if level == "WARNING" {
			return "WARN"
		}
		return level
	}
	return "INFO"
}

// Made with Bob
