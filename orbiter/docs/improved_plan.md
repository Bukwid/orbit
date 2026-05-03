# Orbiter — Mobile VPS Admin & Migration Pilot
### AI Agent Build Specification (IBM Cloud Enhanced)

---

## 1. Overview

**Orbiter** is a Flutter mobile application that turns your smartphone into a full-featured server administration panel. It connects to any Linux VPS (DigitalOcean, Hostinger, Vultr, Linode, AWS EC2, IBM Cloud Virtual Servers, etc.) via SSH, automatically bootstraps a lightweight agent onto the server on first connect, and exposes real-time metrics, service management, log analysis, **IBM watsonx.ai-powered** natural language control, and a migration planning assistant — all from your phone.

**Core philosophy:** Connecting *is* the setup. The user enters an IP and credentials once. Everything else is automatic.

**IBM Cloud Integration:** Leverages IBM watsonx.ai for AI capabilities, IBM Cloud Functions for serverless operations, and IBM Cloud Object Storage for binary distribution.

---

## 2. Target Users

- Solo developers and freelancers managing personal VPS instances
- Small teams without a dedicated DevOps engineer
- Developers on the go who need to respond to incidents from mobile
- Anyone migrating between VPS providers or cloud platforms
- IBM Cloud customers managing Virtual Servers or Bare Metal instances

---

## 3. Application Architecture

### 3.1 High-Level Architecture (IBM Cloud Enhanced)

```
┌─────────────────────────────────────────────┐
│         Flutter Mobile App                  │
│                                             │
│  ┌──────────┐  ┌──────────────────────────┐│
│  │ SSH Layer│  │  AI Service Layer        ││
│  │(dartssh2 │  │  (IBM watsonx.ai)        ││
│  │ / xterm) │  │  - Granite Models        ││
│  │          │  │  - Llama 3               ││
│  └────┬─────┘  └────────┬─────────────────┘│
└───────┼─────────────────┼───────────────────┘
        │ SSH Tunnel       │ HTTPS
        ▼                  ▼
┌───────────────────┐   ┌──────────────────────┐
│   Orbiter Agent   │   │  IBM watsonx.ai      │
│  (Go binary on    │   │  (us-south region)   │
│   your VPS)       │   │                      │
│                   │   │  - Text Generation   │
│  - Metrics stream │   │  - Prompt Lab        │
│  - Log tailing    │   │  - Foundation Models │
│  - Service ctrl   │   └──────────────────────┘
│  - File manager   │
│  - WebSocket API  │   ┌──────────────────────┐
│                   │   │ IBM Cloud Functions  │
│  Alert triggers ──┼──>│ (Push Relay)         │
└───────────────────┘   └──────┬───────────────┘
                               │
                               ▼
                        ┌──────────────────┐
                        │ FCM / APNs       │
                        │ Push to Device   │
                        └──────────────────┘

Binary Distribution:
┌──────────────────────────────┐
│ IBM Cloud Object Storage     │
│ - agent-amd64-v1.0.0         │
│ - agent-arm64-v1.0.0         │
│ - agent-armv7-v1.0.0         │
│ - SHA256 checksums           │
└──────────────────────────────┘
```

### 3.2 The Orbiter Agent

The agent is a single self-contained Go binary (~8MB) that gets pushed to the server automatically on first SSH connection. It runs as a lightweight daemon and exposes a local WebSocket API that Orbiter tunnels over SSH.

**Why Go:**
- Single static binary, no runtime dependencies
- Cross-compile for any Linux arch (amd64, arm64, arm)
- Low memory footprint (~15MB RAM at idle)
- Native concurrency for streaming metrics

**Agent responsibilities:**
- Expose `/metrics` WebSocket — CPU, RAM, disk, network, uptime
- Expose `/logs` WebSocket — stream and tail any log file
- Expose `/services` REST — list, start, stop, restart systemd/docker services
- Expose `/exec` WebSocket — execute shell commands, stream output
- Expose `/files` REST — browse, read, write files (with permission checks)
- Expose `/processes` REST — list running processes, kill by PID
- Expose `/cron` REST — read and write crontab entries
- Expose `/alerts` POST — trigger alerts to IBM Cloud Functions relay

**Agent communication flow:**
```
App opens SSH connection
  → App checks if agent binary exists at ~/.orbiter/agent
  → If missing: Download from IBM Cloud Object Storage, SCP to server, chmod +x, launch
  → App opens SSH port-forward tunnel: localhost:7433 → 127.0.0.1:7433
  → All subsequent API calls go through this tunnel (never exposed publicly)
  → Agent auto-updates if app version > agent version
```

