# Phase 3: Flutter App with Live Dashboard

**Goal:** Build Flutter app that connects to agent and displays live metrics.

---

## 3.1 Agent Bootstrap Flow

### Create Agent Bootstrapper (lib/core/agent/agent_bootstrapper.dart)

**Tasks:**
- [ ] Detect server architecture: `uname -m`
- [ ] Check if agent exists: `test -f ~/.orbiter/agent && ~/.orbiter/agent --version`
- [ ] Download agent from IBM Cloud Object Storage if needed
- [ ] Transfer binary via SFTP to `~/.orbiter/agent.tmp`
- [ ] Make executable: `chmod +x ~/.orbiter/agent.tmp && mv ~/.orbiter/agent.tmp ~/.orbiter/agent`
- [ ] Launch agent: `nohup ~/.orbiter/agent --port 7433 --token <token> > ~/.orbiter/agent.log 2>&1 &`
- [ ] Open SSH tunnel: `localhost:7433 → remote:7433`
- [ ] Health check: `GET http://127.0.0.1:7433/health`

**Bootstrap Sequence:**
```dart
class AgentBootstrapper {
  Future<void> bootstrap(SSHSession session) async {
    // 1. Detect architecture
    final arch = await detectArchitecture(session);
    
    // 2. Check agent version
    final needsUpdate = await checkAgentVersion(session);
    
    if (needsUpdate) {
      // 3. Download from IBM Cloud Object Storage
      final binary = await downloadAgent(arch);
      
      // 4. Transfer via SFTP
      await transferAgent(session, binary);
      
      // 5. Install
      await installAgent(session);
    }
    
    // 6. Launch agent
    await launchAgent(session);
    
    // 7. Open tunnel
    await openTunnel(session);
    
    // 8. Health check
    await healthCheck();
  }
}
```

---

## 3.2 Live Dashboard UI

### Create Dashboard Screen (lib/features/dashboard/dashboard_screen.dart)

**Tasks:**
- [ ] Create dashboard layout with metric cards
- [ ] Connect to agent WebSocket: `ws://127.0.0.1:7433/metrics`
- [ ] Parse and display real-time metrics
- [ ] Implement CPU circular gauge
- [ ] Implement RAM progress bar
- [ ] Implement disk usage rings
- [ ] Implement network in/out display
- [ ] Add sparkline charts for history (last 1 hour)
- [ ] Store metrics locally for 24-hour history
- [ ] Implement pull-to-refresh

**Metric Cards:**
```dart
// CPU Card
CircularGauge(
  value: metrics.cpu.total,
  label: 'CPU',
  color: getStatusColor(metrics.cpu.total),
)

// RAM Card
LinearProgressBar(
  value: metrics.ram.used / metrics.ram.total,
  label: 'RAM: ${metrics.ram.used}MB / ${metrics.ram.total}MB',
)

// Disk Card (per mount)
for (var disk in metrics.disks)
  DiskRing(
    mount: disk.mount,
    used: disk.used,
    total: disk.total,
  )
```

---

## 3.3 Services Management UI

### Create Services Screen (lib/features/services/services_screen.dart)

**Tasks:**
- [ ] Fetch services: `GET http://127.0.0.1:7433/services`
- [ ] Display unified systemd + Docker list
- [ ] Color-coded status (green=running, red=stopped, yellow=degraded)
- [ ] Add start/stop/restart buttons
- [ ] Show CPU and RAM per service
- [ ] Implement search/filter
- [ ] Add "View Logs" button per service

**Service Card UI:**
```dart
ServiceCard(
  name: service.name,
  type: service.type, // systemd or docker
  status: service.status,
  cpu: service.cpu,
  memory: service.memory,
  onStart: () => controlService(service.name, 'start'),
  onStop: () => controlService(service.name, 'stop'),
  onRestart: () => controlService(service.name, 'restart'),
  onViewLogs: () => navigateToLogs(service.name),
)
```

---

## 3.4 Log Viewer UI

### Create Log Viewer Screen (lib/features/logs/log_viewer_screen.dart)

