# Orbiter — Mobile VPS Admin & Migration Pilot
### AI Agent Build Specification

---

## 1. Overview

**Orbiter** is a Flutter mobile application that turns your smartphone into a full-featured server administration panel. It connects to any Linux VPS (DigitalOcean, Hostinger, Vultr, Linode, AWS EC2, etc.) via SSH, automatically bootstraps a lightweight agent onto the server on first connect, and exposes real-time metrics, service management, log analysis, AI-powered natural language control, and a migration planning assistant — all from your phone.

**Core philosophy:** Connecting *is* the setup. The user enters an IP and credentials once. Everything else is automatic.

---

## 2. Target Users

- Solo developers and freelancers managing personal VPS instances
- Small teams without a dedicated DevOps engineer
- Developers on the go who need to respond to incidents from mobile
- Anyone migrating between VPS providers or cloud platforms

---

## 3. Application Architecture

### 3.1 High-Level Architecture

```
┌─────────────────────────────────────┐
│         Flutter Mobile App          │
│                                     │
│  ┌──────────┐  ┌──────────────────┐ │
│  │ SSH Layer│  │  AI Service Layer│ │
│  │ (dartssh2│  │  (Claude API /   │ │
│  │  / xterm)│  │   on-device)     │ │
│  └────┬─────┘  └────────┬─────────┘ │
└───────┼─────────────────┼───────────┘
        │ SSH Tunnel       │ HTTPS
        ▼                  ▼
┌───────────────────┐   ┌──────────────┐
│   Orbiter Agent     │   │  Claude API  │
│  (Go binary on    │   │ (Anthropic)  │
│   your VPS)       │   └──────────────┘
│                   │
│  - Metrics stream │
│  - Log tailing    │
│  - Service ctrl   │
│  - File manager   │
│  - WebSocket API  │
└───────────────────┘
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

**Agent communication flow:**
```
App opens SSH connection
  → App checks if agent binary exists at ~/.orbiter/agent
  → If missing: SCP binary to server, chmod +x, launch in background
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
4. On success: checks for existing agent → installs if absent
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
- Push notifications via FCM (Firebase Cloud Messaging) — agent pings a relay, relay sends push
- In-app alert center with history and timestamps
- Silence alerts per server for a defined period

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

### 4.4 Layer 4 — AI Features (Hackathon Differentiator)

All AI features use Claude API (`claude-sonnet-4-20250514`). The app sends relevant context (metrics, logs, config snippets) alongside user queries. No raw log data is sent without user awareness.

#### 4.4a Natural Language Terminal

User types or speaks a command in plain English. App translates to shell command, shows the command for review, executes on approval.

```
User:  "restart nginx and show me the last 20 lines of its error log"
Orbiter: → systemctl restart nginx && tail -20 /var/log/nginx/error.log
       [Run] [Edit] [Cancel]
```

- Commands always shown before execution — user is never bypassed
- AI has context of current server state (OS, installed services, directory)
- Dangerous commands (rm -rf, format, drop database) require explicit confirmation with typed "CONFIRM"

#### 4.4b Log Analysis

- User taps any log file or service log → AI summarizes in plain English
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

#### 4.4c "Why is my server slow?" Mode

One-tap holistic diagnosis. AI receives full metrics snapshot + recent logs and produces a prioritized explanation with suggested fixes.

#### 4.4d MigrationPilot — Server Migration Assistant

This is the feature that separates Orbiter from every competitor.