This is the exact model VSCode Remote SSH uses — the IDE pushes its server binary on first connect, then communicates through an SSH tunnel. No firewall changes, no open ports, no manual configuration.

---

## 4. Feature Specification

### 4.1 Layer 1 — Smart SSH Connection (Build First)

**Server onboarding flow:**
1. User taps "Add Server"
2. Inputs: nickname, IP/hostname, port (default 22), username, auth method (password or private key)
3. App attempts SSH connection
4. On success: checks for existing agent → downloads from IBM Cloud Object Storage if absent
5. Server appears in dashboard with green status indicator

**SSH features:**
- Password and private key authentication (RSA, Ed25519)
- Key import from device file picker or paste
- Support for jump hosts / bastion servers
- Auto-reconnect with exponential backoff on connection drop
- Persistent session management (survive app backgrounding)
- Multi-server support — unlimited servers, quick-switch from sidebar

**Mobile-optimized terminal:**
- Full xterm-compatible terminal using `xterm` Flutter package
- Swipe-up for command history, swipe-right to close
- Persistent keyboard shortcut bar: Tab, Ctrl+C, Ctrl+D, arrow keys, Esc
- Font size pinch-to-zoom
- Copy/paste with long-press
- Dark and light themes

---

### 4.2 Layer 2 — Live Dashboard

Displayed immediately after connecting. All data streams from agent WebSocket.

**Metric cards (real-time, 1s refresh):**

| Metric | Display | Detail on tap |
|---|---|---|
| CPU Usage | Circular gauge + % | Per-core breakdown, load average (1/5/15m) |
| RAM | Used / Total bar | Breakdown: used, cached, buffers, swap |
| Disk | Usage ring per mount | Read/write IOPS, throughput MB/s |
| Network | In/Out bandwidth | Total transferred, packet counts, interface list |
| Uptime | Human-readable | Boot time, last reboot reason |
| Load Average | 1m / 5m / 15m | Sparkline history chart |

**Historical charts:**
- 1 hour sparkline for CPU, RAM, network on the main dashboard
- Tap any metric to expand to full 24h chart
- Data stored locally on device (agent streams live, app persists history)
- Optional: Sync to IBM Cloudant for cross-device access (post-hackathon)

**Services panel:**
- Lists all systemd services + Docker containers in unified view
- Color-coded status: green (running), red (stopped), yellow (degraded)
- One-tap: start / stop / restart / view logs
- Search/filter by name
- Shows memory and CPU usage per service

**Process list:**
- Top-style live process list sorted by CPU or RAM
- Pull-to-refresh
- Long-press a process to kill it (with confirmation)
- Search by process name

---

### 4.3 Layer 3 — Alerting & Incident Intelligence

**Threshold alerts:**
- User sets thresholds per server: e.g., CPU > 85%, RAM > 90%, disk > 80%
- Push notifications via **IBM Cloud Functions** relay → FCM/APNs
- Agent POSTs alert to IBM Cloud Functions endpoint
- Cloud Function forwards to device via FCM
- In-app alert center with history and timestamps
- Silence alerts per server for a defined period

**Alert flow:**
```
Agent detects threshold breach
  → POST to IBM Cloud Functions endpoint
  → Function validates request
  → Function sends push via FCM
  → User receives notification
  → Tap notification → opens Orbiter to affected server
```

**Cron manager:**
- Visual cron expression editor (no memorizing `* * * * *` syntax)
- Reads existing crontab and displays in human-readable format: "Every day at 3:00 AM"
- Add / edit / delete entries with picker UI
- Writes back to crontab via agent

**Incident Timeline (auto-generated):**
- When a crash or anomaly is detected, Orbiter automatically correlates:
  - Metric spikes leading up to the event
  - Relevant log lines from all services around that time window
  - Service state changes
- Presents as a readable chronological story:
  ```
  01:47:03  RAM usage crossed 90% threshold
  01:48:51  Swap space exhausted
  01:49:12  nginx worker process OOM-killed (PID 3847)
  01:49:13  Service nginx entered failed state
  01:49:14  ⚠ Orbiter alert sent
  ```
- Timeline is exportable as plain text

---

### 4.4 Layer 4 — AI Features (IBM watsonx.ai Powered)

