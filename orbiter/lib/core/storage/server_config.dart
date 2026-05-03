import 'dart:convert';

/// Authentication method for SSH connection
enum AuthMethod {
  password,
  privateKey,
}

/// Server configuration model
class ServerConfig {
  final String id;
  final String nickname;
  final String hostname;
  final int port;
  final String username;
  final AuthMethod authMethod;
  final String? password;
  final String? privateKey;
  final DateTime createdAt;
  final DateTime? lastConnectedAt;

  ServerConfig({
    required this.id,
    required this.nickname,
    required this.hostname,
    this.port = 22,
    required this.username,
    required this.authMethod,
    this.password,
    this.privateKey,
    DateTime? createdAt,
    this.lastConnectedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Create a copy with updated fields
  ServerConfig copyWith({
    String? id,
    String? nickname,
    String? hostname,
    int? port,
    String? username,
    AuthMethod? authMethod,
    String? password,
    String? privateKey,
    DateTime? createdAt,
    DateTime? lastConnectedAt,
  }) {
    return ServerConfig(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      hostname: hostname ?? this.hostname,
      port: port ?? this.port,
      username: username ?? this.username,
      authMethod: authMethod ?? this.authMethod,
      password: password ?? this.password,
      privateKey: privateKey ?? this.privateKey,
      createdAt: createdAt ?? this.createdAt,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'hostname': hostname,
      'port': port,
      'username': username,
      'authMethod': authMethod.name,
      'password': password,
      'privateKey': privateKey,
      'createdAt': createdAt.toIso8601String(),
      'lastConnectedAt': lastConnectedAt?.toIso8601String(),
    };
  }

  /// Create from JSON
  factory ServerConfig.fromJson(Map<String, dynamic> json) {
    return ServerConfig(
      id: json['id'] as String,
      nickname: json['nickname'] as String,
      hostname: json['hostname'] as String,
      port: json['port'] as int? ?? 22,
      username: json['username'] as String,
      authMethod: AuthMethod.values.firstWhere(
        (e) => e.name == json['authMethod'],
        orElse: () => AuthMethod.password,
      ),
      password: json['password'] as String?,
      privateKey: json['privateKey'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastConnectedAt: json['lastConnectedAt'] != null
          ? DateTime.parse(json['lastConnectedAt'] as String)
          : null,
    );
  }

  /// Convert to JSON string
  String toJsonString() => jsonEncode(toJson());

  /// Create from JSON string
  factory ServerConfig.fromJsonString(String jsonString) {
    return ServerConfig.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  @override
  String toString() {
    return 'ServerConfig(id: $id, nickname: $nickname, hostname: $hostname:$port, username: $username)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ServerConfig && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Made with Bob
