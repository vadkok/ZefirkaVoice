import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'download_service.dart';
import 'vosk_service.dart';
import 'commands_service.dart';

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

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver {
  final VoskService _vosk = VoskService();
  final CommandsService _commands = CommandsService();

  bool _isListening = false;
  bool _wasListening = false;
  bool _flash = false;
  bool _voskReady = false;
  bool _waitingForCommand = false;
  String _lastText = '';
  String _lastAction = '';

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
      if (_isListening) {
        _vosk.stop();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_wasListening) {
        _restartVosk();
      }
    }
  }

  Future<void> _restartVosk() async {
    try {
      await _vosk.stop();
      await Future.delayed(const Duration(milliseconds: 300));
      await _vosk.start();
      if (mounted) {
        setState(() {
          _isListening = true;
          _lastText = 'Слушаю...';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isListening = false;
          _lastText = 'Ошибка перезапуска: $e';
        });
      }
    }
  }

  Future<void> _init() async {
    await _commands.load();

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
    setState(() {
      _lastAction = 'Команда: ${cmd.phrase}';
    });
  }

  void _doFlash() {
    setState(() => _flash = true);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _flash = false);
    });
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
      });
    } else {
      await _vosk.start();
      setState(() {
        _isListening = true;
        _wasListening = true;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _vosk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleListening,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.expand(
          child: Stack(
            children: [
              Center(
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

              if (_lastText.isNotEmpty)
                Positioned(
                  bottom: 80,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF7CBFAD).withOpacity(0.4),
                      ),
                    ),
                    child: Text(
                      _lastText,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF7CBFAD),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),

              if (_lastAction.isNotEmpty)
                Positioned(
                  bottom: 30,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7CBFAD).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _lastAction,
                      textAlign: TextAlign.center,
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
    );
  }
}