**Tasks:**
- [ ] Connect to WebSocket: `ws://127.0.0.1:7433/logs?path=/var/log/nginx/error.log`
- [ ] Display logs with syntax highlighting
- [ ] Auto-scroll to bottom
- [ ] Implement search/filter
- [ ] Add log level filtering (ERROR, WARN, INFO)
- [ ] Color-code log levels
- [ ] Add "Copy" button for log lines
- [ ] Support systemd journal logs

**Log Display:**
```dart
LogViewer(
  stream: logStream,
  highlightErrors: true,
  autoScroll: true,
  searchQuery: searchController.text,
  levelFilter: selectedLevel, // ERROR, WARN, INFO, ALL
)
```

---

## 3.5 Process Manager UI

### Create Process List Screen (lib/features/processes/process_list_screen.dart)

**Tasks:**
- [ ] Fetch processes: `GET http://127.0.0.1:7433/processes`
- [ ] Display top-style list
- [ ] Sort by CPU or RAM
- [ ] Implement search
- [ ] Add "Kill Process" with confirmation
- [ ] Show PID, user, CPU%, MEM%, command
- [ ] Implement pull-to-refresh

**Process List:**
```dart
ProcessList(
  processes: processes,
  sortBy: sortBy, // cpu or memory
  onKill: (pid) => showKillConfirmation(pid),
  searchQuery: searchController.text,
)
```

---

## 3.6 State Management

### Create Providers (lib/core/providers/)

**Tasks:**
- [ ] Create metrics provider (StreamProvider)
- [ ] Create services provider (FutureProvider)
- [ ] Create logs provider (StreamProvider)
- [ ] Create processes provider (FutureProvider)
- [ ] Implement error handling
- [ ] Add retry logic
- [ ] Implement offline mode detection

**Example Providers:**
```dart
final metricsProvider = StreamProvider<MetricsSnapshot>((ref) {
  final websocket = ref.watch(websocketServiceProvider);
  return websocket.metricsStream;
});

final servicesProvider = FutureProvider<List<Service>>((ref) async {
  final api = ref.watch(agentApiProvider);
  return api.getServices();
});
```

---

## 3.7 Navigation

### Create App Navigation (lib/main.dart)

**Tasks:**
- [ ] Implement bottom navigation bar
- [ ] Create routes for all screens
- [ ] Add server switcher in app bar
- [ ] Implement drawer for settings
- [ ] Add "Disconnect" button

**Bottom Navigation:**
```dart
BottomNavigationBar(
  items: [
    BottomNavigationBarItem(icon: Icons.dashboard, label: 'Dashboard'),
    BottomNavigationBarItem(icon: Icons.dns, label: 'Services'),
    BottomNavigationBarItem(icon: Icons.article, label: 'Logs'),
    BottomNavigationBarItem(icon: Icons.terminal, label: 'Terminal'),
    BottomNavigationBarItem(icon: Icons.more_horiz, label: 'More'),
  ],
)
```

---

## 3.8 WebSocket Connection Manager

### Create WebSocket Service (lib/core/websocket/websocket_service.dart)

**Tasks:**
- [ ] Manage WebSocket connections
- [ ] Handle reconnection on disconnect
- [ ] Parse incoming messages
- [ ] Implement error handling
- [ ] Add connection state tracking

**WebSocket Manager:**
```dart
class WebSocketService {
  Stream<MetricsSnapshot> get metricsStream;
  Stream<LogEntry> get logsStream;
  
  Future<void> connect(String url);
  Future<void> disconnect();
  void sendMessage(String message);
}
```

---

## Phase 3 Checklist

- [ ] Agent auto-installs on first connection
- [ ] Dashboard shows live metrics (1s refresh)
- [ ] Can view and control services
- [ ] Can view and search logs
- [ ] Can view and kill processes
- [ ] Terminal integrated and working
- [ ] Navigation smooth between screens
- [ ] WebSocket connections stable
- [ ] Handles connection errors gracefully
- [ ] Offline mode detected

**Demo:** Connect to server, show live dashboard, control nginx service, view logs, kill a process.

**Next:** Phase 4 - Integrate IBM Cloud services (watsonx.ai, Cloud Functions, push notifications).