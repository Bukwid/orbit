package api

import (
	"encoding/json"
	"log"
	"net/http"
	"time"

	"github.com/gorilla/websocket"
	"github.com/shirou/gopsutil/v3/cpu"
	"github.com/shirou/gopsutil/v3/disk"
	"github.com/shirou/gopsutil/v3/host"
	"github.com/shirou/gopsutil/v3/load"
	"github.com/shirou/gopsutil/v3/mem"
	"github.com/shirou/gopsutil/v3/net"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true // Allow all origins for development
	},
}

// CPUMetrics represents CPU usage information
type CPUMetrics struct {
	Total       float64   `json:"total"`
	Cores       []float64 `json:"cores"`
	LoadAverage []float64 `json:"loadAverage"`
}

// RAMMetrics represents RAM usage information
type RAMMetrics struct {
	Total   uint64 `json:"total"`
	Used    uint64 `json:"used"`
	Cached  uint64 `json:"cached"`
	Buffers uint64 `json:"buffers"`
	Swap    uint64 `json:"swap"`
}

// DiskMetrics represents disk usage for a mount point
type DiskMetrics struct {
	Mount     string  `json:"mount"`
	Total     uint64  `json:"total"`
	Used      uint64  `json:"used"`
	ReadIOPS  uint64  `json:"readIOPS"`
	WriteIOPS uint64  `json:"writeIOPS"`
}

// NetworkMetrics represents network usage
type NetworkMetrics struct {
	BytesIn  uint64 `json:"bytesIn"`
	BytesOut uint64 `json:"bytesOut"`
}

// MetricsResponse represents the complete metrics response
type MetricsResponse struct {
	Timestamp string           `json:"timestamp"`
	CPU       CPUMetrics       `json:"cpu"`
	RAM       RAMMetrics       `json:"ram"`
	Disk      []DiskMetrics    `json:"disk"`
	Network   NetworkMetrics   `json:"network"`
	Uptime    uint64           `json:"uptime"`
}

// GetMetrics handles HTTP GET requests for metrics (single snapshot)
func GetMetrics(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Check if this is a WebSocket upgrade request
	if r.Header.Get("Upgrade") == "websocket" {
		StreamMetrics(w, r)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	metrics, err := collectMetrics()
	if err != nil {
		log.Printf("[ERROR] Failed to collect metrics: %v", err)
		http.Error(w, "Failed to collect metrics", http.StatusInternalServerError)
		return
	}

	json.NewEncoder(w).Encode(metrics)
}

// StreamMetrics handles WebSocket connections for real-time metrics streaming
func StreamMetrics(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("[ERROR] WebSocket upgrade failed: %v", err)
		return
	}
	defer conn.Close()

	log.Printf("[INFO] Metrics WebSocket connected from %s", r.RemoteAddr)

	ticker := time.NewTicker(1 * time.Second)
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

// collectMetrics gathers all system metrics
func collectMetrics() (*MetricsResponse, error) {
	// CPU metrics
	cpuPercent, err := cpu.Percent(500*time.Millisecond, false)
	if err != nil {
		return nil, err
	}
	cpuTotal := 0.0
	if len(cpuPercent) > 0 {
		cpuTotal = cpuPercent[0]
	}

	cpuPerCore, err := cpu.Percent(500*time.Millisecond, true)
	if err != nil {
		cpuPerCore = []float64{}
	}

	// Load average
	loadAvg, err := load.Avg()
	loadAverage := []float64{0, 0, 0}
	if err == nil {
		loadAverage = []float64{loadAvg.Load1, loadAvg.Load5, loadAvg.Load15}
	}

	// RAM metrics
	memInfo, err := mem.VirtualMemory()
	if err != nil {
		return nil, err
	}

	swapInfo, err := mem.SwapMemory()
	swapUsed := uint64(0)
	if err == nil {
		swapUsed = swapInfo.Used
	}

	// Disk metrics
	partitions, err := disk.Partitions(false)
	diskMetrics := []DiskMetrics{}
	if err == nil {
		for _, partition := range partitions {
			usage, err := disk.Usage(partition.Mountpoint)
			if err != nil {
				continue
			}

			// Get IO stats
			ioCounters, err := disk.IOCounters(partition.Device)
			readIOPS := uint64(0)
			writeIOPS := uint64(0)
			if err == nil {
				if counter, ok := ioCounters[partition.Device]; ok {
					readIOPS = counter.ReadCount
					writeIOPS = counter.WriteCount
				}
			}

			diskMetrics = append(diskMetrics, DiskMetrics{
				Mount:     partition.Mountpoint,
				Total:     usage.Total,
				Used:      usage.Used,
				ReadIOPS:  readIOPS,
				WriteIOPS: writeIOPS,
			})
		}
	}

	// Network metrics
	netIO, err := net.IOCounters(false)
	bytesIn := uint64(0)
	bytesOut := uint64(0)
	if err == nil && len(netIO) > 0 {
		bytesIn = netIO[0].BytesRecv
		bytesOut = netIO[0].BytesSent
	}

	// Uptime
	hostInfo, err := host.Info()
	uptime := uint64(0)
	if err == nil {
		uptime = hostInfo.Uptime
	}

	return &MetricsResponse{
		Timestamp: time.Now().UTC().Format(time.RFC3339),
		CPU: CPUMetrics{
			Total:       cpuTotal,
			Cores:       cpuPerCore,
			LoadAverage: loadAverage,
		},
		RAM: RAMMetrics{
			Total:   memInfo.Total,
			Used:    memInfo.Used,
			Cached:  memInfo.Cached,
			Buffers: memInfo.Buffers,
			Swap:    swapUsed,
		},
		Disk:    diskMetrics,
		Network: NetworkMetrics{
			BytesIn:  bytesIn,
			BytesOut: bytesOut,
		},
		Uptime: uptime,
	}, nil
}

// Made with Bob
