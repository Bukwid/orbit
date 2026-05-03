/// Represents a system service (systemd or Docker)
class ServiceInfo {
  final String name;
  final ServiceType type;
  final ServiceStatus status;
  final double cpu;
  final int memory;
  final String? description;

  ServiceInfo({
    required this.name,
    required this.type,
    required this.status,
    required this.cpu,
    required this.memory,
    this.description,
  });

  factory ServiceInfo.fromJson(Map<String, dynamic> json) {
    return ServiceInfo(
      name: json['name'] as String,
      type: ServiceType.fromString(json['type'] as String),
      status: ServiceStatus.fromString(json['status'] as String),
      cpu: (json['cpu'] as num).toDouble(),
      memory: json['memory'] as int,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type.toString(),
      'status': status.toString(),
      'cpu': cpu,
      'memory': memory,
      'description': description,
    };
  }
}

enum ServiceType {
  systemd,
  docker;

  static ServiceType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'systemd':
        return ServiceType.systemd;
      case 'docker':
        return ServiceType.docker;
      default:
        return ServiceType.systemd;
    }
  }

  @override
  String toString() {
    switch (this) {
      case ServiceType.systemd:
        return 'systemd';
      case ServiceType.docker:
        return 'docker';
    }
  }
}

enum ServiceStatus {
  running,
  stopped,
  degraded,
  failed,
  unknown;

  static ServiceStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'running':
      case 'active':
        return ServiceStatus.running;
      case 'stopped':
      case 'inactive':
        return ServiceStatus.stopped;
      case 'degraded':
        return ServiceStatus.degraded;
      case 'failed':
        return ServiceStatus.failed;
      default:
        return ServiceStatus.unknown;
    }
  }

  @override
  String toString() {
    switch (this) {
      case ServiceStatus.running:
        return 'running';
      case ServiceStatus.stopped:
        return 'stopped';
      case ServiceStatus.degraded:
        return 'degraded';
      case ServiceStatus.failed:
        return 'failed';
      case ServiceStatus.unknown:
        return 'unknown';
    }
  }
}

// Made with Bob