All AI features use **IBM watsonx.ai** with foundation models. The app sends relevant context (metrics, logs, config snippets) alongside user queries. No raw log data is sent without user awareness.

**Available Models:**
- `ibm/granite-13b-chat-v2` — General purpose, fast responses
- `meta-llama/llama-3-70b-instruct` — Complex reasoning, migration planning
- `ibm/granite-20b-code-instruct` — Code analysis and generation

#### 4.4a Natural Language Terminal

User types or speaks a command in plain English. App translates to shell command using watsonx.ai, shows the command for review, executes on approval.

```
User:  "restart nginx and show me the last 20 lines of its error log"
Orbiter: → systemctl restart nginx && tail -20 /var/log/nginx/error.log
       [Run] [Edit] [Cancel]
```

**Implementation:**
```dart
class WatsonxCommandTranslator {
  Future<String> translateCommand(String naturalLanguage, ServerContext context) async {
    final prompt = '''
You are a Linux system administrator assistant. Convert natural language to shell commands.

Server context:
- OS: ${context.os}
- Installed services: ${context.services.join(', ')}
- Current directory: ${context.currentDir}

User request: "$naturalLanguage"

Respond with ONLY the shell command, no explanation.
''';
    
    final response = await watsonxClient.generateText(
      modelId: 'ibm/granite-13b-chat-v2',
      input: prompt,
      parameters: {
        'max_new_tokens': 100,
        'temperature': 0.3,
      }
    );
    
    return response.generatedText.trim();
  }
}
```

- Commands always shown before execution — user is never bypassed
- AI has context of current server state (OS, installed services, directory)
- Dangerous commands (rm -rf, format, drop database) require explicit confirmation with typed "CONFIRM"

#### 4.4b Log Analysis

- User taps any log file or service log → watsonx.ai summarizes in plain English
- "What's causing these errors?" → AI reads last N lines, identifies patterns, explains root cause
- Proactive: when CPU/RAM spikes, AI automatically analyzes logs from that time window and pushes a summary notification

Example output:
```
Your MySQL process is using 3.1GB RAM (78% of total). 
This is caused by innodb_buffer_pool_size being set to 
3G in /etc/mysql/mysql.conf.d/mysqld.cnf — it's consuming 
all available memory. Recommended fix: reduce to 512M for 
a 4GB server. Want me to apply this change?
```

**Implementation:**
```dart
class WatsonxLogAnalyzer {
  Future<LogAnalysis> analyzeLog(String logContent, MetricsSnapshot metrics) async {
    final prompt = '''
Analyze this server log and current metrics to identify issues:

Current Metrics:
- CPU: ${metrics.cpu}%
- RAM: ${metrics.ram}% (${metrics.ramUsed}/${metrics.ramTotal})
- Disk: ${metrics.disk}%

Recent Log Lines:
$logContent

Provide:
1. Root cause analysis
2. Specific configuration issues
3. Recommended fixes with exact commands
''';
    
    final response = await watsonxClient.generateText(
      modelId: 'ibm/granite-13b-chat-v2',
      input: prompt,
      parameters: {
        'max_new_tokens': 500,
        'temperature': 0.5,
      }
    );
    
    return LogAnalysis.fromText(response.generatedText);
  }
}
```

#### 4.4c "Why is my server slow?" Mode

One-tap holistic diagnosis. watsonx.ai receives full metrics snapshot + recent logs and produces a prioritized explanation with suggested fixes.

#### 4.4d MigrationPilot — Server Migration Assistant (watsonx.ai Powered)

This is the feature that separates Orbiter from every competitor.

**What it does:**
Reads your current server's complete configuration and generates a step-by-step migration plan to any target environment using **IBM watsonx.ai's Llama 3 70B model** for complex reasoning.

**What it scans:**
- Installed packages (`dpkg --get-selections` / `rpm -qa`)
- Running services (systemd units + Docker containers + images)
- Nginx / Apache / Caddy site configs
- MySQL / PostgreSQL databases (names, sizes, users — no data)
- Environment files (`.env` — user can redact sensitive values)
- Crontab entries
- Firewall rules (`ufw status` / `iptables -L`)
- Custom scripts in common locations

**Output format:**
A structured migration plan in three sections:

