import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'core/websocket/websocket_service.dart';
import 'core/ai/watsonx_service.dart';
import 'core/models/metrics_snapshot.dart';

void main() {
  runApp(const OrbiterPOC());
}

class OrbiterPOC extends StatelessWidget {
  const OrbiterPOC({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Orbiter POC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ConnectScreen(),
    );
  }
}

// ============================================================================
// SCREEN 1: Agent Connect Screen (Direct HTTP/WebSocket)
// ============================================================================
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _hostController = TextEditingController(text: '168.144.33.97');
  final _portController = TextEditingController(text: '8090');
  final _tokenController = TextEditingController(text: 'hackathon2024');
  bool _isConnecting = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to Agent'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.cloud, size: 64, color: Colors.blue),
                    const SizedBox(height: 24),
                    const Text(
                      'Agent Connection',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _hostController,
                      decoration: const InputDecoration(
                        labelText: 'Agent Host/IP',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.dns),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _portController,
                      decoration: const InputDecoration(
                        labelText: 'Agent Port',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.settings_ethernet),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _tokenController,
                      decoration: const InputDecoration(
                        labelText: 'Auth Token',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade900),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isConnecting ? null : _connect,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isConnecting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Connect', style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _connect() async {
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      final host = _hostController.text.trim();
      final port = _portController.text.trim();
      final token = _tokenController.text.trim();
      final agentUrl = 'http://$host:$port';

      // Test connection with health check
      final response = await http.get(
        Uri.parse('$agentUrl/health'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        throw Exception('Health check failed: ${response.statusCode}');
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardScreen(
            agentUrl: agentUrl,
            token: token,
            serverName: host,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection failed: $e';
        _isConnecting = false;
      });
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _tokenController.dispose();
    super.dispose();
  }
}

// ============================================================================
// SCREEN 2: Dashboard Screen with Real-time Metrics
// ============================================================================
class DashboardScreen extends StatefulWidget {
  final String agentUrl;
  final String token;
  final String serverName;

  const DashboardScreen({
    super.key,
    required this.agentUrl,
    required this.token,
    required this.serverName,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final WebSocketService _wsService = WebSocketService();
  MetricsSnapshot? _latestMetrics;
  bool _isAnalyzing = false;
  String? _aiAnalysis;
  Timer? _metricsTimer;

  @override
  void initState() {
    super.initState();
    _startMetricsPolling();
  }

  void _startMetricsPolling() {
  _metricsTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
    try {
      final response = await http.get(
        Uri.parse('${widget.agentUrl}/api/metrics'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _latestMetrics = MetricsSnapshot.fromJson(json);
          });
        }
      }
    } catch (e) {
      debugPrint('Metrics poll error: $e');
    }
  });
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard - ${widget.serverName}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _startMetricsPolling();
            },
          ),
        ],
      ),
      body: _latestMetrics == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Connecting to agent...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMetricCard(
                    'CPU Usage',
                    '${_latestMetrics!.cpu.total.toStringAsFixed(1)}%',
                    Icons.memory,
                    Colors.blue,
                    _latestMetrics!.cpu.total,
                  ),
                  const SizedBox(height: 16),
                  _buildMetricCard(
                    'Memory Usage',
                    '${_latestMetrics!.ram.usedPercent.toStringAsFixed(1)}%',
                    Icons.storage,
                    Colors.green,
                    _latestMetrics!.ram.usedPercent,
                  ),
                  const SizedBox(height: 16),
                  _buildMetricCard(
                    'Disk Usage',
                    '${_latestMetrics!.disks.first.usedPercent.toStringAsFixed(1)}%',
                    Icons.sd_card,
                    Colors.orange,
                    _latestMetrics!.disks.first.usedPercent,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isAnalyzing ? null : _analyzeNginxLogs,
                    icon: _isAnalyzing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.analytics),
                    label: const Text('Analyze Nginx Logs with AI'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  if (_aiAnalysis != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: Colors.purple.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.psychology, color: Colors.purple.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'AI Analysis',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(_aiAnalysis!),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
    double percentage,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percentage / 100,
                minHeight: 8,
                backgroundColor: color.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _analyzeNginxLogs() async {
    setState(() {
      _isAnalyzing = true;
      _aiAnalysis = null;
    });

    try {
      // Get last 20 lines of nginx logs via agent API
      final response = await http.post(
        Uri.parse('${widget.agentUrl}/api/exec'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'command': 'tail -n 20 /var/log/nginx/access.log 2>/dev/null || echo "No nginx logs found"',
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to get logs: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final logOutput = data['stdout'] as String? ?? '';
      final logLines = logOutput.trim().split('\n');

      // Analyze with watsonx.ai
      final watsonx = WatsonXService(
        apiKey: '<api_key>',
        projectId: '<project_id>',
        url: 'https://us-south.ml.cloud.ibm.com',
      );

      final analysis = await watsonx.analyzeLogs(logLines);

      setState(() {
        _aiAnalysis = analysis;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _aiAnalysis = 'Error analyzing logs: $e';
        _isAnalyzing = false;
      });
    }
  }

  @override
  void dispose() {
    _metricsTimer?.cancel();
    super.dispose();
  }
}

// Made with Bob
