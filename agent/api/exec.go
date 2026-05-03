package api

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os/exec"
	"time"

	"github.com/gorilla/websocket"
)

var execUpgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true // Allow all origins for development
	},
}

// ExecRequest represents a command execution request
type ExecRequest struct {
	Command string `json:"command"`
	Timeout int    `json:"timeout,omitempty"` // Timeout in seconds, default 30
}

// ExecResponse represents command execution output
type ExecResponse struct {
	Type      string `json:"type"`      // "stdout", "stderr", "exit", "error"
	Data      string `json:"data"`
	ExitCode  int    `json:"exitCode,omitempty"`
	Timestamp string `json:"timestamp"`
}

// ExecuteCommand handles both HTTP POST and WebSocket for command execution
func ExecuteCommand(w http.ResponseWriter, r *http.Request) {
	// Check if this is a WebSocket upgrade request
	if r.Header.Get("Upgrade") == "websocket" {
		StreamCommandExecution(w, r)
		return
	}

	// Regular HTTP POST
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req ExecRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	if req.Command == "" {
		http.Error(w, "Command is required", http.StatusBadRequest)
		return
	}

	// Set default timeout
	if req.Timeout == 0 {
		req.Timeout = 30
	}

	log.Printf("[INFO] Executing command: %s (timeout: %ds)", req.Command, req.Timeout)

	// Execute command with timeout
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(req.Timeout)*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "sh", "-c", req.Command)
	output, err := cmd.CombinedOutput()

	response := ExecResponse{
		Type:      "exit",
		Data:      string(output),
		Timestamp: time.Now().UTC().Format(time.RFC3339),
	}

	if err != nil {
		if ctx.Err() == context.DeadlineExceeded {
			response.Type = "error"
			response.Data = fmt.Sprintf("Command timed out after %d seconds", req.Timeout)
			response.ExitCode = -1
		} else if exitErr, ok := err.(*exec.ExitError); ok {
			response.ExitCode = exitErr.ExitCode()
		} else {
			response.Type = "error"
			response.Data = err.Error()
			response.ExitCode = -1
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// StreamCommandExecution handles WebSocket connections for real-time command execution
func StreamCommandExecution(w http.ResponseWriter, r *http.Request) {
	conn, err := execUpgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("[ERROR] WebSocket upgrade failed: %v", err)
		return
	}
	defer conn.Close()

	log.Printf("[INFO] Command execution WebSocket connected from %s", r.RemoteAddr)

	// Read command from WebSocket
	var req ExecRequest
	if err := conn.ReadJSON(&req); err != nil {
		log.Printf("[ERROR] Failed to read command: %v", err)
		conn.WriteJSON(ExecResponse{
			Type:      "error",
			Data:      "Failed to read command",
			Timestamp: time.Now().UTC().Format(time.RFC3339),
		})
		return
	}

	if req.Command == "" {
		conn.WriteJSON(ExecResponse{
			Type:      "error",
			Data:      "Command is required",
			Timestamp: time.Now().UTC().Format(time.RFC3339),
		})
		return
	}

	// Set default timeout
	if req.Timeout == 0 {
		req.Timeout = 30
	}

	log.Printf("[SECURITY] Command executed by %s: %s", r.RemoteAddr, req.Command)

	// Create command with timeout
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(req.Timeout)*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "sh", "-c", req.Command)

	// Get stdout and stderr pipes
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		conn.WriteJSON(ExecResponse{
			Type:      "error",
			Data:      fmt.Sprintf("Failed to create stdout pipe: %v", err),
			Timestamp: time.Now().UTC().Format(time.RFC3339),
		})
		return
	}

	stderr, err := cmd.StderrPipe()
	if err != nil {
		conn.WriteJSON(ExecResponse{
			Type:      "error",
			Data:      fmt.Sprintf("Failed to create stderr pipe: %v", err),
			Timestamp: time.Now().UTC().Format(time.RFC3339),
		})
		return
	}

	// Start command
	if err := cmd.Start(); err != nil {
		conn.WriteJSON(ExecResponse{
			Type:      "error",
			Data:      fmt.Sprintf("Failed to start command: %v", err),
			Timestamp: time.Now().UTC().Format(time.RFC3339),
		})
		return
	}

	// Stream stdout
	go func() {
		scanner := bufio.NewScanner(stdout)
		for scanner.Scan() {
			conn.WriteJSON(ExecResponse{
				Type:      "stdout",
				Data:      scanner.Text(),
				Timestamp: time.Now().UTC().Format(time.RFC3339),
			})
		}
	}()

	// Stream stderr
	go func() {
		scanner := bufio.NewScanner(stderr)
		for scanner.Scan() {
			conn.WriteJSON(ExecResponse{
				Type:      "stderr",
				Data:      scanner.Text(),
				Timestamp: time.Now().UTC().Format(time.RFC3339),
			})
		}
	}()

	// Wait for command to complete
	err = cmd.Wait()

	exitCode := 0
	responseType := "exit"
	message := "Command completed successfully"

	if err != nil {
		if ctx.Err() == context.DeadlineExceeded {
			responseType = "error"
			message = fmt.Sprintf("Command timed out after %d seconds", req.Timeout)
			exitCode = -1
		} else if exitErr, ok := err.(*exec.ExitError); ok {
			exitCode = exitErr.ExitCode()
			message = fmt.Sprintf("Command exited with code %d", exitCode)
		} else {
			responseType = "error"
			message = err.Error()
			exitCode = -1
		}
	}

	// Send exit status
	conn.WriteJSON(ExecResponse{
		Type:      responseType,
		Data:      message,
		ExitCode:  exitCode,
		Timestamp: time.Now().UTC().Format(time.RFC3339),
	})

	log.Printf("[INFO] Command completed with exit code %d", exitCode)
}

// Made with Bob
