package main

import (
	"context"
	"encoding/json"
	"flag"
	"log"
	"net/http"
	"orbiter-agent/api"
	"orbiter-agent/websocket"
	"os"
	"os/signal"
	"syscall"
	"time"
)

const version = "1.0.0"

var (
	port          string
	token         string
	alertEndpoint string
	startTime     time.Time
)

// HealthResponse represents the health check response
type HealthResponse struct {
	Status  string `json:"status"`
	Version string `json:"version"`
	Uptime  int64  `json:"uptime"`
}

func main() {
	// Parse CLI arguments
	flag.StringVar(&port, "port", "7433", "Port to listen on")
	flag.StringVar(&token, "token", "", "Authentication token (required)")
	flag.StringVar(&alertEndpoint, "alert-endpoint", "", "IBM Cloud Functions alert endpoint URL")
	flag.Parse()

	// Validate required arguments
	if token == "" {
		log.Fatal("Error: --token is required")
	}

	startTime = time.Now()

	// Structured logging
	log.SetFlags(log.LstdFlags | log.Lshortfile)
	log.Printf("[INFO] Orbiter Agent v%s starting...", version)
	log.Printf("[INFO] Port: %s", port)
	log.Printf("[INFO] Alert Endpoint: %s", alertEndpoint)

	// Initialize WebSocket hub
	hub := websocket.NewHub()
	go hub.Run()

	// Create HTTP server with authentication middleware
	mux := http.NewServeMux()

	// Health check endpoint (no auth required)
	mux.HandleFunc("/health", healthCheckHandler)

	// Protected API routes with authentication
	mux.HandleFunc("/api/metrics", authMiddleware(api.GetMetrics))
	mux.HandleFunc("/api/logs", authMiddleware(api.GetLogs))
	mux.HandleFunc("/api/services", authMiddleware(api.GetServices))
	mux.HandleFunc("/api/services/", authMiddleware(api.ControlService))
	mux.HandleFunc("/api/exec", authMiddleware(api.ExecuteCommand))
	mux.HandleFunc("/api/files", authMiddleware(api.GetFiles))
	mux.HandleFunc("/api/processes", authMiddleware(api.GetProcesses))
	mux.HandleFunc("/api/processes/", authMiddleware(api.KillProcess))
	mux.HandleFunc("/api/cron", authMiddleware(api.GetCronJobs))
	mux.HandleFunc("/api/alerts", authMiddleware(api.GetAlerts))

	// WebSocket endpoints with authentication
	mux.HandleFunc("/ws", authMiddleware(func(w http.ResponseWriter, r *http.Request) {
		websocket.ServeWs(hub, w, r)
	}))
	mux.HandleFunc("/ws/metrics", authMiddleware(func(w http.ResponseWriter, r *http.Request) {
		websocket.ServeMetrics(w, r)
	}))

	// Create server
	server := &http.Server{
		Addr:         ":" + port,
		Handler:      corsMiddleware(mux),
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Start server in a goroutine
	go func() {
		log.Printf("[INFO] Server listening on port %s", port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("[ERROR] Server failed to start: %v", err)
		}
	}()

	// Initialize alert monitoring if endpoint is provided
	if alertEndpoint != "" {
		go api.StartAlertMonitoring(alertEndpoint, token)
		log.Printf("[INFO] Alert monitoring started")
	}

	// Graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("[INFO] Shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Printf("[ERROR] Server forced to shutdown: %v", err)
	}

	log.Println("[INFO] Server exited")
}

func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type")
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}
		next.ServeHTTP(w, r)
	})
}

// healthCheckHandler handles the /health endpoint
func healthCheckHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	uptime := int64(time.Since(startTime).Seconds())
	response := HealthResponse{
		Status:  "ok",
		Version: version,
		Uptime:  uptime,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
	log.Printf("[INFO] Health check requested - Uptime: %ds", uptime)
}

// authMiddleware validates the authentication token
func authMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			log.Printf("[WARN] Unauthorized request from %s - No token provided", r.RemoteAddr)
			http.Error(w, "Unauthorized: No token provided", http.StatusUnauthorized)
			return
		}

		// Expected format: "Bearer <token>"
		expectedAuth := "Bearer " + token
		if authHeader != expectedAuth {
			log.Printf("[WARN] Unauthorized request from %s - Invalid token", r.RemoteAddr)
			http.Error(w, "Unauthorized: Invalid token", http.StatusUnauthorized)
			return
		}

		log.Printf("[INFO] Authenticated request: %s %s from %s", r.Method, r.URL.Path, r.RemoteAddr)
		next(w, r)
	}
}

// Made with Bob
