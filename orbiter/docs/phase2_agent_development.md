# Phase 2: Go Agent Development

**Goal:** Build the lightweight Go agent that runs on the server and exposes metrics/control APIs.

---

## 2.1 Agent Core Setup

### Create main.go

**Tasks:**
- [ ] Set up HTTP server on localhost:7433
- [ ] Parse CLI arguments (--port, --token, --alert-endpoint)
- [ ] Implement token-based authentication middleware
- [ ] Add health check endpoint: `GET /health`
- [ ] Implement graceful shutdown
- [ ] Add structured logging

**CLI Usage:**
```bash
./agent --port 7433 --token <session_token> --alert-endpoint <ibm-cloud-function-url>
```

**Health Check Response:**
```json
{
  "status": "ok",
  "version": "1.0.0",
  "uptime": 3600
}
```

---

## 2.2 Metrics Collection (WebSocket)

### Create api/metrics.go

**Tasks:**
- [ ] Implement CPU usage collector (total + per-core)
- [ ] Implement RAM usage collector (used, cached, buffers, swap)
- [ ] Implement disk usage collector (per mount, IOPS)
- [ ] Implement network usage collector (in/out bandwidth)
- [ ] Implement uptime and load average
- [ ] Create WebSocket endpoint: `WS /metrics`
- [ ] Stream metrics every 1 second

**Metrics JSON Format:**
```json
{
  "timestamp": "2026-05-03T00:00:00Z",
  "cpu": {
    "total": 45.2,
    "cores": [42.1, 48.3, 44.5, 46.0],
    "loadAverage": [1.2, 1.5, 1.8]
  },
  "ram": {
    "total": 4096,
    "used": 2048,
    "cached": 512,
    "buffers": 256,
    "swap": 1024
  },
  "disk": [
    {
      "mount": "/",
      "total": 80000,
      "used": 45000,
      "readIOPS": 120,
      "writeIOPS": 80
    }
  ],
  "network": {
    "bytesIn": 1024000,
    "bytesOut": 512000
  },
  "uptime": 86400
}
```

**Go Libraries:**
- `github.com/shirou/gopsutil/v3` for system metrics
- `github.com/gorilla/websocket` for WebSocket

---

## 2.3 Service Management API

### Create api/services.go

**Tasks:**
- [ ] List systemd services: `systemctl list-units --type=service`
- [ ] List Docker containers: `docker ps -a`
- [ ] Create unified endpoint: `GET /services`
- [ ] Implement service control: `POST /services/{name}/start|stop|restart`
- [ ] Add service resource usage (CPU, RAM per service)

**Service JSON Format:**
```json
{
  "services": [
    {
      "name": "nginx",
      "type": "systemd",
      "status": "running",
      "cpu": 2.5,
      "memory": 45000000,
      "uptime": 3600
    },
    {
      "name": "webapp",
      "type": "docker",
      "status": "running",
      "containerId": "abc123",
      "image": "webapp:latest"
    }
  ]
}
```

---

## 2.4 Log Streaming (WebSocket)

### Create api/logs.go

**Tasks:**
- [ ] Implement log file tail: `tail -f /path/to/log`
- [ ] Create WebSocket endpoint: `WS /logs?path=/var/log/nginx/error.log`
- [ ] Support systemd journal: `journalctl -u nginx -f`
- [ ] Add log filtering by keyword
- [ ] Implement log level detection (ERROR, WARN, INFO)

**Log Stream Format:**
```json
{
  "timestamp": "2026-05-03T00:00:00Z",
  "source": "/var/log/nginx/error.log",
  "level": "ERROR",
  "message": "Connection refused to upstream"
}
```

---

## 2.5 Process Management API

### Create api/processes.go

**Tasks:**
- [ ] List processes: `GET /processes`
- [ ] Sort by CPU or RAM usage
- [ ] Kill process: `POST /processes/{pid}/kill`
- [ ] Add process search by name

**Process JSON Format:**
```json
{
  "processes": [
    {
      "pid": 1234,
      "name": "nginx",
      "user": "www-data",
      "cpu": 5.2,
      "memory": 45000000,
      "command": "nginx: master process"
    }
  ]
}
```

---

## 2.6 Shell Command Execution (WebSocket)

### Create api/exec.go

**Tasks:**
- [ ] Create WebSocket endpoint: `WS /exec`
- [ ] Execute commands and stream output
- [ ] Support interactive commands (stdin/stdout/stderr)
- [ ] Implement command timeout (30 seconds default)
- [ ] Log all executed commands for security

**Security:**
- Commands run with agent's user permissions
- No automatic privilege escalation
- Log all commands with timestamps

---

## 2.7 File Operations API

### Create api/files.go

**Tasks:**
- [ ] File browser: `GET /files?path=/path/to/dir`
- [ ] File reader: `GET /files/read?path=/path/to/file`
- [ ] File writer: `POST /files/write`
- [ ] Permission checks before operations
- [ ] File size limits (10MB max for safety)

---

## 2.8 Cron Management API

### Create api/cron.go

**Tasks:**
- [ ] Read crontab: `GET /cron`
- [ ] Parse cron expressions to human-readable
- [ ] Write crontab: `POST /cron`
- [ ] Validate cron expressions

**Cron JSON Format:**
```json
{
  "entries": [
    {
      "expression": "0 3 * * *",
      "command": "/usr/local/bin/backup.sh",
      "description": "Every day at 3:00 AM"
    }
  ]
}
```

---

## 2.9 Alert System

### Create api/alerts.go

**Tasks:**
- [ ] Monitor thresholds (CPU > 85%, RAM > 90%, disk > 80%)
- [ ] Send alerts to IBM Cloud Functions: `POST /alerts`
- [ ] Include server context in alert payload
- [ ] Implement cooldown (5 minutes between same alerts)

**Alert Payload:**
```json
{
  "serverId": "server-123",
  "serverName": "production-web",
  "alertType": "threshold",
  "metric": "cpu",
  "value": 92.5,
  "threshold": 85.0,
  "timestamp": "2026-05-03T00:00:00Z",
  "deviceToken": "fcm-token-here"
}
```

---

## 2.10 Build & Distribution

### Create build.sh

**Tasks:**
- [ ] Cross-compile for Linux amd64, arm64, armv7
- [ ] Generate SHA256 checksums
- [ ] Create version.json
- [ ] Upload to IBM Cloud Object Storage

**Build Script:**
```bash
#!/bin/bash
VERSION="1.0.0"

# Build for different architectures
GOOS=linux GOARCH=amd64 go build -o agent-amd64-v$VERSION main.go
GOOS=linux GOARCH=arm64 go build -o agent-arm64-v$VERSION main.go
GOOS=linux GOARCH=arm GOARM=7 go build -o agent-armv7-v$VERSION main.go

# Generate checksums
sha256sum agent-* > checksums.sha256

# Create version file
echo "{\"version\": \"$VERSION\"}" > version.json

# Upload to IBM Cloud Object Storage (add your upload commands)
```

---

## Phase 2 Checklist

- [ ] Agent compiles for all architectures (amd64, arm64, armv7)
- [ ] Health check endpoint working
- [ ] Metrics streaming via WebSocket
- [ ] Can list and control services
- [ ] Can stream logs from files and systemd
- [ ] Can list and kill processes
- [ ] Can execute shell commands
- [ ] File operations working
- [ ] Cron management working
- [ ] Alert system functional
- [ ] Binaries uploaded to IBM Cloud Object Storage

**Demo:** Run agent on server, connect via curl, stream metrics, control services.

**Next:** Phase 3 - Build Flutter app that connects to the agent.