```markdown
## Phase 1: Provision & Baseline (Target Server)
- [ ] Create new VPS (recommended spec: 2 vCPU / 4GB RAM / 80GB SSD)
- [ ] SSH in, run initial hardening script (generated below)
- [ ] Install required packages: nginx, mysql-server, php8.2-fpm, certbot

## Phase 2: Migrate Services
- [ ] Export MySQL databases: [generated mysqldump commands]
- [ ] Copy nginx site configs: [generated rsync commands]
- [ ] Transfer application files: [generated rsync with exclusions]
- [ ] Restore databases on target: [generated restore commands]

## Phase 3: Cutover
- [ ] Update DNS A record for yourdomain.com → [new IP]
- [ ] Verify SSL certificates: [certbot commands]
- [ ] Run smoke tests: [generated curl test commands]
- [ ] Decommission old server after 48h monitoring window
```

**Implementation:**
```dart
class WatsonxMigrationPlanner {
  Future<MigrationPlan> generatePlan(ServerConfig config, String targetProvider) async {
    final prompt = '''
You are a DevOps expert. Generate a detailed server migration plan.

Source Server Configuration:
${config.toJson()}

Target: $targetProvider

Generate a structured migration plan with:
1. Phase 1: Provision & Baseline
2. Phase 2: Migrate Services
3. Phase 3: Cutover

Include exact commands, estimated times, and validation steps.
Format as markdown with checkboxes.
''';
    
    final response = await watsonxClient.generateText(
      modelId: 'meta-llama/llama-3-70b-instruct',
      input: prompt,
      parameters: {
        'max_new_tokens': 2000,
        'temperature': 0.7,
      }
    );
    
    return MigrationPlan.fromMarkdown(response.generatedText);
  }
}
```

- User can connect the **target server** to Orbiter simultaneously, and execute each phase step directly from the app
- AI validates each step's success before moving to the next
- Generates all bash scripts needed — no manual command lookup

---

## 5. Technical Stack

### 5.1 Flutter App

```
lib/
├── main.dart
├── core/
│   ├── ssh/           # SSH connection management (dartssh2)
│   ├── agent/         # Agent install, version check, binary transfer
│   ├── websocket/     # Metrics and log streaming
│   ├── storage/       # Encrypted local storage (flutter_secure_storage)
│   └── ibm/           # IBM Cloud service integrations
│       ├── watsonx_client.dart
│       ├── cloud_functions_client.dart
│       └── object_storage_client.dart
├── features/
│   ├── servers/       # Server list, add/edit/remove
│   ├── dashboard/     # Live metrics dashboard
│   ├── terminal/      # xterm terminal emulator
│   ├── services/      # Systemd + Docker service manager
│   ├── logs/          # Log viewer + AI analysis
│   ├── alerts/        # Alert config, history, push notifications
│   ├── cron/          # Cron manager UI
│   ├── migration/     # MigrationPilot UI and flow
│   └── ai/            # Natural language command interface
├── shared/
│   ├── widgets/       # Reusable UI components
│   └── theme/         # Dark/light theme tokens
```

**Key Flutter packages:**

| Package | Purpose |
|---|---|
| `dartssh2` | SSH client (pure Dart, no native code needed) |
| `xterm` | Terminal emulator widget |
| `fl_chart` | Metrics charts and sparklines |
| `flutter_secure_storage` | Encrypted key storage |
| `riverpod` | State management |
| `dio` | HTTP client for agent REST API and IBM Cloud APIs |
| `web_socket_channel` | WebSocket for metrics streaming |
| `firebase_messaging` | Push notifications (FCM) |
| `file_picker` | SSH key import |

### 5.2 Orbiter Agent (Go)

```
agent/
├── main.go
├── api/
│   ├── metrics.go     # CPU, RAM, disk, network collectors
│   ├── logs.go        # Log file streaming
│   ├── services.go    # systemd + docker control
│   ├── exec.go        # Shell command execution
│   ├── files.go       # File system operations
│   ├── processes.go   # Process list + kill
│   ├── cron.go        # Crontab read/write
│   └── alerts.go      # Alert triggers to IBM Cloud Functions
├── websocket/
│   └── hub.go         # WebSocket connection manager
└── build.sh           # Cross-compile for amd64, arm64, arm
```

**Agent startup:**
```bash
# App uploads binary via SCP then runs:
nohup ~/.orbiter/agent --port 7433 --token <session_token> --alert-endpoint <ibm-cloud-function-url> > ~/.orbiter/agent.log 2>&1 &
```

The session token is generated per-connection and passed by the app. The agent only accepts connections with a valid token, preventing any local process from hijacking it.

### 5.3 IBM Cloud Infrastructure

#### 5.3.1 IBM watsonx.ai Configuration

