package api

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"syscall"

	"github.com/shirou/gopsutil/v3/process"
)

// Process represents a system process
type Process struct {
	PID     int32   `json:"pid"`
	Name    string  `json:"name"`
	User    string  `json:"user"`
	CPU     float64 `json:"cpu"`
	Memory  uint64  `json:"memory"`
	Command string  `json:"command"`
}

// ProcessesResponse wraps the list of processes
type ProcessesResponse struct {
	Processes []Process `json:"processes"`
}

// GetProcesses handles GET /processes - lists all processes
func GetProcesses(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	w.Header().Set("Content-Type", "application/json")

	// Get query parameters
	sortBy := r.URL.Query().Get("sort") // "cpu" or "memory"
	searchName := r.URL.Query().Get("name")

	processes, err := listProcesses(sortBy, searchName)
	if err != nil {
		log.Printf("[ERROR] Failed to list processes: %v", err)
		http.Error(w, "Failed to list processes", http.StatusInternalServerError)
		return
	}

	response := ProcessesResponse{Processes: processes}
	json.NewEncoder(w).Encode(response)
}

// KillProcess handles POST /processes/{pid}/kill - kills a process
func KillProcess(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Extract PID from URL path
	pathParts := strings.Split(r.URL.Path, "/")
	if len(pathParts) < 4 {
		http.Error(w, "Invalid URL format", http.StatusBadRequest)
		return
	}

	pidStr := pathParts[3]
	pid, err := strconv.ParseInt(pidStr, 10, 32)
	if err != nil {
		http.Error(w, "Invalid PID", http.StatusBadRequest)
		return
	}

	// Kill the process
	proc, err := process.NewProcess(int32(pid))
	if err != nil {
		log.Printf("[ERROR] Process %d not found: %v", pid, err)
		http.Error(w, fmt.Sprintf("Process %d not found", pid), http.StatusNotFound)
		return
	}

	name, _ := proc.Name()
	err = proc.Kill()
	if err != nil {
		log.Printf("[ERROR] Failed to kill process %d (%s): %v", pid, name, err)
		http.Error(w, fmt.Sprintf("Failed to kill process: %v", err), http.StatusInternalServerError)
		return
	}

	log.Printf("[INFO] Process %d (%s) killed successfully", pid, name)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status":  "success",
		"message": fmt.Sprintf("Process %d (%s) killed successfully", pid, name),
	})
}

// listProcesses retrieves all processes with optional sorting and filtering
func listProcesses(sortBy, searchName string) ([]Process, error) {
	pids, err := process.Pids()
	if err != nil {
		return nil, err
	}

	var processes []Process

	for _, pid := range pids {
		proc, err := process.NewProcess(pid)
		if err != nil {
			continue // Skip processes we can't access
		}

		name, err := proc.Name()
		if err != nil {
			name = "unknown"
		}

		// Filter by name if specified
		if searchName != "" && !strings.Contains(strings.ToLower(name), strings.ToLower(searchName)) {
			continue
		}

		username, err := proc.Username()
		if err != nil {
			username = "unknown"
		}

		cpuPercent, err := proc.CPUPercent()
		if err != nil {
			cpuPercent = 0
		}

		memInfo, err := proc.MemoryInfo()
		memory := uint64(0)
		if err == nil {
			memory = memInfo.RSS
		}

		cmdline, err := proc.Cmdline()
		if err != nil {
			cmdline = ""
		}
		if cmdline == "" {
			cmdline = name
		}

		processes = append(processes, Process{
			PID:     pid,
			Name:    name,
			User:    username,
			CPU:     cpuPercent,
			Memory:  memory,
			Command: cmdline,
		})
	}

	// Sort processes
	switch sortBy {
	case "cpu":
		sort.Slice(processes, func(i, j int) bool {
			return processes[i].CPU > processes[j].CPU
		})
	case "memory":
		sort.Slice(processes, func(i, j int) bool {
			return processes[i].Memory > processes[j].Memory
		})
	default:
		// Default sort by PID
		sort.Slice(processes, func(i, j int) bool {
			return processes[i].PID < processes[j].PID
		})
	}

	return processes, nil
}

// TerminateProcess sends SIGTERM to a process (graceful shutdown)
func TerminateProcess(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	pathParts := strings.Split(r.URL.Path, "/")
	if len(pathParts) < 4 {
		http.Error(w, "Invalid URL format", http.StatusBadRequest)
		return
	}

	pidStr := pathParts[3]
	pid, err := strconv.ParseInt(pidStr, 10, 32)
	if err != nil {
		http.Error(w, "Invalid PID", http.StatusBadRequest)
		return
	}

	proc, err := process.NewProcess(int32(pid))
	if err != nil {
		http.Error(w, fmt.Sprintf("Process %d not found", pid), http.StatusNotFound)
		return
	}

	name, _ := proc.Name()
	err = proc.SendSignal(syscall.SIGTERM)
	if err != nil {
		log.Printf("[ERROR] Failed to terminate process %d (%s): %v", pid, name, err)
		http.Error(w, fmt.Sprintf("Failed to terminate process: %v", err), http.StatusInternalServerError)
		return
	}

	log.Printf("[INFO] Process %d (%s) terminated (SIGTERM)", pid, name)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status":  "success",
		"message": fmt.Sprintf("Process %d (%s) terminated successfully", pid, name),
	})
}

// Made with Bob
