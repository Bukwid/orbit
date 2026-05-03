# Orbiter Hackathon Quick Start Guide

**Build Order for Maximum Impact in Minimum Time**

---

## 🎯 MVP Strategy (Minimum Viable Product)

For a hackathon, focus on these phases in order:

### Priority 1: Core Demo (Hours 1-12)
✅ **Phase 0** - Foundation (2 hours)
✅ **Phase 1** - SSH Connection (3 hours)
✅ **Phase 2** - Agent Basics (4 hours - metrics only)
✅ **Phase 3** - Dashboard UI (3 hours - metrics display only)

**Result:** Can connect to server, auto-install agent, show live metrics.

### Priority 2: AI Features (Hours 13-18)
✅ **Phase 4** - IBM Cloud Setup (2 hours)
✅ **Phase 5.1** - Natural Language Commands (2 hours)
✅ **Phase 5.2** - AI Log Analysis (2 hours)

**Result:** AI-powered features that differentiate from competitors.

### Priority 3: Polish (Hours 19-24)
✅ **Phase 6** - Demo Prep (3 hours)
✅ **Phase 3** - Services UI (2 hours)
✅ **Phase 6** - Final Polish (1 hour)

**Result:** Demo-ready app with wow factor.

---

## 🚀 Hackathon Build Order

### Hour 1-2: Foundation
- [ ] Install Flutter, Go, IBM Cloud CLI
- [ ] Create IBM Cloud account
- [ ] Provision watsonx.ai
- [ ] Set up Firebase
- [ ] Initialize projects

**Checkpoint:** `flutter doctor` passes, watsonx.ai API tested

---

### Hour 3-5: SSH Connection
- [ ] Implement SSH service with dartssh2
- [ ] Create server list UI
- [ ] Add server form
- [ ] Secure storage for credentials
- [ ] Basic terminal emulator

**Checkpoint:** Can add server, connect via SSH, execute commands

---

### Hour 6-9: Go Agent (Metrics Only)
- [ ] Create main.go with HTTP server
- [ ] Implement metrics collection (CPU, RAM, disk, network)
- [ ] Create WebSocket endpoint for metrics
- [ ] Build for amd64
- [ ] Upload to IBM Cloud Object Storage

**Checkpoint:** Agent runs, streams metrics via WebSocket

---

### Hour 10-12: Dashboard UI
- [ ] Implement agent bootstrap flow
- [ ] Create dashboard screen
- [ ] Connect to agent WebSocket
- [ ] Display metric cards (CPU, RAM, disk, network)
- [ ] Add sparkline charts

**Checkpoint:** Dashboard shows live metrics updating every second

---

### Hour 13-14: IBM Cloud Integration
- [ ] Create watsonx.ai client
- [ ] Test API connection
- [ ] Implement IAM authentication

**Checkpoint:** Can call watsonx.ai API successfully

---

### Hour 15-16: Natural Language Commands
- [ ] Create command translator
- [ ] Implement command preview UI
- [ ] Add dangerous command detection
- [ ] Test with common commands

**Checkpoint:** Can translate "restart nginx" to shell command

---

### Hour 17-18: AI Log Analysis
- [ ] Add log streaming to agent
- [ ] Create log viewer UI
- [ ] Implement AI log analyzer
- [ ] Add "Analyze" button

**Checkpoint:** Can analyze logs and get AI insights

---

### Hour 19-21: Services & Polish
- [ ] Add service management to agent
- [ ] Create services UI
- [ ] Add start/stop/restart buttons
- [ ] Polish dashboard UI
- [ ] Add haptic feedback

**Checkpoint:** Can control services from app

---

### Hour 22-24: Demo Prep
- [ ] Practice demo script
- [ ] Set up demo servers
- [ ] Record demo video
- [ ] Create presentation slides
- [ ] Write README

**Checkpoint:** Demo runs smoothly in under 2 minutes

---

## 🎬 2-Minute Demo Script

**[0:00-0:15] The Problem**
"Managing servers from mobile is painful. Let me show you Orbiter."

**[0:15-0:30] Connect**
Open app → Add server → Enter IP + SSH key → Connect
"No configuration needed. Watch this."

**[0:30-0:45] Live Metrics**
Dashboard appears with live metrics
"Agent auto-installed. Live metrics updating every second."

**[0:45-1:05] AI Commands**
Tap AI → Type "restart nginx and show errors"
"IBM watsonx.ai translates plain English to shell commands."

**[1:05-1:25] AI Log Analysis**
Show log analysis with Granite model
"AI analyzes logs and suggests fixes. All powered by watsonx.ai."

**[1:25-1:50] MigrationPilot (if time)**
Show migration plan generation
"Llama 3 generates complete migration plans."

**[1:50-2:00] Close**
"Works on any Linux VPS. Powered by IBM watsonx.ai. Thank you!"

---

## 🔥 If You're Running Out of Time

### Must-Have (Don't skip these)
- SSH connection
- Agent auto-installation
- Live metrics dashboard
- AI command translation
- AI log analysis

### Nice-to-Have (Skip if needed)
- MigrationPilot
- Push notifications
- Cron manager
- Process manager
- File browser

### Can Demo Without
- Multiple servers
- Alert configuration
- Incident timeline
- Service resource usage

---

## 💡 Quick Wins for Demo Impact

1. **Smooth animations** - Makes it feel polished
2. **Haptic feedback** - Feels responsive
3. **Dark theme** - Looks professional
4. **Live metrics** - Shows real-time capability
5. **AI features** - Differentiates from competitors

---

## 🐛 Common Issues & Fixes

### Agent won't install
- Check server has internet access
- Verify IBM Cloud Object Storage is public
- Try manual installation first

### Metrics not streaming
- Check SSH tunnel is open
- Verify agent is running: `ps aux | grep agent`
- Check agent logs: `cat ~/.orbiter/agent.log`

### watsonx.ai errors
- Verify API key is correct
- Check IAM token is valid
- Ensure project ID is set

### App crashes
- Check all dependencies installed
- Run `flutter clean && flutter pub get`
- Check for null safety issues

---

## 📋 Pre-Demo Checklist

**30 Minutes Before:**
- [ ] Demo servers are online and stable
- [ ] App installed on demo device
- [ ] Screen mirroring working
- [ ] Demo script memorized
- [ ] Backup video ready

**5 Minutes Before:**
- [ ] Close all other apps
- [ ] Turn off notifications
- [ ] Check battery level
- [ ] Test WiFi connection
- [ ] Open app to server list

---

## 🎯 Judging Criteria Focus

### Technical Complexity (30%)
- Highlight agent auto-installation
- Explain SSH tunneling
- Show real-time WebSocket streaming

### IBM Cloud Integration (30%)
- Emphasize watsonx.ai usage (Granite + Llama 3)
- Mention Cloud Functions for alerts
- Show Object Storage for distribution

### Innovation (20%)
- MigrationPilot is unique
- Natural language commands
- Zero-config setup

### User Experience (20%)
- Show smooth UI
- Demonstrate ease of use
- Highlight mobile-first design

---

## 🚀 Good Luck!

**Remember:**
- Focus on core features first
- AI features are your differentiator
- Practice your demo
- Have fun!

**You've got this! 💪**