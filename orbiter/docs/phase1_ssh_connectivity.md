# Phase 1: SSH Connectivity & Basic UI

**Goal:** Connect to servers via SSH and build basic terminal interface.

---

## 1.1 SSH Connection Manager

### Create SSH Service (lib/core/ssh/ssh_service.dart)

**Tasks:**
- [ ] Implement password authentication
- [ ] Implement private key authentication (RSA, Ed25519)
- [ ] Add connection state management
- [ ] Implement auto-reconnect with exponential backoff
- [ ] Add SSH port forwarding (for agent tunnel: localhost:7433 → remote:7433)

**Key Methods:**
```dart
Future<SSHSession> connect({host, port, username, password, privateKey})
Future<void> disconnect()
Future<String> executeCommand(String command)
Future<void> openTunnel(int localPort, int remotePort)
```

---

## 1.2 Secure Storage

### Create Storage Service (lib/core/storage/secure_storage_service.dart)

**Tasks:**
- [ ] Implement encrypted storage using `flutter_secure_storage`
- [ ] Create ServerConfig model
- [ ] Implement CRUD operations (save, load, update, delete servers)
- [ ] Encrypt private keys at rest

**Server Config Model:**
```dart
class ServerConfig {
  String id;
  String nickname;
  String hostname;
  int port;
  String username;
  AuthMethod authMethod; // password or privateKey
  String? password;
  String? privateKey;
}
```

---

## 1.3 Server List UI

### Create Server List Screen (lib/features/servers/server_list_screen.dart)

**Tasks:**
- [ ] Create server list with cards showing nickname, hostname, status
- [ ] Add "Add Server" floating action button
- [ ] Implement connection status indicators (green/red/yellow)
- [ ] Add pull-to-refresh for connection status
- [ ] Implement server edit/delete functionality
- [ ] Add empty state ("No servers yet")

**UI Components:**
- Server card with status badge
- Add server form with validation
- Connection status indicator
- Quick-switch sidebar

---

## 1.4 Terminal Emulator

### Integrate xterm (lib/features/terminal/terminal_screen.dart)

**Tasks:**
- [ ] Integrate `xterm` Flutter package
- [ ] Connect terminal to SSH session
- [ ] Add keyboard shortcut bar (Tab, Ctrl+C, Ctrl+D, arrows, Esc)
- [ ] Implement pinch-to-zoom for font size
- [ ] Add copy/paste with long-press
- [ ] Support dark and light themes

**Terminal Features:**
- Full xterm compatibility
- Swipe gestures for history
- Persistent keyboard shortcuts
- Font size adjustment

---

## 1.5 Add Server Flow

### Create Add Server Form (lib/features/servers/add_server_screen.dart)

**Form Fields:**
- [ ] Nickname (text input)
- [ ] Hostname/IP (text input with validation)
- [ ] Port (number input, default 22)
- [ ] Username (text input)
- [ ] Auth method selector (password or key)
- [ ] Password field (if password auth)
- [ ] Private key input (paste or file picker)

**Connection Flow:**
1. User fills form
2. Tap "Connect"
3. Show connecting spinner
4. On success: Save server, navigate to dashboard
5. On failure: Show error dialog

---

## Phase 1 Checklist

- [ ] SSH connection working with password auth
- [ ] SSH connection working with private key auth
- [ ] Can add multiple servers
- [ ] Server credentials stored securely
- [ ] Terminal emulator functional
- [ ] Can execute commands in terminal
- [ ] Connection errors handled gracefully
- [ ] Auto-reconnect works

**Demo:** Add a server, connect via SSH, execute commands in terminal, disconnect and reconnect.

**Next:** Phase 2 - Build the Go agent that runs on the server.