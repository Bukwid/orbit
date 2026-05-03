# Orbiter POC Demo Guide - Hackathon Edition

## 🚀 Quick Start (2 Simple Steps)

### Step 1: Start the Agent on Your Server

On your Linux server (168.144.33.97):

```bash
# Run the agent
./orbiter-agent --port 8090 --token hackathon2024
```

The agent will start on port 8090 and stream real-time metrics.

### Step 2: Run the Flutter App

```bash
cd orbiter
flutter pub get
flutter run
```

## 📱 The 3 POC Screens

### Screen 1: Agent Connect (Direct HTTP)
- **Default Host**: 168.144.33.97
- **Default Port**: 8090
- **Default Token**: hackathon2024
- Click "Connect" - app calls `GET /health` to verify connection

**Demo Tip**: Connection is instant - no SSH handshake needed!

### Screen 2: Real-time Dashboard
Once connected, you'll see:
- **CPU Usage** - Live percentage with progress bar
- **Memory Usage** - Real-time RAM consumption  
- **Disk Usage** - Storage utilization
- All metrics update every 2 seconds via WebSocket (`ws://host:port/ws/metrics`)

**Demo Tip**: Open a terminal and run `stress-ng --cpu 4 --timeout 30s` to show live CPU updates

### Screen 3: AI Log Analysis
- Click the **"Analyze Nginx Logs with AI"** button
- The app calls agent API: `POST /api/exec` with command `tail -n 20 /var/log/nginx/access.log`
- Sends logs to IBM watsonx.ai (Granite model)
- Displays AI-generated analysis including:
  - Total requests
  - Status code summary
  - Error detection
  - Top requested paths
  - Security assessment

**Demo Tip**: If nginx isn't installed, the app will show "No nginx logs found" - that's okay for the demo!

## 🎯 What This POC Demonstrates

1. **Direct Agent Connection** - Simple HTTP health check, no SSH complexity
2. **Real-time Monitoring** - WebSocket-based live metrics streaming
3. **AI Integration** - IBM watsonx.ai analyzing server logs

## 🔧 Technical Stack

**Flutter App (Minimal):**
- WebSocket: web_socket_channel
- HTTP: http package
- AI: IBM watsonx.ai REST API
- **Total dependencies: 2** (plus Flutter SDK)

**Go Agent:**
- WebSocket: gorilla/websocket
- Metrics: gopsutil
- HTTP server with Bearer token auth

## 📝 Architecture

```
Flutter App                    Go Agent (168.144.33.97:8090)
-----------                    ------------------------------
Connect Screen  --HTTP GET-->  /health (verify connection)
Dashboard       --WebSocket--> /ws/metrics (live metrics)
AI Analysis     --HTTP POST--> /api/exec (get nginx logs)
                --HTTP POST--> watsonx.ai (analyze logs)
```

## 🎬 Demo Script (90 seconds)

1. **[20s]** "Here's Orbiter - a server monitoring tool with AI"
2. **[20s]** Show connect screen, click Connect, show instant connection
3. **[30s]** Show live metrics updating in real-time
4. **[20s]** Click AI button, show it analyzing nginx logs with IBM watsonx.ai

## 🐛 Troubleshooting

**Can't connect?**
- Check agent is running: `curl http://168.144.33.97:8090/health`
- Verify firewall allows port 8090
- Check token matches: `hackathon2024`

**No metrics showing?**
- Wait 2-3 seconds for first WebSocket message
- Check browser console for WebSocket errors
- Verify agent has `/ws/metrics` endpoint

**AI analysis fails?**
- Verify IBM Cloud credentials in watsonx_service.dart
- Check internet connectivity
- watsonx.ai API key must be valid

## 📦 What's Included

**Files:**
- `orbiter/lib/main.dart` - Complete POC (442 lines, all 3 screens)
- `orbiter/lib/core/ai/watsonx_service.dart` - IBM watsonx.ai integration
- `orbiter/lib/core/websocket/websocket_service.dart` - WebSocket client
- `orbiter/lib/core/models/metrics_snapshot.dart` - Metrics data model
- `agent/bin/orbiter-agent.exe` - Pre-built agent binary

**What's NOT included (removed for simplicity):**
- ❌ SSH connectivity (dartssh2)
- ❌ Secure storage (flutter_secure_storage)
- ❌ File picker (file_picker)
- ❌ Charts (fl_chart)
- ❌ State management (riverpod)
- ❌ Firebase
- ❌ Terminal emulator

## 🚀 Next Steps (If We Had More Time)

- Multi-server support
- Alert notifications
- Process management UI
- Historical metrics charts
- Custom log file selection
- More AI analysis options

---

**Built for IBM Hackathon 2024**
**Made with Bob** 🤖

**Total Code: ~600 lines | Dependencies: 2 | Screens: 3**