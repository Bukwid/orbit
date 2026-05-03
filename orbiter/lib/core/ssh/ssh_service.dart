import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import '../storage/server_config.dart';

/// Connection state for SSH sessions
enum SSHConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// SSH session wrapper
class SSHSession {
  final SSHClient client;
  final ServerConfig config;
  final DateTime connectedAt;
  SSHConnectionState state;
  String? errorMessage;

  SSHSession({
    required this.client,
    required this.config,
    required this.connectedAt,
    this.state = SSHConnectionState.connected,
    this.errorMessage,
  });
}

/// Service for managing SSH connections
class SSHService {
  final Map<String, SSHSession> _sessions = {};
  final Map<String, Timer> _reconnectTimers = {};
  final Map<String, int> _reconnectAttempts = {};
  final StreamController<SSHConnectionEvent> _connectionEvents =
      StreamController<SSHConnectionEvent>.broadcast();

  /// Stream of connection events
  Stream<SSHConnectionEvent> get connectionEvents => _connectionEvents.stream;

  /// Connect to a server
  Future<SSHSession> connect(ServerConfig config) async {
    try {
      // Cancel any existing reconnect timer
      _cancelReconnectTimer(config.id);

      // Update state
      _emitEvent(SSHConnectionEvent(
        serverId: config.id,
        state: SSHConnectionState.connecting,
      ));

      // Create SSH socket
      final socket = await SSHSocket.connect(
        config.hostname,
        config.port,
        timeout: const Duration(seconds: 30),
      );

      // Create SSH client
      final client = SSHClient(
        socket,
        username: config.username,
        onPasswordRequest: config.authMethod == AuthMethod.password
            ? () => config.password ?? ''
            : null,
        identities: config.authMethod == AuthMethod.privateKey && config.privateKey != null
            ? [
                ...SSHKeyPair.fromPem(config.privateKey!),
              ]
            : null,
      );

      // Wait for authentication
      await client.authenticated;

      // Create session
      final session = SSHSession(
        client: client,
        config: config,
        connectedAt: DateTime.now(),
        state: SSHConnectionState.connected,
      );

      _sessions[config.id] = session;
      _reconnectAttempts[config.id] = 0;

      // Update state
      _emitEvent(SSHConnectionEvent(
        serverId: config.id,
        state: SSHConnectionState.connected,
      ));

      // Monitor connection
      _monitorConnection(config.id);

      return session;
    } catch (e) {
      _emitEvent(SSHConnectionEvent(
        serverId: config.id,
        state: SSHConnectionState.error,
        errorMessage: e.toString(),
      ));
      throw SSHException('Failed to connect: $e');
    }
  }

  /// Disconnect from a server
  Future<void> disconnect(String serverId) async {
    try {
      _cancelReconnectTimer(serverId);
      
      final session = _sessions[serverId];
      if (session != null) {
        session.client.close();
        _sessions.remove(serverId);
        _reconnectAttempts.remove(serverId);
        
        _emitEvent(SSHConnectionEvent(
          serverId: serverId,
          state: SSHConnectionState.disconnected,
        ));
      }
    } catch (e) {
      throw SSHException('Failed to disconnect: $e');
    }
  }

  /// Execute a command on the server
  Future<String> executeCommand(String serverId, String command) async {
    final session = _sessions[serverId];
    if (session == null) {
      throw SSHException('Not connected to server: $serverId');
    }

    try {
      final result = await session.client.run(command);
      return utf8.decode(result);
    } catch (e) {
      throw SSHException('Failed to execute command: $e');
    }
  }

  /// Execute a command and get a stream of output
  Stream<String> executeCommandStream(String serverId, String command) async* {
    final session = _sessions[serverId];
    if (session == null) {
      throw SSHException('Not connected to server: $serverId');
    }

    try {
      final result = await session.client.execute(command);
      await for (final chunk in result.stdout) {
        yield utf8.decode(chunk);
      }
    } catch (e) {
      throw SSHException('Failed to execute command: $e');
    }
  }

  /// Open a shell session
  Future<SSHSession> openShell(String serverId) async {
    final session = _sessions[serverId];
    if (session == null) {
      throw SSHException('Not connected to server: $serverId');
    }

    return session;
  }

