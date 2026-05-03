import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'server_config.dart';

/// Service for securely storing server configurations
class SecureStorageService {
  static const String _serversKey = 'servers';
  static const String _serverPrefix = 'server_';
  
  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
          ),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock,
          ),
        );

  /// Save a server configuration
  Future<void> saveServer(ServerConfig server) async {
    try {
      // Save the server data
      final serverJson = server.toJsonString();
      await _storage.write(
        key: '$_serverPrefix${server.id}',
        value: serverJson,
      );

      // Update the server list
      final serverIds = await _getServerIds();
      if (!serverIds.contains(server.id)) {
        serverIds.add(server.id);
        await _saveServerIds(serverIds);
      }
    } catch (e) {
      throw StorageException('Failed to save server: $e');
    }
  }

  /// Load a server configuration by ID
  Future<ServerConfig?> loadServer(String id) async {
    try {
      final serverJson = await _storage.read(key: '$_serverPrefix$id');
      if (serverJson == null) return null;
      return ServerConfig.fromJsonString(serverJson);
    } catch (e) {
      throw StorageException('Failed to load server: $e');
    }
  }

  /// Load all server configurations
  Future<List<ServerConfig>> loadAllServers() async {
    try {
      final serverIds = await _getServerIds();
      final servers = <ServerConfig>[];

      for (final id in serverIds) {
        final server = await loadServer(id);
        if (server != null) {
          servers.add(server);
        }
      }

      // Sort by last connected (most recent first), then by nickname
      servers.sort((a, b) {
        if (a.lastConnectedAt != null && b.lastConnectedAt != null) {
          return b.lastConnectedAt!.compareTo(a.lastConnectedAt!);
        }
        if (a.lastConnectedAt != null) return -1;
        if (b.lastConnectedAt != null) return 1;
        return a.nickname.compareTo(b.nickname);
      });

      return servers;
    } catch (e) {
      throw StorageException('Failed to load servers: $e');
    }
  }

  /// Update a server configuration
  Future<void> updateServer(ServerConfig server) async {
    try {
      final exists = await loadServer(server.id);
      if (exists == null) {
        throw StorageException('Server not found: ${server.id}');
      }
      await saveServer(server);
    } catch (e) {
      throw StorageException('Failed to update server: $e');
    }
  }

  /// Delete a server configuration
  Future<void> deleteServer(String id) async {
    try {
      // Delete the server data
      await _storage.delete(key: '$_serverPrefix$id');

      // Update the server list
      final serverIds = await _getServerIds();
      serverIds.remove(id);
      await _saveServerIds(serverIds);
    } catch (e) {
      throw StorageException('Failed to delete server: $e');
    }
  }

  /// Update last connected timestamp for a server
  Future<void> updateLastConnected(String id) async {
    try {
      final server = await loadServer(id);
      if (server != null) {
        final updatedServer = server.copyWith(
          lastConnectedAt: DateTime.now(),
        );
        await saveServer(updatedServer);
      }
    } catch (e) {
      throw StorageException('Failed to update last connected: $e');
    }
  }

  /// Clear all stored data
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      throw StorageException('Failed to clear storage: $e');
    }
  }

  /// Get list of server IDs
  Future<List<String>> _getServerIds() async {
    try {
      final idsJson = await _storage.read(key: _serversKey);
      if (idsJson == null) return [];
      final List<dynamic> idsList = jsonDecode(idsJson);
      return idsList.cast<String>();
    } catch (e) {
      return [];
    }
  }

  /// Save list of server IDs
  Future<void> _saveServerIds(List<String> ids) async {
    try {
      await _storage.write(
        key: _serversKey,
        value: jsonEncode(ids),
      );
    } catch (e) {
      throw StorageException('Failed to save server IDs: $e');
    }
  }

  /// Check if a server exists
  Future<bool> serverExists(String id) async {
    try {
      final server = await loadServer(id);
      return server != null;
    } catch (e) {
      return false;
    }
  }

  /// Get server count
  Future<int> getServerCount() async {
    try {
      final serverIds = await _getServerIds();
      return serverIds.length;
    } catch (e) {
      return 0;
    }
  }
}

/// Exception thrown when storage operations fail
class StorageException implements Exception {
  final String message;
  StorageException(this.message);

  @override
  String toString() => 'StorageException: $message';
}

// Made with Bob