```yaml
Service: IBM watsonx.ai
Region: us-south (or closest to users)
Models:
  - ibm/granite-13b-chat-v2 (command translation, log analysis)
  - meta-llama/llama-3-70b-instruct (migration planning)
  - ibm/granite-20b-code-instruct (code analysis)

Authentication: IBM Cloud IAM API Key
Endpoint: https://us-south.ml.cloud.ibm.com/ml/v1/text/generation
```

**Cost Estimation:**
- Input tokens: ~$0.50 per 1M tokens
- Output tokens: ~$1.50 per 1M tokens
- Estimated monthly (moderate usage): $10-40

#### 5.3.2 IBM Cloud Functions (Push Notification Relay)

```javascript
// IBM Cloud Functions - Push Relay
// File: push-relay.js

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.cert({
    projectId: process.env.FIREBASE_PROJECT_ID,
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n')
  })
});

async function main(params) {
  const { serverId, serverName, alertType, message, deviceToken } = params;
  
  // Validate required parameters
  if (!deviceToken || !message) {
    return {
      statusCode: 400,
      body: { error: 'Missing required parameters' }
    };
  }
  
  // Send push notification via FCM
  const notification = {
    notification: {
      title: `⚠️ ${serverName || 'Server'} Alert`,
      body: message
    },
    data: {
      serverId: serverId || '',
      alertType: alertType || 'threshold',
      timestamp: new Date().toISOString()
    },
    token: deviceToken
  };
  
  try {
    const response = await admin.messaging().send(notification);
    return {
      statusCode: 200,
      body: { 
        success: true, 
        messageId: response 
      }
    };
  } catch (error) {
    console.error('FCM Error:', error);
    return {
      statusCode: 500,
      body: { 
        error: 'Failed to send notification',
        details: error.message 
      }
    };
  }
}

exports.main = main;
```

**Deployment:**
```bash
# Deploy to IBM Cloud Functions
ibmcloud fn action create orbiter-push-relay push-relay.js \
  --kind nodejs:18 \
  --web true \
  --param FIREBASE_PROJECT_ID "your-project-id" \
  --param FIREBASE_CLIENT_EMAIL "your-client-email" \
  --param FIREBASE_PRIVATE_KEY "your-private-key"

# Get endpoint URL
ibmcloud fn action get orbiter-push-relay --url
```

**Cost:** Free tier includes 400,000 GB-seconds per month (more than sufficient)

#### 5.3.3 IBM Cloud Object Storage (Binary Distribution)

```yaml
Service: IBM Cloud Object Storage
Region: us-south (with global CDN)
Bucket: orbiter-agent-binaries
Access: Public read, private write

Files:
  - agent-amd64-v1.0.0 (Linux x86_64)
  - agent-arm64-v1.0.0 (Linux ARM64)
  - agent-armv7-v1.0.0 (Linux ARMv7)
  - checksums.sha256 (verification)
  - version.json (latest version info)
```

**Flutter Integration:**
```dart
class IBMObjectStorageClient {
  final String bucketUrl = 'https://orbiter-agent-binaries.s3.us-south.cloud-object-storage.appdomain.cloud';
  
  Future<AgentBinary> downloadAgent(String architecture) async {
    // Get latest version
    final versionResponse = await dio.get('$bucketUrl/version.json');
    final version = versionResponse.data['version'];
    
    // Download binary
    final binaryUrl = '$bucketUrl/agent-$architecture-v$version';
    final response = await dio.get(
      binaryUrl,
      options: Options(responseType: ResponseType.bytes)
    );
    
    // Verify checksum
    final checksumResponse = await dio.get('$bucketUrl/checksums.sha256');
    final expectedChecksum = _parseChecksum(checksumResponse.data, architecture, version);
    final actualChecksum = sha256.convert(response.data).toString();
    
    if (actualChecksum != expectedChecksum) {
      throw Exception('Binary checksum verification failed');
    }
    
    return AgentBinary(
      data: response.data,
      version: version,
      architecture: architecture
    );
  }
}
```

**Cost Estimation:**
- Storage: ~$0.023 per GB/month (3 binaries × 8MB = ~$0.001)
- Bandwidth: ~$0.09 per GB (first 50GB free)
- Estimated monthly: $2-5

#### 5.3.4 Optional: IBM Cloudant (Cross-Device Sync)

