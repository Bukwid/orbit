package websocket

import (
	"log"
	"net/http"
	"time"

	"github.com/shirou/gopsutil/v3/cpu"
	"github.com/shirou/gopsutil/v3/disk"
	"github.com/shirou/gopsutil/v3/mem"
)

// MetricsSnapshot represents system metrics at a point in time
type MetricsSnapshot struct {
	Timestamp   string  `json:"timestamp"`
	CPUUsage    float64 `json:"cpuUsage"`
	MemoryUsage float64 `json:"memoryUsage"`
	DiskUsage   float64 `json:"diskUsage"`
	LoadAvg     float64 `json:"loadAvg"`
}

// ServeMetrics handles WebSocket connections for real-time metrics streaming
func ServeMetrics(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("[ERROR] WebSocket upgrade failed: %v", err)
		return
	}
	defer conn.Close()

	log.Printf("[INFO] Metrics WebSocket connected from %s", r.RemoteAddr)

	// Send metrics every 2 seconds
	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			metrics, err := collectMetrics()
			if err != nil {
				log.Printf("[ERROR] Failed to collect metrics: %v", err)
				continue
			}

			if err := conn.WriteJSON(metrics); err != nil {
				log.Printf("[ERROR] Failed to send metrics: %v", err)
				return
			}
		}
	}
}

// collectMetrics gathers current system metrics
func collectMetrics() (*MetricsSnapshot, error) {
	// CPU usage
	cpuPercent, err := cpu.Percent(time.Second, false)
	if err != nil {
		return nil, err
	}
	cpuUsage := 0.0
	if len(cpuPercent) > 0 {
		cpuUsage = cpuPercent[0]
	}

	// Memory usage
	memInfo, err := mem.VirtualMemory()
	if err != nil {
		return nil, err
	}

	// Disk usage
	diskInfo, err := disk.Usage("/")
	if err != nil {
		return nil, err
	}

	// Load average (CPU load)
	loadAvg := cpuUsage / 100.0

	return &MetricsSnapshot{
		Timestamp:   time.Now().UTC().Format(time.RFC3339),
		CPUUsage:    cpuUsage,
		MemoryUsage: memInfo.UsedPercent,
		DiskUsage:   diskInfo.UsedPercent,
		LoadAvg:     loadAvg,
	}, nil
}

// Made with Bob