**What it does:**
Reads your current server's complete configuration and generates a step-by-step migration plan to any target environment — new VPS, different provider, or a clean server of the same provider.

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
│   └── storage/       # Encrypted local storage (flutter_secure_storage)
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
| `dio` | HTTP client for agent REST API |
| `web_socket_channel` | WebSocket for metrics streaming |
| `firebase_messaging` | Push notifications |
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
│   └── cron.go        # Crontab read/write
├── websocket/
│   └── hub.go         # WebSocket connection manager
└── build.sh           # Cross-compile for amd64, arm64, arm
```

**Agent startup:**
```bash
# App uploads binary via SCP then runs:
nohup ~/.orbiter/agent --port 7433 --token <session_token> > ~/.orbiter/agent.log 2>&1 &
```

The session token is generated per-connection and passed by the app. The agent only accepts connections with a valid token, preventing any local process from hijacking it.

### 5.3 Infrastructure (Minimal — Hackathon Scope)

For a hackathon, you only need two backend pieces beyond the app itself:

**Push notification relay (simple Node.js function):**
- The agent cannot push to Firebase directly (no credentials on server)
- Agent POSTs to a relay endpoint when threshold is breached
- Relay holds a mapping of `server_id → FCM token` and forwards the push
- Deploy as a single Cloudflare Worker or Vercel Function — zero server cost

**Binary CDN:**
- Host compiled agent binaries on GitHub Releases or Cloudflare R2
- App downloads the correct binary for the server's architecture on first connect
- SHA256 checksum verified before execution

**That's it.** No database, no backend API, no user accounts needed for a hackathon demo. Everything else is peer-to-peer between the phone and the VPS via SSH.

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
        → App downloads correct binary from CDN (if not cached locally)
        → App streams binary to server via SFTP:
           ~/.orbiter/agent.tmp
        → App runs: "chmod +x ~/.orbiter/agent.tmp && 
                     mv ~/.orbiter/agent.tmp ~/.orbiter/agent"

Step 4: App launches agent:
        → "mkdir -p ~/.orbiter && 
           nohup ~/.orbiter/agent --port 7433 
           --token {token} > ~/.orbiter/agent.log 2>&1 & 
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

Step 2: AI Analysis
  All collected data sent to Claude API with prompt:
  "Generate a complete migration plan for this server..."
  Claude returns structured JSON with phases, steps, commands

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

**Color system:**
- Green `#22c55e` — healthy / running
- Amber `#f59e0b` — warning / degraded  
- Red `#ef4444` — critical / stopped / disconnected
- Blue `#3b82f6` — AI features / interactive elements
- Surface: `#0f172a` (dark) / `#f8fafc` (light)

---

## 9. Hackathon Build Order

Build in this exact sequence to always have a demo-able product:

**Hour 1-2:** Server list UI + SSH connection with dartssh2
**Hour 3-4:** Agent binary (Go) — metrics endpoint only (CPU/RAM/disk)
**Hour 5-6:** Agent bootstrap flow (auto-install via SSH)
**Hour 7-8:** Live dashboard — metric cards streaming from agent
**Hour 9-10:** Terminal emulator (xterm Flutter widget)
**Hour 11-12:** Services list — systemd + docker start/stop/restart
**Hour 13-14:** Log viewer — tail any log file, search
**Hour 15-16:** AI log analysis (Claude API integration)
**Hour 17-18:** Natural language terminal (translate English → shell command)
**Hour 19-20:** MigrationPilot — server scanner + Claude-generated plan
**Hour 21-22:** Alerts — threshold config + push notifications
**Hour 23-24:** Polish, demo script, edge cases

**Minimum viable demo (if short on time):** Hours 1-10 + Hours 15-16 (AI log analysis). That alone is impressive and fully demo-able.

---

## 10. Competitive Differentiation

| Feature | Orbiter | Termius | ServerCat | JuiceSSH |
|---|---|---|---|---|
| Zero-config agent install | ✅ | ❌ | ❌ | ❌ |
| AI log analysis | ✅ | ❌ | ❌ | ❌ |
| Natural language commands | ✅ | ❌ | ❌ | ❌ |
| Migration planning | ✅ | ❌ | ❌ | ❌ |
| Incident timeline | ✅ | ❌ | ❌ | ❌ |
| Live metrics dashboard | ✅ | ❌ | ✅ | ❌ |
| Service manager | ✅ | ❌ | Partial | ❌ |
| Free | ✅* | Freemium | Paid | Freemium |

*Hackathon scope — future monetization via team/enterprise plan

---

## 11. Demo Script (2 Minutes)

1. **(0:00)** Open Orbiter. Tap "Add Server." Enter IP and paste SSH key. Tap Connect.
2. **(0:15)** Dashboard appears instantly — CPU, RAM, disk all live. "This took 4 seconds and zero server configuration."
3. **(0:30)** Tap Services. Show nginx running. Tap Restart. Watch it go red then green.
4. **(0:45)** Tap AI. Type: *"Why is my memory usage at 87%?"* — AI reads metrics + logs and explains.
5. **(1:00)** Type: *"Show me the last nginx errors"* — AI executes, returns results, explains them in plain English.
6. **(1:20)** Tap MigrationPilot. Show scan running. Show generated plan with phases, checkboxes, exact commands.
7. **(1:45)** "Everything you just saw works on any Linux VPS — DigitalOcean, Hostinger, AWS, anything with SSH."
8. **(2:00)** Show multi-server dashboard — 3 servers, all green. Done.

---

## 12. Future Roadmap (Post-Hackathon)

- **Team mode** — share server access with teammates, audit log of who ran what
- **DeployStory integration** — pull git history from server and generate client changelogs
- **GitHub Actions / CI visibility** — see pipeline status alongside server metrics
- **Cost tracker** — Hostinger + DigitalOcean API integration to show spend vs utilization
- **Runbooks** — define one-tap playbooks (e.g., "deploy latest") that run a sequence of commands
- **Apple Watch widget** — glanceable server health on wrist