```yaml
Service: IBM Cloudant (Post-Hackathon)
Plan: Lite (free) or Standard
Use Case: Sync metrics history across devices

Database: server-metrics
Documents:
  - server_id: string
  - timestamp: ISO8601
  - metrics: { cpu, ram, disk, network }
  - device_id: string
```

---

## 6. Agent Bootstrap Flow (VSCode Remote SSH Model)

This is the core "magic" of Orbiter. Here is the exact sequence:

```
Step 1: App establishes SSH connection (dartssh2)

Step 2: App runs detection command via SSH exec:
        → "uname -m && test -f ~/.orbiter/agent && 
           ~/.orbiter/agent --version"

Step 3a: If agent exists and is current version:
        → Skip to Step 6

Step 3b: If agent missing or outdated:
        → App determines arch from uname -m output
        → App downloads correct binary from IBM Cloud Object Storage
        → App streams binary to server via SFTP:
           ~/.orbiter/agent.tmp
        → App runs: "chmod +x ~/.orbiter/agent.tmp && 
                     mv ~/.orbiter/agent.tmp ~/.orbiter/agent"

Step 4: App launches agent:
        → "mkdir -p ~/.orbiter && 
           nohup ~/.orbiter/agent --port 7433 
           --token {token} 
           --alert-endpoint {ibm-cloud-function-url} 
           > ~/.orbiter/agent.log 2>&1 & 
           echo $!"
        → App stores PID for session tracking

Step 5: App opens SSH port-forward tunnel:
        → local 127.0.0.1:7433 → remote 127.0.0.1:7433
        → All subsequent API calls go through this tunnel

Step 6: App sends health check:
        → GET http://127.0.0.1:7433/health
        → On 200 OK: show dashboard
        → On failure: show error with logs from ~/.orbiter/agent.log

Step 7: On app disconnect or background:
        → Tunnel closed (agent keeps running on server)
        → On next connect: skip Steps 3-4, go straight to tunnel
```

**Total time from "connect" tap to dashboard: ~3-8 seconds** (first time, subsequent ~1 second)

---

## 7. MigrationPilot Detailed Flow

```
User taps "Migrate This Server"
  ↓
Step 1: Scan (automated, ~30 seconds)
  App runs a series of SSH commands to collect:
  - OS and kernel version
  - Installed packages list
  - systemd service states
  - Docker containers and images
  - Web server configs (nginx/apache/caddy)
  - Database inventory (no data, just schema names + sizes)
  - Cron entries
  - UFW/iptables rules
  - Disk usage breakdown
  - Open ports (ss -tlnp)

Step 2: AI Analysis (IBM watsonx.ai)
  All collected data sent to watsonx.ai with prompt:
  "Generate a complete migration plan for this server..."
  Uses meta-llama/llama-3-70b-instruct for complex reasoning
  Returns structured JSON with phases, steps, commands

Step 3: Plan Display
  App renders migration plan as interactive checklist
  Each step has:
  - Explanation in plain English
  - The exact command(s) to run
  - "Run on source" / "Run on target" button
  - Estimated time
  - Validation check (command to verify step succeeded)

Step 4: Execution (optional)
  User can add target server to Orbiter
  Tap "Run" on each step → executes on correct server
  AI validates output before marking step complete

Step 5: Export
  Full plan exportable as Markdown file
  Shareable with team or saved for documentation
```

---

## 8. UI/UX Design Principles

- **Dark-first** — developers use dark mode, servers are often managed at night during incidents
- **Information density** — pack metrics tightly, no wasted whitespace
- **One-thumb reachability** — primary actions in bottom 40% of screen
- **Glanceable** — server health visible in 1 second without any taps
- **Haptic feedback** — on successful command execution, on alerts, on connection
- **Zero loading spinners** — stream data progressively, never block the UI
- **IBM Carbon Design influence** — Professional, enterprise-ready aesthetics

**Color system:**
- Green `#22c55e` — healthy / running
- Amber `#f59e0b` — warning / degraded  
- Red `#ef4444` — critical / stopped / disconnected
- Blue `#0f62fe` — AI features / interactive elements (IBM Blue)
- Surface: `#0f172a` (dark) / `#f8fafc` (light)

---

## 9. Hackathon Build Order (IBM Cloud Enhanced)

Build in this exact sequence to always have a demo-able product:

