
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../agent/agent_api_service.dart';
import '../agent/agent_bootstrapper.dart';
import '../websocket/websocket_service.dart';
import '../models/metrics_snapshot.dart';
import '../models/service_info.dart';
import '../models/process_info.dart';

/// Provider for the WebSocket service
final websocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for the Agent API service
final agentApiProvider = Provider<AgentApiService>((ref) {
  // Default to localhost:7433, will be updated after bootstrap
  return AgentApiService(
    baseUrl: 'http://127.0.0.1:7433',
    authToken: 'your-auth-token', // TODO: Get from secure storage
  );
});

/// Provider for connection state
final connectionStateProvider = StreamProvider<ConnectionState>((ref) {
  final websocket = ref.watch(websocketServiceProvider);
  return websocket.connectionStateStream;
});

/// Provider for metrics stream
final metricsStreamProvider = StreamProvider<MetricsSnapshot>((ref) {
  final websocket = ref.watch(websocketServiceProvider);
  return websocket.metricsStream;
});

/// Provider for current metrics snapshot
final currentMetricsProvider = Provider<MetricsSnapshot?>((ref) {
  final metricsAsync = ref.watch(metricsStreamProvider);
  return metricsAsync.value;
});

/// Provider for services list
final servicesProvider = FutureProvider<List<ServiceInfo>>((ref) async {
  final api = ref.watch(agentApiProvider);
  return api.getServices();
});

/// Provider for processes list
final processesProvider = FutureProvider<List<ProcessInfo>>((ref) async {
  final api = ref.watch(agentApiProvider);
  return api.getProcesses();
});

/// Provider for logs stream
final logsStreamProvider = StreamProvider<LogEntry>((ref) {
  final websocket = ref.watch(websocketServiceProvider);
  return websocket.logsStream;
});

/// Provider for metrics history (last 24 hours)
final metricsHistoryProvider = StateNotifierProvider<MetricsHistoryNotifier, List<MetricsSnapshot>>((ref) {
  return MetricsHistoryNotifier();
});

/// Notifier for managing metrics history
class MetricsHistoryNotifier extends StateNotifier<List<MetricsSnapshot>> {
  MetricsHistoryNotifier() : super([]);

  static const int maxHistorySize = 86400; // 24 hours at 1 second intervals

  void addMetric(MetricsSnapshot snapshot) {
    state = [...state, snapshot];
    
    // Keep only last 24 hours
    if (state.length > maxHistorySize) {
      state = state.sublist(state.length - maxHistorySize);
    }
  }

  void clear() {
    state = [];
  }

  List<MetricsSnapshot> getLastHour() {
    final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
    return state.where((s) => s.timestamp.isAfter(oneHourAgo)).toList();
  }

  List<MetricsSnapshot> getLastDay() {
    return state;
  }
}

/// Provider for service control actions
final serviceControlProvider = Provider<ServiceController>((ref) {
  final api = ref.watch(agentApiProvider);
  return ServiceController(api);
});

/// Controller for service actions
class ServiceController {
  final AgentApiService api;

  ServiceController(this.api);

  Future<void> startService(String serviceName) async {
    await api.controlService(serviceName, 'start');
  }

  Future<void> stopService(String serviceName) async {
    await api.controlService(serviceName, 'stop');
  }

  Future<void> restartService(String serviceName) async {
    await api.controlService(serviceName, 'restart');
  }
}

/// Provider for process control actions
final processControlProvider = Provider<ProcessController>((ref) {
  final api = ref.watch(agentApiProvider);
  return ProcessController(api);
});

/// Controller for process actions
class ProcessController {
  final AgentApiService api;

  ProcessController(this.api);

  Future<void> killProcess(int pid, {int signal = 15}) async {
    await api.killProcess(pid, signal: signal);
  }

  Future<void> forceKillProcess(int pid) async {
    await api.killProcess(pid, signal: 9);
  }
}

