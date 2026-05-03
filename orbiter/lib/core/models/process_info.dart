/// Represents a running process
class ProcessInfo {
  final int pid;
  final String user;
  final double cpu;
  final double memory;
  final String command;
  final String? state;

  ProcessInfo({
    required this.pid,
    required this.user,
    required this.cpu,
    required this.memory,
    required this.command,
    this.state,
  });

  factory ProcessInfo.fromJson(Map<String, dynamic> json) {
    return ProcessInfo(
      pid: json['pid'] as int,
      user: json['user'] as String,
      cpu: (json['cpu'] as num).toDouble(),
      memory: (json['memory'] as num).toDouble(),
      command: json['command'] as String,
      state: json['state'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pid': pid,
      'user': user,
      'cpu': cpu,
      'memory': memory,
      'command': command,
      'state': state,
    };
  }
}

/// Represents a log entry
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? source;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.source,
  });

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      timestamp: DateTime.parse(json['timestamp'] as String),
      level: LogLevel.fromString(json['level'] as String? ?? 'INFO'),
      message: json['message'] as String,
      source: json['source'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level.toString(),
      'message': message,
      'source': source,
    };
  }
}

enum LogLevel {
  error,
  warn,
  info,
  debug;

  static LogLevel fromString(String value) {
    switch (value.toUpperCase()) {
      case 'ERROR':
      case 'ERR':
        return LogLevel.error;
      case 'WARN':
      case 'WARNING':
        return LogLevel.warn;
      case 'INFO':
        return LogLevel.info;
      case 'DEBUG':
        return LogLevel.debug;
      default:
        return LogLevel.info;
    }
  }

  @override
  String toString() {
    switch (this) {
      case LogLevel.error:
        return 'ERROR';
      case LogLevel.warn:
        return 'WARN';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.debug:
        return 'DEBUG';
    }
  }
}

// Made with Bob