  /// Open SSH port forwarding (tunnel)
  Future<void> openTunnel(
    String serverId,
    String localHost,
    int localPort,
    String remoteHost,
    int remotePort,
  ) async {
    final session = _sessions[serverId];
    if (session == null) {
      throw SSHException('Not connected to server: $serverId');
    }

    try {
      final serverSocket = await ServerSocket.bind(localHost, localPort);
      
      serverSocket.listen((socket) async {
        final forward = await session.client.forwardLocal(remoteHost, remotePort);
        forward.stream.cast<List<int>>().listen((data) => socket.add(data));
        forward.stream.cast<List<int>>().pipe(socket);
      });
    } catch (e) {
      throw SSHException('Failed to open tunnel: $e');
    }
  }

  /// Get session for a server
  SSHSession? getSession(String serverId) {
    return _sessions[serverId];
  }

  /// Check if connected to a server
  bool isConnected(String serverId) {
    final session = _sessions[serverId];
    return session != null && session.state == SSHConnectionState.connected;
  }

  /// Get connection state for a server
  SSHConnectionState getConnectionState(String serverId) {
    final session = _sessions[serverId];
    return session?.state ?? SSHConnectionState.disconnected;
  }

  /// Monitor connection and auto-reconnect if needed
  void _monitorConnection(String serverId) {
    final session = _sessions[serverId];
    if (session == null) return;

    session.client.done.then((_) {
      if (_sessions.containsKey(serverId)) {
        _handleDisconnection(serverId);
      }
    }).catchError((error) {
      if (_sessions.containsKey(serverId)) {
        _handleDisconnection(serverId);
      }
    });
  }

  /// Handle disconnection and attempt reconnect
  void _handleDisconnection(String serverId) {
    final session = _sessions[serverId];
    if (session == null) return;

    _emitEvent(SSHConnectionEvent(
      serverId: serverId,
      state: SSHConnectionState.reconnecting,
    ));

    _attemptReconnect(serverId, session.config);
  }

  /// Attempt to reconnect with exponential backoff
  void _attemptReconnect(String serverId, ServerConfig config) {
    final attempts = _reconnectAttempts[serverId] ?? 0;
    
    // Max 10 attempts
    if (attempts >= 10) {
      _emitEvent(SSHConnectionEvent(
        serverId: serverId,
        state: SSHConnectionState.error,
        errorMessage: 'Max reconnection attempts reached',
      ));
      _sessions.remove(serverId);
      return;
    }

    // Exponential backoff: 2^attempts seconds (max 60 seconds)
    final delay = Duration(seconds: (1 << attempts).clamp(1, 60));
    
    _reconnectTimers[serverId] = Timer(delay, () async {
      _reconnectAttempts[serverId] = attempts + 1;
      
      try {
        await connect(config);
      } catch (e) {
        _attemptReconnect(serverId, config);
      }
    });
  }

  /// Cancel reconnect timer
  void _cancelReconnectTimer(String serverId) {
    _reconnectTimers[serverId]?.cancel();
    _reconnectTimers.remove(serverId);
  }

  /// Emit connection event
  void _emitEvent(SSHConnectionEvent event) {
    if (!_connectionEvents.isClosed) {
      _connectionEvents.add(event);
    }
  }

  /// Disconnect all sessions
  Future<void> disconnectAll() async {
    final serverIds = _sessions.keys.toList();
    for (final serverId in serverIds) {
      await disconnect(serverId);
    }
  }

  /// Dispose the service
  void dispose() {
    disconnectAll();
    for (final timer in _reconnectTimers.values) {
      timer.cancel();
    }
    _reconnectTimers.clear();
    _reconnectAttempts.clear();
    _connectionEvents.close();
  }
}

/// SSH connection event
class SSHConnectionEvent {
  final String serverId;
  final SSHConnectionState state;
  final String? errorMessage;

  SSHConnectionEvent({
    required this.serverId,
    required this.state,
    this.errorMessage,
  });
}

/// Exception thrown when SSH operations fail
class SSHException implements Exception {
  final String message;
  SSHException(this.message);

  @override
  String toString() => 'SSHException: $message';
}

// Made with Bob