**Hour 1-2:** Server list UI + SSH connection with dartssh2
**Hour 3-4:** Agent binary (Go) — metrics endpoint only (CPU/RAM/disk)
**Hour 5-6:** Agent bootstrap flow (auto-install via SSH from IBM Cloud Object Storage)
**Hour 7-8:** Live dashboard — metric cards streaming from agent
**Hour 9-10:** Terminal emulator (xterm Flutter widget)
**Hour 11-12:** Services list — systemd + docker start/stop/restart
**Hour 13-14:** Log viewer — tail any log file, search
**Hour 15-16:** **IBM watsonx.ai integration** — log analysis with Granite model
**Hour 17-18:** Natural language terminal (translate English → shell command with watsonx.ai)
**Hour 19-20:** MigrationPilot — server scanner + watsonx.ai-generated plan (Llama 3)
**Hour 21-22:** Alerts — threshold config + IBM Cloud Functions relay + push notifications
**Hour 23-24:** Polish, demo script, edge cases

**Minimum viable demo (if short on time):** Hours 1-10 + Hours 15-16 (AI log analysis with watsonx.ai). That alone is impressive and fully demo-able.

---

## 10. Competitive Differentiation

| Feature | Orbiter | Termius | ServerCat | JuiceSSH |
|---|---|---|---|---|
| Zero-config agent install | ✅ | ❌ | ❌ | ❌ |
| AI log analysis (watsonx.ai) | ✅ | ❌ | ❌ | ❌ |
| Natural language commands | ✅ | ❌ | ❌ | ❌ |
| Migration planning (AI) | ✅ | ❌ | ❌ | ❌ |
| Incident timeline | ✅ | ❌ | ❌ | ❌ |
| Live metrics dashboard | ✅ | ❌ | ✅ | ❌ |
| Service manager | ✅ | ❌ | Partial | ❌ |
| IBM Cloud integration | ✅ | ❌ | ❌ | ❌ |
| Enterprise AI (watsonx) | ✅ | ❌ | ❌ | ❌ |
| Free | ✅* | Freemium | Paid | Freemium |

*Hackathon scope — future monetization via team/enterprise plan

---

## 11. Demo Script (2 Minutes)

1. **(0:00)** Open Orbiter. Tap "Add Server." Enter IP and paste SSH key. Tap Connect.
2. **(0:15)** Dashboard appears instantly — CPU, RAM, disk all live. "This took 4 seconds and zero server configuration. The agent was automatically installed from IBM Cloud Object Storage."
3. **(0:30)** Tap Services. Show nginx running. Tap Restart. Watch it go red then green.
4. **(0:45)** Tap AI. Type: *"Why is my memory usage at 87%?"* — **IBM watsonx.ai** reads metrics + logs and explains.
5. **(1:00)** Type: *"Show me the last nginx errors"* — AI executes, returns results, explains them in plain English using Granite model.
6. **(1:20)** Tap MigrationPilot. Show scan running. Show **watsonx.ai-generated plan** with phases, checkboxes, exact commands.
7. **(1:45)** "Everything you just saw works on any Linux VPS — DigitalOcean, Hostinger, AWS, IBM Cloud Virtual Servers, anything with SSH. And it's powered by IBM watsonx.ai for enterprise-grade AI."
8. **(2:00)** Show multi-server dashboard — 3 servers, all green. Done.

---

## 12. IBM Cloud Cost Breakdown (Monthly Estimates)

| Service | Usage | Cost |
|---------|-------|------|
| **watsonx.ai** | ~5M input tokens, ~2M output tokens | $10-40 |
| **Cloud Functions** | ~10K invocations (alerts) | Free tier |
| **Object Storage** | 24MB storage + 5GB bandwidth | $2-5 |
| **Cloudant** (optional) | Lite plan | Free |
| **Total** | | **$12-45/month** |

**Comparison to original plan:**
- Claude API: $15-50/month
- Cloudflare Workers: Free
- GitHub Releases: Free
- **Original total: $15-50/month**

**IBM Cloud is cost-competitive with better enterprise features.**

---

## 13. Future Roadmap (Post-Hackathon)

### Phase 1: Enhanced IBM Cloud Integration
- **IBM Cloud Virtual Servers API** — one-tap provision new servers
- **IBM Cloud Monitoring** — export metrics to IBM Cloud Monitoring
- **IBM App ID** — user authentication and team management
- **IBM Cloudant** — cross-device metrics sync

### Phase 2: Enterprise Features
- **Team mode** — share server access with teammates, audit log of who ran what
- **IBM watsonx Assistant** — voice-controlled server management
- **IBM Security Advisor** — vulnerability scanning and compliance checks
- **Cost tracker** — IBM Cloud + multi-cloud cost analysis

