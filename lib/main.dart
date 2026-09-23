import 'package:flutter/material.dart';
import 'download_service.dart';

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
// Проверяет, есть ли модель.
// Если нет — скачивает.
// Если есть — переходит к основному экрану.

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
    setState(() {
      _status = 'Проверка модели...';
    });

    final ready = await DownloadService.isModelReady();

    if (ready) {
      setState(() {
        _status = 'Модель готова';
      });
      await Future.delayed(const Duration(milliseconds: 500));
      _goToMain();
    } else {
      setState(() {
        _downloading = true;
        _status = 'Скачивание модели (~50 МБ)';
        _progress = 0.0;
      });

      try {
        await DownloadService.downloadModel(
          onProgress: (p) {
            if (mounted) {
              setState(() {
                _progress = p;
              });
            }
          },
          onStatus: (s) {
            if (mounted) {
              setState(() {
                _status = s;
              });
            }
          },
        );

        setState(() {
          _status = 'Готово!';
        });
        await Future.delayed(const Duration(milliseconds: 500));
        _goToMain();
      } catch (e) {
        setState(() {
          _status = 'Ошибка: $e';
          _downloading = false;
        });
      }
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
              // Картинка (мятная)
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
              
              // Прогресс
              if (_downloading)
                Column(
                  children: [
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
                ),
              
              // Статус
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
// Картинка на весь экран.
// Тап — вкл/выкл прослушивание.

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isListening = false;
  bool _flash = false;

  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
    });
  }

  void _testFlash() {
    setState(() {
      _flash = true;
    });
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          _flash = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleListening,
        onDoubleTap: _testFlash,
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
            ],
          ),
        ),
      ),
    );
  }
}
