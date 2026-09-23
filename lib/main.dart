import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'download_service.dart';
import 'vosk_service.dart';

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

class _HomeScreenState extends State<HomeScreen> {
  final VoskService _vosk = VoskService();

  bool _isListening = false;
  bool _flash = false;
  bool _voskReady = false;
  String _lastText = '';

  @override
  void initState() {
    super.initState();
    _initVosk();
  }

  Future<void> _initVosk() async {
    try {
      // Разрешение на микрофон
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        setState(() => _lastText = 'Микрофон не разрешён');
        return;
      }

      // Загрузка модели
      final modelPath = await DownloadService.getModelPath();
      await _vosk.init(modelPath);

      // Подписки на результаты
      _vosk.onPartial = (text) {
        if (mounted) setState(() => _lastText = text);
      };
      _vosk.onResult = (text) {
        if (mounted) {
          setState(() => _lastText = text);
          _doFlash();
        }
      };

      setState(() => _voskReady = true);
    } catch (e) {
      setState(() => _lastText = 'Ошибка Vosk: $e');
    }
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
      setState(() => _isListening = false);
    } else {
      await _vosk.start();
      setState(() => _isListening = true);
    }
  }

  @override
  void dispose() {
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
              // Картинка
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

              // Распознанный текст (внизу) — для отладки
              if (_lastText.isNotEmpty)
                Positioned(
                  bottom: 40,
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

              // Индикатор Vosk (сверху)
              Positioned(
                top: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    _voskReady ? '' : 'Загрузка Vosk...',
                    style: TextStyle(
                      color: const Color(0xFF7CBFAD).withOpacity(0.6),
                      fontSize: 12,
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