### Phase 3: Advanced AI
- **Predictive alerts** — watsonx.ai predicts issues before they occur
- **Auto-remediation** — AI suggests and applies fixes automatically (with approval)
- **Runbooks** — define one-tap playbooks powered by watsonx.ai
- **DeployStory integration** — pull git history and generate changelogs

### Phase 4: Platform Expansion
- **GitHub Actions / CI visibility** — see pipeline status alongside server metrics
- **Apple Watch widget** — glanceable server health on wrist
- **Desktop companion app** — full-featured desktop version
- **API for third-party integrations**

---

## 14. IBM Cloud Setup Checklist

### Prerequisites
- [ ] IBM Cloud account (free tier available)
- [ ] IBM Cloud CLI installed
- [ ] Firebase project for FCM (free)

### watsonx.ai Setup
- [ ] Create watsonx.ai instance in IBM Cloud
- [ ] Generate API key with watsonx.ai access
- [ ] Test API connection with Granite model
- [ ] Configure project ID in Flutter app

### Cloud Functions Setup
- [ ] Install IBM Cloud Functions CLI plugin
- [ ] Create namespace for Orbiter functions
- [ ] Deploy push-relay function
- [ ] Configure Firebase Admin SDK credentials
- [ ] Test alert flow end-to-end

### Object Storage Setup
- [ ] Create Cloud Object Storage instance
- [ ] Create bucket: orbiter-agent-binaries
- [ ] Configure public read access
- [ ] Upload agent binaries (amd64, arm64, armv7)
- [ ] Generate checksums.sha256 file
- [ ] Test download from Flutter app

### Optional: Cloudant Setup
- [ ] Create Cloudant instance (Lite plan)
- [ ] Create database: server-metrics
- [ ] Configure replication (if multi-region)
- [ ] Implement sync logic in Flutter app

---

## 15. Security Considerations

### SSH Security
- Private keys encrypted at rest using `flutter_secure_storage`
- Keys never leave device except during SSH connection
- Support for passphrase-protected keys
- Session tokens rotated per connection

### Agent Security
- Agent only listens on localhost (127.0.0.1)
- All communication through SSH tunnel
- Token-based authentication per session
- No credentials stored on server

### IBM Cloud Security
- API keys stored in secure storage
- TLS 1.3 for all IBM Cloud API calls
- IAM-based access control
- Audit logging via IBM Cloud Activity Tracker

### Data Privacy
- No server data sent to AI without user awareness
- Log snippets sanitized before sending to watsonx.ai
- User can redact sensitive values in migration scans
- All data encrypted in transit and at rest

---

## 16. Testing Strategy

### Unit Tests
- SSH connection handling
- Agent binary verification
- Metrics parsing and aggregation
- watsonx.ai API integration

### Integration Tests
- End-to-end agent bootstrap flow
- Alert trigger → Cloud Functions → FCM
- Migration plan generation
- Multi-server management

### Performance Tests
- Agent memory footprint (<20MB)
- Dashboard refresh rate (1s)
- Binary download speed
- watsonx.ai response time (<3s)

### Security Tests
- SSH key encryption
- Token validation
- API key protection
- Injection attack prevention

---

## 17. Success Metrics

### Hackathon Demo
- ✅ Connect to server in <5 seconds
- ✅ Live metrics streaming at 1s refresh
- ✅ AI log analysis in <3 seconds
- ✅ Migration plan generated in <30 seconds
- ✅ Alert delivered in <2 seconds

### Production Goals (Post-Hackathon)
- 1,000+ active users in first month
- <1% agent installation failure rate
- 99.9% uptime for IBM Cloud Functions
- <2s average watsonx.ai response time
- 4.5+ star rating on app stores

---

## 18. Conclusion

Orbiter combines the simplicity of mobile-first design with the power of enterprise AI through IBM watsonx.ai. By leveraging IBM Cloud's ecosystem, we achieve:

- **Zero-config deployment** — connecting is the setup
- **Enterprise-grade AI** — watsonx.ai for log analysis and migration planning
- **Serverless scalability** — Cloud Functions for alerts
- **Global distribution** — Object Storage for agent binaries
- **Cost-effective** — $12-45/month for full IBM Cloud integration

The architecture is proven (VSCode Remote SSH model), the tech stack is modern (Flutter + Go), and the IBM Cloud integration provides enterprise credibility while maintaining hackathon feasibility.

**Build time: 24 hours. Impact: Transformative.**