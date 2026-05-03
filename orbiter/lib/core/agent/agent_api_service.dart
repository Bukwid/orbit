import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/service_info.dart';
import '../models/process_info.dart';
import '../models/metrics_snapshot.dart';

/// Service for making HTTP requests to the agent
class AgentApiService {
  final Dio _dio;
  final String baseUrl;

  AgentApiService({
    required this.baseUrl,
    String? authToken,
  }) : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: authToken != null
              ? {'Authorization': 'Bearer $authToken'}
              : null,
        ));

  /// Health check
  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get('/health');
      return response.statusCode == 200;
    } catch (e) {
      print('Health check failed: $e');
      return false;
    }
  }

  /// Get current metrics snapshot
  Future<MetricsSnapshot> getMetrics() async {
    try {
      final response = await _dio.get('/api/metrics');
      return MetricsSnapshot.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to get metrics: $e');
    }
  }

  /// Get list of services
  Future<List<ServiceInfo>> getServices() async {
    try {
      final response = await _dio.get('/api/services');
      final List<dynamic> data = response.data as List<dynamic>;
      return data
          .map((json) => ServiceInfo.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to get services: $e');
    }
  }

  /// Control a service (start, stop, restart)
  Future<void> controlService(String serviceName, String action) async {
    try {
      await _dio.post('/api/services/$serviceName/$action');
    } catch (e) {
      throw Exception('Failed to $action service $serviceName: $e');
    }
  }

  /// Get list of processes
  Future<List<ProcessInfo>> getProcesses() async {
    try {
      final response = await _dio.get('/api/processes');
      final List<dynamic> data = response.data as List<dynamic>;
      return data
          .map((json) => ProcessInfo.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to get processes: $e');
    }
  }

  /// Kill a process
  Future<void> killProcess(int pid, {int signal = 15}) async {
    try {
      await _dio.post('/api/processes/$pid/kill', data: {'signal': signal});
    } catch (e) {
      throw Exception('Failed to kill process $pid: $e');
    }
  }

  /// Execute a command
  Future<Map<String, dynamic>> executeCommand(String command) async {
    try {
      final response = await _dio.post('/api/exec', data: {'command': command});
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to execute command: $e');
    }
  }

  /// Get file content
  Future<String> getFileContent(String path) async {
    try {
      final response = await _dio.get('/api/files', queryParameters: {'path': path});
      return response.data['content'] as String;
    } catch (e) {
      throw Exception('Failed to get file content: $e');
    }
  }

  /// Write file content
  Future<void> writeFileContent(String path, String content) async {
    try {
      await _dio.post('/api/files', data: {
        'path': path,
        'content': content,
      });
    } catch (e) {
      throw Exception('Failed to write file: $e');
    }
  }

  /// Get cron jobs
  Future<List<Map<String, dynamic>>> getCronJobs() async {
    try {
      final response = await _dio.get('/api/cron');
      return List<Map<String, dynamic>>.from(response.data as List);
    } catch (e) {
      throw Exception('Failed to get cron jobs: $e');
    }
  }

  /// Add cron job
  Future<void> addCronJob(String schedule, String command) async {
    try {
      await _dio.post('/api/cron', data: {
        'schedule': schedule,
        'command': command,
      });
    } catch (e) {
      throw Exception('Failed to add cron job: $e');
    }
  }

  /// Delete cron job
  Future<void> deleteCronJob(String id) async {
    try {
      await _dio.delete('/api/cron/$id');
    } catch (e) {
      throw Exception('Failed to delete cron job: $e');
    }
  }

  /// Get alerts
  Future<List<Map<String, dynamic>>> getAlerts() async {
    try {
      final response = await _dio.get('/api/alerts');
      return List<Map<String, dynamic>>.from(response.data as List);
    } catch (e) {
      throw Exception('Failed to get alerts: $e');
    }
  }

  /// Create alert
  Future<void> createAlert(Map<String, dynamic> alert) async {
    try {
      await _dio.post('/api/alerts', data: alert);
    } catch (e) {
      throw Exception('Failed to create alert: $e');
    }
  }

  /// Delete alert
  Future<void> deleteAlert(String id) async {
    try {
      await _dio.delete('/api/alerts/$id');
    } catch (e) {
      throw Exception('Failed to delete alert: $e');
    }
  }
}

// Made with Bob
