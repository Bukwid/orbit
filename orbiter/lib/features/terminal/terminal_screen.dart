import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import 'package:xterm/flutter.dart';
import '../../core/ssh/ssh_service.dart';
import '../../core/storage/server_config.dart';

/// Terminal screen with xterm emulator
class TerminalScreen extends StatefulWidget {
  final ServerConfig server;
  final SSHService sshService;

  const TerminalScreen({
    super.key,
    required this.server,
    required this.sshService,
  });

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  late final Terminal _terminal;
  late final TerminalController _terminalController;
  SSHSession? _session;
  StreamSubscription? _shellSubscription;
  double _fontSize = 14.0;
  bool _isConnecting = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(
      maxLines: 10000,
    );
    _terminalController = TerminalController();
    _connectToServer();
  }

  Future<void> _connectToServer() async {
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      // Connect to server
      _session = await widget.sshService.connect(widget.server);

      // Open shell
      final shell = await _session!.client.shell(
        pty: SSHPtyConfig(
          width: _terminal.viewWidth,
          height: _terminal.viewHeight,
        ),
      );

      // Handle terminal input
      _terminal.onOutput = (data) {
        shell.write(utf8.encode(data) as Uint8List);
      };

      // Handle terminal resize
      _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
        shell.resizeTerminal(width, height, pixelWidth, pixelHeight);
      };

      // Handle shell output
      _shellSubscription = shell.stdout.listen((data) {
        _terminal.write(utf8.decode(data));
      });

      // Handle shell errors
      shell.stderr.listen((data) {
        _terminal.write(utf8.decode(data));
      });

      // Handle shell done
      shell.done.then((_) {
        if (mounted) {
          _terminal.write('\r\n[Connection closed]\r\n');
          setState(() {
            _isConnecting = false;
          });
        }
      }).catchError((error) {
        if (mounted) {
          _terminal.write('\r\n[Error: $error]\r\n');
          setState(() {
            _isConnecting = false;
            _errorMessage = error.toString();
          });
        }
      });

      setState(() {
        _isConnecting = false;
      });
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _errorMessage = e.toString();
      });
      _terminal.write('Failed to connect: $e\r\n');
    }
  }

  void _increaseFontSize() {
    setState(() {
      _fontSize = (_fontSize + 2).clamp(8.0, 32.0);
    });
  }

  void _decreaseFontSize() {
    setState(() {
      _fontSize = (_fontSize - 2).clamp(8.0, 32.0);
    });
  }

  void _sendSpecialKey(String key) {
    switch (key) {
      case 'Tab':
        _terminal.keyInput(TerminalKey.tab);
        break;
      case 'Ctrl+C':
        _terminal.textInput('\x03');
        break;
      case 'Ctrl+D':
        _terminal.textInput('\x04');
        break;
      case 'Ctrl+Z':
        _terminal.textInput('\x1a');
        break;
      case 'Esc':
        _terminal.keyInput(TerminalKey.escape);
        break;
      case 'Up':
        _terminal.keyInput(TerminalKey.arrowUp);
        break;
      case 'Down':
        _terminal.keyInput(TerminalKey.arrowDown);
        break;
      case 'Left':
        _terminal.keyInput(TerminalKey.arrowLeft);
        break;
      case 'Right':
        _terminal.keyInput(TerminalKey.arrowRight);
        break;
    }
  }

  Future<void> _copySelection() async {
    final selection = _terminal.selection;
    if (selection != null) {
      final text = _terminal.buffer.getText(selection);
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copied to clipboard'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      _terminal.textInput(data!.text!);
    }
  }

  @override
  void dispose() {
    _shellSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.server.nickname),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: _increaseFontSize,
            tooltip: 'Increase font size',
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: _decreaseFontSize,
            tooltip: 'Decrease font size',
          ),
          IconButton(
            icon: const Icon(Icons.content_copy),
            onPressed: _copySelection,
            tooltip: 'Copy',
          ),
          IconButton(
            icon: const Icon(Icons.content_paste),
            onPressed: _paste,
            tooltip: 'Paste',
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection status
          if (_isConnecting)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.orange,
              child: const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Connecting...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.red,
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  TextButton(
                    onPressed: _connectToServer,
                    child: const Text(
                      'Retry',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

          // Terminal
          Expanded(
            child: TerminalView(
              _terminal,
              controller: _terminalController,
              autofocus: true,
              backgroundOpacity: 1.0,
              padding: const EdgeInsets.all(8),
              theme: TerminalTheme(
                cursor: isDark ? Colors.white : Colors.black,
                selection: isDark ? Colors.white24 : Colors.black26,
                foreground: isDark ? Colors.white : Colors.black,
                background: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                black: isDark ? Colors.black : const Color(0xFF000000),
                red: const Color(0xFFCD3131),
                green: const Color(0xFF0DBC79),
                yellow: const Color(0xFFE5E510),
                blue: const Color(0xFF2472C8),
                magenta: const Color(0xFFBC3FBC),
                cyan: const Color(0xFF11A8CD),
                white: isDark ? Colors.white : const Color(0xFF555555),
                brightBlack: const Color(0xFF666666),
                brightRed: const Color(0xFFF14C4C),
                brightGreen: const Color(0xFF23D18B),
                brightYellow: const Color(0xFFF5F543),
                brightBlue: const Color(0xFF3B8EEA),
                brightMagenta: const Color(0xFFD670D6),
                brightCyan: const Color(0xFF29B8DB),
                brightWhite: Colors.white,
                searchHitBackground: const Color(0xFFFFFF2B),
                searchHitBackgroundCurrent: const Color(0xFF31FF26),
                searchHitForeground: Colors.black,
              ),
              textStyle: TerminalStyle(
                fontSize: _fontSize,
                fontFamily: 'monospace',
              ),
            ),
          ),

          // Keyboard shortcuts bar
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: theme.dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  _ShortcutButton(
                    label: 'Tab',
                    onPressed: () => _sendSpecialKey('Tab'),
                  ),
                  _ShortcutButton(
                    label: 'Ctrl+C',
                    onPressed: () => _sendSpecialKey('Ctrl+C'),
                  ),
                  _ShortcutButton(
                    label: 'Ctrl+D',
                    onPressed: () => _sendSpecialKey('Ctrl+D'),
                  ),
                  _ShortcutButton(
                    label: 'Ctrl+Z',
                    onPressed: () => _sendSpecialKey('Ctrl+Z'),
                  ),
                  _ShortcutButton(
                    label: 'Esc',
                    onPressed: () => _sendSpecialKey('Esc'),
                  ),
                  _ShortcutButton(
                    label: '↑',
                    onPressed: () => _sendSpecialKey('Up'),
                  ),
                  _ShortcutButton(
                    label: '↓',
                    onPressed: () => _sendSpecialKey('Down'),
                  ),
                  _ShortcutButton(
                    label: '←',
                    onPressed: () => _sendSpecialKey('Left'),
                  ),
                  _ShortcutButton(
                    label: '→',
                    onPressed: () => _sendSpecialKey('Right'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _ShortcutButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}

// Made with Bob
