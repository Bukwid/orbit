class MetricsSnapshot {
  final DateTime timestamp;
  final CpuMetrics cpu;
  final RamMetrics ram;
  final List<DiskMetrics> disks;
  final NetworkMetrics network;

  MetricsSnapshot({
    required this.timestamp,
    required this.cpu,
    required this.ram,
    required this.disks,
    required this.network,
  });

  factory MetricsSnapshot.fromJson(Map<String, dynamic> json) {
    return MetricsSnapshot(
      timestamp: DateTime.parse(json['timestamp'] as String),
      cpu: CpuMetrics.fromJson(json['cpu'] as Map<String, dynamic>),
      ram: RamMetrics.fromJson(json['ram'] as Map<String, dynamic>),
      disks: (json['disk'] as List)
          .map((d) => DiskMetrics.fromJson(d as Map<String, dynamic>))
          .toList(),
      network: NetworkMetrics.fromJson(json['network'] as Map<String, dynamic>),
    );
  }
}

class CpuMetrics {
  final double total;
  final int cores;

  CpuMetrics({required this.total, required this.cores});

  factory CpuMetrics.fromJson(Map<String, dynamic> json) {
    return CpuMetrics(
      total: (json['total'] as num).toDouble(),
      cores: (json['cores'] as List).length,
    );
  }
}

class RamMetrics {
  final int total;
  final int used;
  final double usedPercent;

  RamMetrics({required this.total, required this.used, required this.usedPercent});

  factory RamMetrics.fromJson(Map<String, dynamic> json) {
    final total = json['total'] as int;
    final used = json['used'] as int;
    return RamMetrics(
      total: total,
      used: used,
      usedPercent: total > 0 ? (used / total * 100) : 0.0,
    );
  }
}

class DiskMetrics {
  final String mount;
  final int total;
  final int used;
  final double usedPercent;

  DiskMetrics({required this.mount, required this.total, required this.used, required this.usedPercent});

  factory DiskMetrics.fromJson(Map<String, dynamic> json) {
    final total = json['total'] as int;
    final used = json['used'] as int;
    return DiskMetrics(
      mount: json['mount'] as String,
      total: total,
      used: used,
      usedPercent: total > 0 ? (used / total * 100) : 0.0,
    );
  }
}

class NetworkMetrics {
  final int bytesIn;
  final int bytesOut;

  NetworkMetrics({required this.bytesIn, required this.bytesOut});

  factory NetworkMetrics.fromJson(Map<String, dynamic> json) {
    return NetworkMetrics(
      bytesIn: json['bytesIn'] as int,
      bytesOut: json['bytesOut'] as int,
    );
  }
}

// Made with Bob