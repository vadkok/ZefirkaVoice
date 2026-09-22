import 'package:flutter/material.dart';

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
      home: const HomeScreen(),
    );
  }
}

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

  // Имитация "мигания" — для теста UI.
  // Позже здесь будет реальный Vosk.
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
