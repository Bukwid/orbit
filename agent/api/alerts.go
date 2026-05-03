package api

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/shirou/gopsutil/v3/cpu"
	"github.com/shirou/gopsutil/v3/disk"
	"github.com/shirou/gopsutil/v3/mem"
)

// Alert thresholds
const (
	CPUThreshold  = 85.0
	RAMThreshold  = 90.0
	DiskThreshold = 80.0
	AlertCooldown = 5 * time.Minute
)

// Alert represents a system alert
type Alert struct {
	ServerID    string  `json:"serverId"`
	ServerName  string  `json:"serverName"`
	AlertType   string  `json:"alertType"`
	Metric      string  `json:"metric"`
	Value       float64 `json:"value"`
	Threshold   float64 `json:"threshold"`
	Timestamp   string  `json:"timestamp"`
	DeviceToken string  `json:"deviceToken,omitempty"`
}

// AlertHistory tracks recent alerts to implement cooldown
type AlertHistory struct {
	mu         sync.Mutex
	lastAlerts map[string]time.Time
}

var (
	alertHistory    = &AlertHistory{lastAlerts: make(map[string]time.Time)}
	alertEndpoint   string
	monitoringToken string
)

// GetAlerts handles GET /alerts - returns current alert status
func GetAlerts(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	w.Header().Set("Content-Type", "application/json")

	// Check current metrics against thresholds
	alerts := checkThresholds()

	json.NewEncoder(w).Encode(map[string]interface{}{
		"alerts": alerts,
		"count":  len(alerts),
	})
}

// StartAlertMonitoring starts background monitoring for threshold alerts
func StartAlertMonitoring(endpoint, token string) {
	alertEndpoint = endpoint
	monitoringToken = token

	go func() {
		ticker := time.NewTicker(30 * time.Second)
		defer ticker.Stop()

		log.Println("[INFO] Alert monitoring started")

		for range ticker.C {
			alerts := checkThresholds()
			for _, alert := range alerts {
				sendAlert(alert)
			}
		}
	}()
}

// checkThresholds checks system metrics against thresholds
func checkThresholds() []Alert {
	var alerts []Alert

	// Check CPU usage
	cpuPercent, err := cpu.Percent(time.Second, false)
	if err == nil && len(cpuPercent) > 0 {
		cpuUsage := cpuPercent[0]
		if cpuUsage > CPUThreshold {
			if shouldSendAlert("cpu") {
				alerts = append(alerts, Alert{
					AlertType: "threshold",
					Metric:    "cpu",
					Value:     cpuUsage,
					Threshold: CPUThreshold,
					Timestamp: time.Now().UTC().Format(time.RFC3339),
				})
			}
		}
	}

	// Check RAM usage
	memInfo, err := mem.VirtualMemory()
	if err == nil {
		ramUsage := memInfo.UsedPercent
		if ramUsage > RAMThreshold {
			if shouldSendAlert("ram") {
				alerts = append(alerts, Alert{
					AlertType: "threshold",
					Metric:    "ram",
					Value:     ramUsage,
					Threshold: RAMThreshold,
					Timestamp: time.Now().UTC().Format(time.RFC3339),
				})
			}
		}
	}

	// Check disk usage
	partitions, err := disk.Partitions(false)
	if err == nil {
		for _, partition := range partitions {
			usage, err := disk.Usage(partition.Mountpoint)
			if err != nil {
				continue
			}

			diskUsage := usage.UsedPercent
			if diskUsage > DiskThreshold {
				alertKey := fmt.Sprintf("disk_%s", partition.Mountpoint)
				if shouldSendAlert(alertKey) {
					alerts = append(alerts, Alert{
						AlertType: "threshold",
						Metric:    fmt.Sprintf("disk_%s", partition.Mountpoint),
						Value:     diskUsage,
						Threshold: DiskThreshold,
						Timestamp: time.Now().UTC().Format(time.RFC3339),
					})
				}
			}
		}
	}

	return alerts
}

// shouldSendAlert checks if enough time has passed since last alert (cooldown)
func shouldSendAlert(metric string) bool {
	alertHistory.mu.Lock()
	defer alertHistory.mu.Unlock()

	lastAlert, exists := alertHistory.lastAlerts[metric]
	if !exists || time.Since(lastAlert) > AlertCooldown {
		alertHistory.lastAlerts[metric] = time.Now()
		return true
	}

	return false
}

// sendAlert sends an alert to IBM Cloud Functions
func sendAlert(alert Alert) {
	if alertEndpoint == "" {
		log.Printf("[WARN] Alert endpoint not configured, skipping alert: %s %.2f%% (threshold: %.2f%%)",
			alert.Metric, alert.Value, alert.Threshold)
		return
	}

	// Add server context (could be configured via environment or config file)
	alert.ServerID = "server-001" // TODO: Make this configurable
	alert.ServerName = "production-server"

	// Marshal alert to JSON
	alertJSON, err := json.Marshal(alert)
	if err != nil {
		log.Printf("[ERROR] Failed to marshal alert: %v", err)
		return
	}

	// Send HTTP POST to IBM Cloud Functions
	req, err := http.NewRequest("POST", alertEndpoint, bytes.NewBuffer(alertJSON))
	if err != nil {
		log.Printf("[ERROR] Failed to create alert request: %v", err)
		return
	}

	req.Header.Set("Content-Type", "application/json")
	if monitoringToken != "" {
		req.Header.Set("Authorization", "Bearer "+monitoringToken)
	}

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		log.Printf("[ERROR] Failed to send alert: %v", err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		log.Printf("[INFO] Alert sent successfully: %s %.2f%% (threshold: %.2f%%)",
			alert.Metric, alert.Value, alert.Threshold)
	} else {
		log.Printf("[ERROR] Alert endpoint returned status %d", resp.StatusCode)
	}
}

// TestAlert handles POST /alerts/test - sends a test alert
func TestAlert(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	testAlert := Alert{
		ServerID:   "server-001",
		ServerName: "production-server",
		AlertType:  "test",
		Metric:     "test",
		Value:      99.9,
		Threshold:  85.0,
		Timestamp:  time.Now().UTC().Format(time.RFC3339),
	}

	sendAlert(testAlert)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status":  "success",
		"message": "Test alert sent",
	})
}

// GetAlertHistory returns recent alert history
func GetAlertHistory(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	alertHistory.mu.Lock()
	defer alertHistory.mu.Unlock()

	history := make(map[string]string)
	for metric, timestamp := range alertHistory.lastAlerts {
		history[metric] = timestamp.Format(time.RFC3339)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"history": history,
		"count":   len(history),
	})
}

// Made with Bob
