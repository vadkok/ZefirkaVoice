import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'download_service.dart';
import 'vosk_service.dart';
import 'commands_service.dart';
import 'commands_editor_screen.dart';
import 'websocket_service.dart';

void main() {
  runApp(const ZefirkaVoiceApp());
}

class ZefirkaVoiceApp extends StatelessWidget {
  const ZefirkaVoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZefirkaVoice',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const SplashScreen(),
    );
  }
}

// ==================== ЭКРАН ЗАГРУЗКИ ====================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _progress = 0.0;
  String _status = 'Проверка модели...';
  bool _downloading = false;

  static const Color _splashBg = Color(0xFFF4FAF8);
  static const Color _splashAccent = Color(0xFF5FA896);
  static const Color _splashText = Color(0xFF3D7A6B);
  static const Color _splashTrack = Color(0xFFC8E6DD);

  @override
  void initState() {
    super.initState();
    _checkModel();
  }

  Future<void> _checkModel() async {
    final ready = await DownloadService.isModelReady();

    if (ready) {
      _goToMain();
      return;
    }

    setState(() {
      _downloading = true;
      _status = 'Скачивание модели (~50 МБ)';
    });

    try {
      await DownloadService.downloadModel(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onStatus: (s) {
          if (mounted) setState(() => _status = s);
        },
      );
      _goToMain();
    } catch (e) {
      setState(() {
        _status = 'Ошибка: $e';
        _downloading = false;
      });
    }
  }

  void _goToMain() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _splashBg,
      body: Stack(
        children: [
          Center(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 400),
              opacity: 0.5,
              child: Image.asset(
                'girl.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                color: _splashAccent.withOpacity(0.85),
                colorBlendMode: BlendMode.modulate,
              ),
            ),
          ),
          Positioned(
            left: 32,
            right: 32,
            bottom: 60,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_downloading) ...[
                  LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: _splashTrack,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      _splashAccent,
                    ),
                    minHeight: 6,
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _splashText,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== ОСНОВНОЙ ЭКРАН ====================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final VoskService _vosk = VoskService();
  final CommandsService _commands = CommandsService();
  final WebSocketService _ws = WebSocketService();

  bool _isListening = false;
  bool _wasListening = false;
  bool _voskReady = false;
  bool _waitingForCommand = false;
  String _lastText = '';
  String _lastAction = '';

  bool _wsConnected = false;

  // >>> Контроллер мигания при потере связи (1.5 сек)
  late AnimationController _pulseController;

  // >>> Контроллер быстрых мигов (250 мс — половина мига)
  late AnimationController _flashController;

  // >>> Флаг, что идёт миг
  bool _isFlashing = false;

  Timer? _reconnectTimer;

  bool _drawerOpen = false;
  bool _debugOpen = false;

  Timer? _actionTimer;

  bool _isDark = false;

  final List<String> _log = [];

  Color get _bgColor =>
      _isDark ? Colors.black : const Color(0xFFF4FAF8);

  Color get _accent =>
      _isDark ? const Color(0xFF7CBFAD) : const Color(0xFF5FA896);

  Color get _textColor =>
      _isDark ? const Color(0xFF7CBFAD) : const Color(0xFF3D7A6B);

  Color get _textSoft =>
      _isDark ? const Color(0xFF7CBFAD) : const Color(0xFF5FA896);

  Color get _panelBg =>
      _isDark ? const Color(0xFF0A0A0A) : Colors.white;

  Color get _panelBorder => _isDark
      ? const Color(0xFF7CBFAD).withOpacity(0.4)
      : const Color(0xFFC8E6DD);

  Color get _plaqueBg => _isDark
      ? Colors.black.withOpacity(0.75)
      : const Color(0xFFF4FAF8);

  Color get _plaqueBorder => _isDark
      ? const Color(0xFF7CBFAD).withOpacity(0.5)
      : const Color(0xFFC8E6DD);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // >>> 250 мс = половина мига (полный миг = 500 мс)
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _wasListening = _isListening;
    } else if (state == AppLifecycleState.resumed) {
      if (_wasListening && !_isListening) {
        _restartVosk();
      }
    }
  }

  void _addLog(String msg) {
    if (!mounted) return;
    final now = DateTime.now();
    final t = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    setState(() {
      _log.add('[$t] $msg');
      if (_log.length > 50) {
        _log.removeRange(0, _log.length - 50);
      }
    });
  }

  // >>> Миг девушки: яркая → тусклая → яркая (один миг = reverse + forward)
  Future<void> _flashGirl(int times) async {
    if (_isFlashing) return;
    _isFlashing = true;
    for (int i = 0; i < times; i++) {
      if (!mounted) return;
      await _flashController.reverse(from: 1);  // яркая → тусклая
      if (!mounted) return;
      await _flashController.forward(from: 0);  // тусклая → яркая
    }
    if (mounted) {
      _flashController.value = 1;
      _isFlashing = false;
    }
  }

  void _updatePulseState() {
    if (_isListening && !_wsConnected) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.value = 0;
      }
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () async {
      if (!mounted) return;
      if (_wsConnected) return;
      await _reconnectWs();
      if (!_wsConnected) _scheduleReconnect();
    });
  }

  Future<void> _restartVosk() async {
    try {
      final modelPath = await DownloadService.getModelPath();
      await _vosk.reinit(modelPath);

      _vosk.onPartial = (text) {
        if (mounted) setState(() => _lastText = text);
      };
      _vosk.onResult = (text) {
        if (mounted) {
          setState(() => _lastText = text);
          _handleResult(text);
        }
      };

      await _vosk.start();
      if (mounted) {
        setState(() {
          _isListening = true;
          _wasListening = true;
          _lastText = 'Слушаю...';
        });
        _updatePulseState();
        _addLog('Vosk: слушаю');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isListening = false;
          _wasListening = false;
          _lastText = 'Ошибка: $e';
        });
        _updatePulseState();
        _addLog('Ошибка Vosk: $e');
      }
    }
  }

  Future<void> _init() async {
    await _commands.load();

    if (mounted) {
      setState(() => _isDark = _commands.isDark);
      _addLog('Команды загружены');
    }

    if (_commands.url.isNotEmpty) {
      _ws.init(_commands.url);

      _ws.onMessage = (text) {
        _addLog('<- $text');
      };

      _ws.onConnect = () {
        if (mounted) {
          setState(() => _wsConnected = true);
          _updatePulseState();
          _addLog('WebSocket: подключено');
        }
        _reconnectTimer?.cancel();
      };

      _ws.onDisconnect = () {
        if (mounted) {
          setState(() => _wsConnected = false);
          _updatePulseState();
          _addLog('WebSocket: отключено');
        }
        _scheduleReconnect();
      };

      await _ws.connect();

      if (mounted) {
        setState(() => _wsConnected = _ws.isConnected);
        _updatePulseState();
      }
    }

    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      setState(() => _lastText = 'Микрофон не разрешён');
      _addLog('Микрофон не разрешён');
      return;
    }

    try {
      final modelPath = await DownloadService.getModelPath();
      await _vosk.init(modelPath);

      _vosk.onPartial = (text) {
        if (mounted) setState(() => _lastText = text);
      };

      _vosk.onResult = (text) {
        if (mounted) {
          setState(() => _lastText = text);
          _handleResult(text);
        }
      };

      setState(() => _voskReady = true);
      _addLog('Vosk готов');
    } catch (e) {
      setState(() => _lastText = 'Ошибка Vosk: $e');
      _addLog('Ошибка Vosk: $e');
    }
  }

  void _handleResult(String text) {
    final lower = text.toLowerCase();
    _addLog('Услышано: $text');

    if (_commands.hasWakeWord(lower)) {
      // >>> Wake word — 1 миг
      _flashGirl(1);
      final cleaned = _commands.stripWakeWord(text);
      _addLog('Wake word. Команда: "$cleaned"');

      final cmd = _commands.findCommand(cleaned);
      if (cmd != null) {
        _executeCommand(cmd);
        setState(() => _waitingForCommand = false);
      } else {
        setState(() => _waitingForCommand = true);
        _addLog('Команда не найдена, жду');
      }
      return;
    }

    if (_waitingForCommand) {
      final cmd = _commands.findCommand(text);
      if (cmd != null) {
        _executeCommand(cmd);
        setState(() => _waitingForCommand = false);
      }
    }
  }

  void _executeCommand(VoiceCommand cmd) {
    // >>> Команда — 2 мига
    _flashGirl(2);

    final sent = _ws.send(cmd.json);

    setState(() {
      _lastAction = sent
          ? 'Отправлено: ${_commands.primaryPhrase(cmd)}'
          : 'Ошибка: нет связи';
    });

    if (sent) {
      _addLog('Отправлено: ${_commands.primaryPhrase(cmd)}');
    } else {
      _addLog('Отправка не удалась');
    }

    _actionTimer?.cancel();
    _actionTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _lastAction = '');
    });

    if (!sent) {
      _reconnectWs();
    }
  }

  Future<void> _reconnectWs() async {
    await _ws.disconnect();
    if (_commands.url.isNotEmpty) {
      _ws.init(_commands.url);
      await _ws.connect();
    }
  }

  Future<void> _openEditor() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommandsEditorScreen(
          commands: _commands,
          onSaved: () {
            if (mounted) {
              setState(() {
                _lastAction = 'Команды обновлены';
                _isDark = _commands.isDark;
              });
              _actionTimer?.cancel();
              _actionTimer = Timer(const Duration(seconds: 2), () {
                if (mounted) setState(() => _lastAction = '');
              });
              _addLog('Команды сохранены');
            }
            _reconnectWs();
          },
          isDark: _isDark,
        ),
      ),
    );
  }

  Future<void> _toggleListening() async {
    if (!_voskReady) {
      setState(() => _lastText = 'Vosk не готов');
      return;
    }

    if (_isListening) {
      await _vosk.stop();
      setState(() {
        _isListening = false;
        _wasListening = false;
        _waitingForCommand = false;
        _lastText = '';
      });
      _updatePulseState();
      _addLog('Vosk: стоп');
    } else {
      setState(() => _lastText = 'Запуск...');
      await _restartVosk();
    }
  }

  Future<void> _toggleTheme() async {
    final newIsDark = !_isDark;
    setState(() => _isDark = newIsDark);
    await _commands.saveTheme(newIsDark ? 'dark' : 'light');
  }

  void _openDrawer() {
    if (!_drawerOpen) setState(() => _drawerOpen = true);
  }

  void _closeDrawer() {
    if (_drawerOpen) {
      setState(() {
        _drawerOpen = false;
        _debugOpen = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _actionTimer?.cancel();
    _reconnectTimer?.cancel();
    _pulseController.dispose();
    _flashController.dispose();
    _vosk.dispose();
    _ws.disconnect();
    super.dispose();
  }

  // >>> Логика прозрачности девушки
  double _girlOpacity() {
    if (_isFlashing) {
      return 0.15 + (_flashController.value * 0.7);
    }
    if (!_isListening) return 0.15;
    if (_wsConnected) return 0.85;
    return 0.15 + (_pulseController.value * 0.7);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final swipeZoneHeight = screenHeight * 0.25;

    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          GestureDetector(
            onTap: _toggleListening,
            behavior: HitTestBehavior.opaque,
            child: SizedBox.expand(
              child: Center(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_pulseController, _flashController]),
                  builder: (context, child) {
                    return Opacity(
                      opacity: _girlOpacity(),
                      child: child,
                    );
                  },
                  child: Image.asset(
                    'girl.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    color: _accent.withOpacity(0.85),
                    colorBlendMode: BlendMode.modulate,
                  ),
                ),
              ),
            ),
          ),

          if (!_drawerOpen)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: swipeZoneHeight,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity != null &&
                      details.primaryVelocity! < -200) {
                    _openDrawer();
                  }
                },
                child: const SizedBox.expand(),
              ),
            ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            bottom: _drawerOpen ? 0 : -400,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null &&
                    details.primaryVelocity! > 200) {
                  _closeDrawer();
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: _panelBg,
                    border: Border.all(color: _panelBorder),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 3,
                        decoration: BoxDecoration(
                          color: _textSoft.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        margin: const EdgeInsets.only(bottom: 14),
                      ),

                      GestureDetector(
                        onTap: _closeDrawer,
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(minHeight: 60),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _plaqueBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _plaqueBorder,
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _lastText.isEmpty ? '...' : _lastText,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _textColor.withOpacity(
                                  _lastText.isEmpty ? 0.4 : 1.0),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      if (_lastAction.isNotEmpty)
                        GestureDetector(
                          onTap: _closeDrawer,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _plaqueBorder,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _lastAction,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _accent,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 10),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _footerBtn(
                            text: 'Команды',
                            onTap: _openEditor,
                          ),
                          _footerBtn(
                            text: _isDark ? 'День' : 'Ночь',
                            onTap: _toggleTheme,
                          ),
                          _footerBtn(
                            text: 'Отладка',
                            onTap: () {
                              setState(() => _debugOpen = !_debugOpen);
                            },
                            active: _debugOpen,
                          ),
                        ],
                      ),

                      if (_debugOpen) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          height: 150,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _plaqueBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _plaqueBorder),
                          ),
                          child: _log.isEmpty
                              ? Center(
                                  child: Text(
                                    'лог пуст',
                                    style: TextStyle(
                                      color: _textSoft.withOpacity(0.4),
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  reverse: true,
                                  itemCount: _log.length,
                                  itemBuilder: (context, index) {
                                    final i = _log.length - 1 - index;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 3),
                                      child: Text(
                                        _log[i],
                                        style: TextStyle(
                                          color: _textSoft,
                                          fontSize: 10,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerBtn({
    required String text,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          text,
          style: TextStyle(
            color: active ? _accent : _textSoft.withOpacity(0.75),
            fontSize: 11,
            letterSpacing: 1,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
