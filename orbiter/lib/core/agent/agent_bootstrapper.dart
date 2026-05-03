import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'agent_api_service.dart';

/// Handles agent bootstrap, installation, and lifecycle
class AgentBootstrapper {
  static const String agentVersion = '1.0.0';
  static const String agentPath = '~/.orbiter/agent';
  static const String agentLogPath = '~/.orbiter/agent.log';
  static const int agentPort = 7433;
  
  // IBM Cloud Object Storage URLs for agent binaries
  static const Map<String, String> agentDownloadUrls = {
    'x86_64': 'https://orbiter-agent.s3.us-south.cloud-object-storage.appdomain.cloud/agent-linux-amd64',
    'aarch64': 'https://orbiter-agent.s3.us-south.cloud-object-storage.appdomain.cloud/agent-linux-arm64',
    'arm64': 'https://orbiter-agent.s3.us-south.cloud-object-storage.appdomain.cloud/agent-linux-arm64',
  };

  final SSHClient sshClient;
  final String authToken;

  AgentBootstrapper({
    required this.sshClient,
    required this.authToken,
  });

  /// Bootstrap the agent on the remote server
  Future<void> bootstrap() async {
    print('Starting agent bootstrap...');

    // 1. Detect architecture
    final arch = await detectArchitecture();
    print('Detected architecture: $arch');

    // 2. Check if agent exists and version
    final needsUpdate = await checkAgentVersion();
    print('Agent needs update: $needsUpdate');

    if (needsUpdate) {
      // 3. Download agent binary
      print('Downloading agent for $arch...');
      final binary = await downloadAgent(arch);

      // 4. Transfer via SFTP
      print('Transferring agent via SFTP...');
      await transferAgent(binary);

      // 5. Install agent
      print('Installing agent...');
      await installAgent();
    }

    // 6. Launch agent
    print('Launching agent...');
    await launchAgent();

    // 7. Open SSH tunnel
    print('Opening SSH tunnel...');
    await openTunnel();

    // 8. Health check
    print('Performing health check...');
    final healthy = await healthCheck();
    
    if (!healthy) {
      throw Exception('Agent health check failed');
    }

    print('Agent bootstrap completed successfully!');
  }

  /// Detect server architecture
  Future<String> detectArchitecture() async {
    final result = await sshClient.run('uname -m');
    final arch = String.fromCharCodes(result).trim();
    
    // Normalize architecture names
    if (arch == 'x86_64' || arch == 'amd64') {
      return 'x86_64';
    } else if (arch == 'aarch64' || arch == 'arm64') {
      return 'aarch64';
    }
    
    throw Exception('Unsupported architecture: $arch');
  }

  /// Check if agent exists and needs update
  Future<bool> checkAgentVersion() async {
    try {
      // Check if agent exists
      final checkResult = await sshClient.run('test -f $agentPath && echo "exists" || echo "missing"');
      final exists = String.fromCharCodes(checkResult).trim() == 'exists';
      
      if (!exists) {
        return true; // Needs installation
      }

      // Check version
      final versionResult = await sshClient.run('$agentPath --version 2>&1 || echo "error"');
      final versionOutput = String.fromCharCodes(versionResult).trim();
      
      if (versionOutput.contains(agentVersion)) {
        return false; // Version matches, no update needed
      }
      
      return true; // Version mismatch, needs update
    } catch (e) {
      print('Error checking agent version: $e');
      return true; // On error, assume update needed
    }
  }

  /// Download agent binary from IBM Cloud Object Storage
  Future<List<int>> downloadAgent(String arch) async {
    final url = agentDownloadUrls[arch];
    if (url == null) {
      throw Exception('No download URL for architecture: $arch');
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Failed to download agent: HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to download agent: $e');
    }
  }

  /// Transfer agent binary via SFTP
  Future<void> transferAgent(List<int> binary) async {
    try {
      // Create .orbiter directory if it doesn't exist
      await sshClient.run('mkdir -p ~/.orbiter');

      // Use SFTP to transfer the binary
      final sftp = await sshClient.sftp();
      final file = await sftp.open(
        '$agentPath.tmp',
        mode: SftpFileOpenMode.create | SftpFileOpenMode.write | SftpFileOpenMode.truncate,
      );
      
      await file.write(Stream.value(binary));
      await file.close();
      
    } catch (e) {
      throw Exception('Failed to transfer agent: $e');
    }
  }

  /// Install agent (make executable and move to final location)
  Future<void> installAgent() async {
    try {
      // Make executable and move to final location
      await sshClient.run('chmod +x $agentPath.tmp && mv $agentPath.tmp $agentPath');
    } catch (e) {
      throw Exception('Failed to install agent: $e');
    }
  }

  /// Launch agent in background
  Future<void> launchAgent() async {
    try {
      // Kill any existing agent process
      await sshClient.run('pkill -f "$agentPath" || true');
      
      // Wait a moment for the process to die
      await Future.delayed(const Duration(seconds: 1));

      // Launch agent with nohup
      final command = 'nohup $agentPath --port $agentPort --token $authToken > $agentLogPath 2>&1 &';
      await sshClient.run(command);
      
      // Wait for agent to start
      await Future.delayed(const Duration(seconds: 2));
    } catch (e) {
      throw Exception('Failed to launch agent: $e');
    }
  }

  /// Open SSH tunnel for agent port
  Future<void> openTunnel() async {
    try {
      // Forward local port to remote agent port
      final forward = await sshClient.forwardLocal(
        '127.0.0.1',
        agentPort,
        '127.0.0.1',
        agentPort,
      );
      
      print('SSH tunnel opened: localhost:$agentPort -> remote:$agentPort');
    } catch (e) {
      throw Exception('Failed to open SSH tunnel: $e');
    }
  }

  /// Perform health check on agent
  Future<bool> healthCheck() async {
    try {
      final api = AgentApiService(
        baseUrl: 'http://127.0.0.1:$agentPort',
        authToken: authToken,
      );
      
      // Retry health check a few times
      for (int i = 0; i < 5; i++) {
        final healthy = await api.healthCheck();
        if (healthy) {
          return true;
        }
        await Future.delayed(const Duration(seconds: 1));
      }
      
      return false;
    } catch (e) {
      print('Health check error: $e');
      return false;
    }
  }

  /// Stop the agent
  Future<void> stopAgent() async {
    try {
      await sshClient.run('pkill -f "$agentPath" || true');
    } catch (e) {
      print('Error stopping agent: $e');
    }
  }

  /// Get agent logs
  Future<String> getAgentLogs({int lines = 100}) async {
    try {
      final result = await sshClient.run('tail -n $lines $agentLogPath 2>&1 || echo "No logs available"');
      return String.fromCharCodes(result);
    } catch (e) {
      return 'Error reading logs: $e';
    }
  }
}

// Made with Bob
