import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/metrics_snapshot.dart';
import '../models/process_info.dart';

/// Manages WebSocket connections to the agent
class WebSocketService {
  WebSocketChannel? _metricsChannel;
  WebSocketChannel? _logsChannel;
  
  final _metricsController = StreamController<MetricsSnapshot>.broadcast();
  final _logsController = StreamController<LogEntry>.broadcast();
  final _connectionStateController = StreamController<ConnectionState>.broadcast();
  
  Timer? _reconnectTimer;
  String? _metricsUrl;
  String? _logsUrl;
  bool _isDisposed = false;
  
  ConnectionState _state = ConnectionState.disconnected;

  Stream<MetricsSnapshot> get metricsStream => _metricsController.stream;
  Stream<LogEntry> get logsStream => _logsController.stream;
  Stream<ConnectionState> get connectionStateStream => _connectionStateController.stream;
  ConnectionState get connectionState => _state;

  /// Connect to metrics WebSocket
  Future<void> connectMetrics(String url) async {
    _metricsUrl = url;
    await _connectMetricsChannel();
  }

  /// Connect to logs WebSocket
  Future<void> connectLogs(String url) async {
    _logsUrl = url;
    await _connectLogsChannel();
  }

  Future<void> _connectMetricsChannel() async {
    if (_metricsUrl == null || _isDisposed) return;

    try {
      _updateState(ConnectionState.connecting);
      
      _metricsChannel?.sink.close();
      _metricsChannel = WebSocketChannel.connect(Uri.parse(_metricsUrl!));

      _updateState(ConnectionState.connected);

      _metricsChannel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            final snapshot = MetricsSnapshot.fromJson(json);
            _metricsController.add(snapshot);
          } catch (e) {
            print('Error parsing metrics: $e');
          }
        },
        onError: (error) {
          print('Metrics WebSocket error: $error');
          _handleDisconnection();
        },
        onDone: () {
          print('Metrics WebSocket closed');
          _handleDisconnection();
        },
      );
    } catch (e) {
      print('Failed to connect metrics WebSocket: $e');
      _updateState(ConnectionState.error);
      _scheduleReconnect();
    }
  }

  Future<void> _connectLogsChannel() async {
    if (_logsUrl == null || _isDisposed) return;

    try {
      _logsChannel?.sink.close();
      _logsChannel = WebSocketChannel.connect(Uri.parse(_logsUrl!));

      _logsChannel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            final entry = LogEntry.fromJson(json);
            _logsController.add(entry);
          } catch (e) {
            print('Error parsing log entry: $e');
          }
        },
        onError: (error) {
          print('Logs WebSocket error: $error');
        },
        onDone: () {
          print('Logs WebSocket closed');
        },
      );
    } catch (e) {
      print('Failed to connect logs WebSocket: $e');
    }
  }

  void _handleDisconnection() {
    _updateState(ConnectionState.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isDisposed && _metricsUrl != null) {
        print('Attempting to reconnect...');
        _connectMetricsChannel();
      }
    });
  }

  void _updateState(ConnectionState newState) {
    _state = newState;
    _connectionStateController.add(newState);
  }

  /// Send a message through the WebSocket
  void sendMessage(String message) {
    _metricsChannel?.sink.add(message);
  }

  /// Disconnect all WebSocket connections
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    await _metricsChannel?.sink.close();
    await _logsChannel?.sink.close();
    _metricsChannel = null;
    _logsChannel = null;
    _metricsUrl = null;
    _logsUrl = null;
    _updateState(ConnectionState.disconnected);
  }

  /// Dispose of the service
  void dispose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _metricsChannel?.sink.close();
    _logsChannel?.sink.close();
    _metricsController.close();
    _logsController.close();
    _connectionStateController.close();
  }
}

enum ConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

// Made with Bob
