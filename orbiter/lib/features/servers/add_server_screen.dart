import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/storage/server_config.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../core/ssh/ssh_service.dart';
import '../terminal/terminal_screen.dart';

/// Screen for adding a new server
class AddServerScreen extends StatefulWidget {
  final SecureStorageService storageService;
  final SSHService sshService;

  const AddServerScreen({
    super.key,
    required this.storageService,
    required this.sshService,
  });

  @override
  State<AddServerScreen> createState() => _AddServerScreenState();
}

class _AddServerScreenState extends State<AddServerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _hostnameController = TextEditingController();
  final _portController = TextEditingController(text: '22');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _privateKeyController = TextEditingController();

  AuthMethod _authMethod = AuthMethod.password;
  bool _isConnecting = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nicknameController.dispose();
    _hostnameController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _privateKeyController.dispose();
    super.dispose();
  }

  Future<void> _pickPrivateKeyFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pem', 'key', 'ppk'],
      );

      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        if (file.bytes != null) {
          _privateKeyController.text = String.fromCharCodes(file.bytes!);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load key file: $e')),
        );
      }
    }
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isConnecting = true;
    });

    try {
      // Create server config
      final config = ServerConfig(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        nickname: _nicknameController.text.trim(),
        hostname: _hostnameController.text.trim(),
        port: int.parse(_portController.text.trim()),
        username: _usernameController.text.trim(),
        authMethod: _authMethod,
        password: _authMethod == AuthMethod.password
            ? _passwordController.text
            : null,
        privateKey: _authMethod == AuthMethod.privateKey
            ? _privateKeyController.text
            : null,
      );

      // Test connection
      await widget.sshService.connect(config);

      // Save server
      await widget.storageService.saveServer(config);
      await widget.storageService.updateLastConnected(config.id);

      if (mounted) {
        // Navigate to terminal
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => TerminalScreen(
              server: config,
              sshService: widget.sshService,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isConnecting = false;
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Connection Failed'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Server'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Nickname
            TextFormField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: 'Nickname',
                hintText: 'My Server',
                prefixIcon: Icon(Icons.label),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a nickname';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Hostname
            TextFormField(
              controller: _hostnameController,
              decoration: const InputDecoration(
                labelText: 'Hostname or IP',
                hintText: 'example.com or 192.168.1.100',
                prefixIcon: Icon(Icons.dns),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a hostname or IP';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Port
            TextFormField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: 'Port',
                hintText: '22',
                prefixIcon: Icon(Icons.settings_ethernet),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a port';
                }
                final port = int.tryParse(value.trim());
                if (port == null || port < 1 || port > 65535) {
                  return 'Please enter a valid port (1-65535)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Username
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                hintText: 'root',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a username';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Auth method selector
            Text(
              'Authentication Method',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SegmentedButton<AuthMethod>(
              segments: const [
                ButtonSegment(
                  value: AuthMethod.password,
                  label: Text('Password'),
                  icon: Icon(Icons.password),
                ),
                ButtonSegment(
                  value: AuthMethod.privateKey,
                  label: Text('Private Key'),
                  icon: Icon(Icons.key),
                ),
              ],
              selected: {_authMethod},
              onSelectionChanged: (Set<AuthMethod> newSelection) {
                setState(() {
                  _authMethod = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 16),

            // Password field
            if (_authMethod == AuthMethod.password)
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscurePassword,
                validator: (value) {
                  if (_authMethod == AuthMethod.password &&
                      (value == null || value.isEmpty)) {
                    return 'Please enter a password';
                  }
                  return null;
                },
              ),

            // Private key field
            if (_authMethod == AuthMethod.privateKey) ...[
              TextFormField(
                controller: _privateKeyController,
                decoration: InputDecoration(
                  labelText: 'Private Key',
                  hintText: '-----BEGIN OPENSSH PRIVATE KEY-----',
                  prefixIcon: const Icon(Icons.vpn_key),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.folder_open),
                    onPressed: _pickPrivateKeyFile,
                    tooltip: 'Load from file',
                  ),
                ),
                maxLines: 5,
                validator: (value) {
                  if (_authMethod == AuthMethod.privateKey &&
                      (value == null || value.trim().isEmpty)) {
                    return 'Please enter or load a private key';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Paste your private key or tap the folder icon to load from file',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Connect button
            FilledButton.icon(
              onPressed: _isConnecting ? null : _connect,
              icon: _isConnecting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.login),
              label: Text(_isConnecting ? 'Connecting...' : 'Connect'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Made with Bob
