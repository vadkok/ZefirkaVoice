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
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Opacity(
                opacity: 0.5,
                child: Image.asset(
                  'girl.png',
                  height: 200,
                  fit: BoxFit.contain,
                  color: const Color(0xFF7CBFAD).withOpacity(0.85),
                  colorBlendMode: BlendMode.modulate,
                ),
              ),
              const SizedBox(height: 40),
              if (_downloading) ...[
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.grey.shade800,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF7CBFAD),
                  ),
                  minHeight: 6,
                ),
                const SizedBox(height: 12),
              ],
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF7CBFAD),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final VoskService _vosk = VoskService();
  final CommandsService _commands = CommandsService();
  final WebSocketService _ws = WebSocketService();

  bool _isListening = false;
  bool _wasListening = false;
  bool _flash = false;
  bool _voskReady = false;
  bool _waitingForCommand = false;
  String _lastText = '';
  String _lastAction = '';

  // >>> Шторка
  bool _drawerOpen = false;
  // Высота шторки (такая же, как была раньше для двух плашек + отступ)
  static const double _drawerHeight = 180;

  // >>> Авто-скрытие плашки "Отправлено"
  Timer? _actionTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isListening = false;
          _wasListening = false;
          _lastText = 'Ошибка: $e';
        });
      }
    }
  }

  Future<void> _init() async {
    await _commands.load();

    // WebSocket — подключение
    if (_commands.url.isNotEmpty) {
      _ws.init(_commands.url);
      _ws.onMessage = (text) {
        // Ответы OSSM пока игнорируем
      };
      await _ws.connect();
    }

    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      setState(() => _lastText = 'Микрофон не разрешён');
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
    } catch (e) {
      setState(() => _lastText = 'Ошибка Vosk: $e');
    }
  }

  void _handleResult(String text) {
    final lower = text.toLowerCase();

    if (_commands.hasWakeWord(lower)) {
      _doFlash();
      final cleaned = _commands.stripWakeWord(text);

      final cmd = _commands.findCommand(cleaned);
      if (cmd != null) {
        _executeCommand(cmd);
        setState(() => _waitingForCommand = false);
      } else {
        setState(() => _waitingForCommand = true);
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
    _doFlash();

    final sent = _ws.send(cmd.json);

    setState(() {
      _lastAction = sent
          ? 'Отправлено: ${_commands.primaryPhrase(cmd)}'
          : 'Ошибка: нет связи';
    });

    // >>> Авто-скрытие через 2 секунды
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

  void _doFlash() {
    setState(() => _flash = true);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _flash = false);
    });
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
              });
              _actionTimer?.cancel();
              _actionTimer = Timer(const Duration(seconds: 2), () {
                if (mounted) setState(() => _lastAction = '');
              });
            }
            _reconnectWs();
          },
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
    } else {
      setState(() => _lastText = 'Запуск...');
      await _restartVosk();
    }
  }

  // >>> Управление шторкой
  void _openDrawer() {
    if (!_drawerOpen) setState(() => _drawerOpen = true);
  }

  void _closeDrawer() {
    if (_drawerOpen) setState(() => _drawerOpen = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _actionTimer?.cancel();
    _vosk.dispose();
    _ws.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    // Область свайпа — нижние 25% экрана (можно потянуть вверх)
    final swipeZoneHeight = screenHeight * 0.25;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ===== ОСНОВНОЙ ЖЕСТ: тап — слушать/не слушать =====
          GestureDetector(
            onTap: _toggleListening,
            behavior: HitTestBehavior.opaque,
            child: SizedBox.expand(
              child: Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 400),
                  opacity: _isListening ? 0.85 : 0.15,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      boxShadow: _flash
                          ? [
                              BoxShadow(
                                color: const Color(0xFF7CBFAD).withOpacity(0.8),
                                blurRadius: 80,
                                spreadRadius: 20,
                              ),
                            ]
                          : [],
                    ),
                    child: Image.asset(
                      'girl.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      color: const Color(0xFF7CBFAD).withOpacity(0.85),
                      colorBlendMode: BlendMode.modulate,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ===== ОБЛАСТЬ СВАЙПА СНИЗУ ВВЕРХ (открыть шторку) =====
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

          // ===== КНОПКА "КОМАНДЫ" (видна только когда шторка открыта) =====
          Positioned(
            top: 40,
            right: 20,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _drawerOpen ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !_drawerOpen,
                child: GestureDetector(
                  onTap: _openEditor,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF7CBFAD).withOpacity(0.6),
                      ),
                    ),
                    child: const Text(
                      'команды',
                      style: TextStyle(
                        color: Color(0xFF7CBFAD),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ===== ШТОРКА (снизу вверх) =====
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            bottom: _drawerOpen ? 0 : -_drawerHeight - 20,
            height: _drawerHeight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null &&
                    details.primaryVelocity! > 200) {
                  _closeDrawer();
                }
              },
              onTap: _closeDrawer,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.92),
                  border: Border(
                    top: BorderSide(
                      color: const Color(0xFF7CBFAD).withOpacity(0.4),
                      width: 1,
                    ),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ручка шторки
                    Container(
                      width: 40,
                      height: 3,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7CBFAD).withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Распознанный текст
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF7CBFAD).withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          _lastText.isEmpty ? '...' : _lastText,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFF7CBFAD)
                                .withOpacity(_lastText.isEmpty ? 0.4 : 1.0),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Плашка "Отправлено" — прозрачная, только обводка + мятный текст
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      opacity: _lastAction.isNotEmpty ? 1.0 : 0.0,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF7CBFAD).withOpacity(0.5),
                          ),
                        ),
                        child: Text(
                          _lastAction,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF7CBFAD),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
