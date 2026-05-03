package api

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os/exec"
	"strings"
	"time"

	"github.com/shirou/gopsutil/v3/process"
)

// Service represents a system service (systemd or Docker)
type Service struct {
	Name      string  `json:"name"`
	Type      string  `json:"type"` // "systemd" or "docker"
	Status    string  `json:"status"`
	CPU       float64 `json:"cpu,omitempty"`
	Memory    uint64  `json:"memory,omitempty"`
	Uptime    int64   `json:"uptime,omitempty"`
	Container string  `json:"containerId,omitempty"` // For Docker
	Image     string  `json:"image,omitempty"`       // For Docker
}

// ServicesResponse wraps the list of services
type ServicesResponse struct {
	Services []Service `json:"services"`
}

// GetServices handles GET /services - lists all services
func GetServices(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	w.Header().Set("Content-Type", "application/json")

	var allServices []Service

	// Get systemd services
	systemdServices, err := listSystemdServices()
	if err != nil {
		log.Printf("[WARN] Failed to list systemd services: %v", err)
	} else {
		allServices = append(allServices, systemdServices...)
	}

	// Get Docker containers
	dockerServices, err := listDockerContainers()
	if err != nil {
		log.Printf("[WARN] Failed to list Docker containers: %v", err)
	} else {
		allServices = append(allServices, dockerServices...)
	}

	response := ServicesResponse{Services: allServices}
	json.NewEncoder(w).Encode(response)
}

// ControlService handles POST /services/{name}/start|stop|restart
func ControlService(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Parse URL: /api/services/{name}/{action}
	pathParts := strings.Split(strings.TrimPrefix(r.URL.Path, "/api/services/"), "/")
	if len(pathParts) < 2 {
		http.Error(w, "Invalid URL format. Expected: /api/services/{name}/{action}", http.StatusBadRequest)
		return
	}

	serviceName := pathParts[0]
	action := pathParts[1]

	// Validate action
	if action != "start" && action != "stop" && action != "restart" {
		http.Error(w, "Invalid action. Must be: start, stop, or restart", http.StatusBadRequest)
		return
	}

	// Determine service type from query parameter or try both
	serviceType := r.URL.Query().Get("type") // "systemd" or "docker"

	var err error
	if serviceType == "docker" {
		err = controlDockerContainer(serviceName, action)
	} else if serviceType == "systemd" || serviceType == "" {
		err = controlSystemdService(serviceName, action)
		if err != nil && serviceType == "" {
			// Try Docker if systemd failed and type not specified
			err = controlDockerContainer(serviceName, action)
		}
	}

	if err != nil {
		log.Printf("[ERROR] Failed to %s service %s: %v", action, serviceName, err)
		http.Error(w, fmt.Sprintf("Failed to %s service: %v", action, err), http.StatusInternalServerError)
		return
	}

	log.Printf("[INFO] Service %s %sed successfully", serviceName, action)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status":  "success",
		"message": fmt.Sprintf("Service %s %sed successfully", serviceName, action),
	})
}

// listSystemdServices retrieves all systemd services
func listSystemdServices() ([]Service, error) {
	cmd := exec.Command("systemctl", "list-units", "--type=service", "--all", "--no-pager", "--plain")
	output, err := cmd.Output()
	if err != nil {
		return nil, err
	}

	var services []Service
	lines := strings.Split(string(output), "\n")

	for _, line := range lines {
		fields := strings.Fields(line)
		if len(fields) < 4 {
			continue
		}

		serviceName := strings.TrimSuffix(fields[0], ".service")
		loadState := fields[1]
		activeState := fields[2]
		
		// Skip if not loaded
		if loadState != "loaded" {
			continue
		}

		status := "stopped"
		if activeState == "active" {
			status = "running"
		} else if activeState == "failed" {
			status = "failed"
		}

		service := Service{
			Name:   serviceName,
			Type:   "systemd",
			Status: status,
		}

		// Try to get resource usage
		if status == "running" {
			cpu, mem, uptime := getServiceResources(serviceName)
			service.CPU = cpu
			service.Memory = mem
			service.Uptime = uptime
		}

		services = append(services, service)
	}

	return services, nil
}

// listDockerContainers retrieves all Docker containers
func listDockerContainers() ([]Service, error) {
	cmd := exec.Command("docker", "ps", "-a", "--format", "{{.ID}}|{{.Names}}|{{.Status}}|{{.Image}}")
	output, err := cmd.Output()
	if err != nil {
		return nil, err
	}

	var services []Service
	lines := strings.Split(string(output), "\n")

	for _, line := range lines {
		if line == "" {
			continue
		}

		parts := strings.Split(line, "|")
		if len(parts) < 4 {
			continue
		}

		containerID := parts[0]
		name := parts[1]
		statusStr := parts[2]
		image := parts[3]

		status := "stopped"
		if strings.HasPrefix(statusStr, "Up") {
			status = "running"
		} else if strings.Contains(statusStr, "Exited") {
			status = "stopped"
		}

		service := Service{
			Name:      name,
			Type:      "docker",
			Status:    status,
			Container: containerID,
			Image:     image,
		}

		// Get resource usage for running containers
		if status == "running" {
			cpu, mem := getDockerResources(containerID)
			service.CPU = cpu
			service.Memory = mem
		}

		services = append(services, service)
	}

	return services, nil
}

// getServiceResources gets CPU, memory, and uptime for a systemd service
func getServiceResources(serviceName string) (float64, uint64, int64) {
	// Get main PID of the service
	cmd := exec.Command("systemctl", "show", serviceName, "--property=MainPID")
	output, err := cmd.Output()
	if err != nil {
		return 0, 0, 0
	}

	pidStr := strings.TrimPrefix(strings.TrimSpace(string(output)), "MainPID=")
	var pid int32
	fmt.Sscanf(pidStr, "%d", &pid)

	if pid == 0 {
		return 0, 0, 0
	}

	proc, err := process.NewProcess(pid)
	if err != nil {
		return 0, 0, 0
	}

	cpu, _ := proc.CPUPercent()
	memInfo, _ := proc.MemoryInfo()
	createTime, _ := proc.CreateTime()
	
	memory := uint64(0)
	if memInfo != nil {
		memory = memInfo.RSS
	}

	uptime := int64(0)
	if createTime > 0 {
		uptime = (time.Now().Unix()*1000 - createTime) / 1000
	}

	return cpu, memory, uptime
}

// getDockerResources gets CPU and memory for a Docker container
func getDockerResources(containerID string) (float64, uint64) {
	cmd := exec.Command("docker", "stats", containerID, "--no-stream", "--format", "{{.CPUPerc}}|{{.MemUsage}}")
	output, err := cmd.Output()
	if err != nil {
		return 0, 0
	}

	parts := strings.Split(strings.TrimSpace(string(output)), "|")
	if len(parts) < 2 {
		return 0, 0
	}

	var cpu float64
	fmt.Sscanf(strings.TrimSuffix(parts[0], "%"), "%f", &cpu)

	// Parse memory (format: "123.4MiB / 1.5GiB")
	memParts := strings.Split(parts[1], "/")
	var memory uint64
	if len(memParts) > 0 {
		memStr := strings.TrimSpace(memParts[0])
		var memVal float64
		var unit string
		fmt.Sscanf(memStr, "%f%s", &memVal, &unit)
		
		switch strings.ToUpper(unit) {
		case "KIB":
			memory = uint64(memVal * 1024)
		case "MIB":
			memory = uint64(memVal * 1024 * 1024)
		case "GIB":
			memory = uint64(memVal * 1024 * 1024 * 1024)
		}
	}

	return cpu, memory
}

// controlSystemdService controls a systemd service
func controlSystemdService(serviceName, action string) error {
	cmd := exec.Command("systemctl", action, serviceName)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	
	err := cmd.Run()
	if err != nil {
		return fmt.Errorf("%v: %s", err, stderr.String())
	}
	
	return nil
}

// controlDockerContainer controls a Docker container
func controlDockerContainer(containerName, action string) error {
	dockerAction := action
	if action == "restart" {
		dockerAction = "restart"
	} else if action == "stop" {
		dockerAction = "stop"
	} else if action == "start" {
		dockerAction = "start"
	}

	cmd := exec.Command("docker", dockerAction, containerName)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	
	err := cmd.Run()
	if err != nil {
		return fmt.Errorf("%v: %s", err, stderr.String())
	}
	
	return nil
}

// Made with Bob
