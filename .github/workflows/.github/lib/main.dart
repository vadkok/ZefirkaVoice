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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7CBFAD)),
        useMaterial3: true,
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
  final List<String> _log = [];

  void _addLog(String message) {
    setState(() {
      _log.insert(0, '[${DateTime.now().toString().substring(11, 19)}] $message');
      if (_log.length > 50) _log.removeLast();
    });
  }

  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
    });
    _addLog(_isListening ? 'Слушаю...' : 'Остановлено');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZefirkaVoice'),
        backgroundColor: const Color(0xFF7CBFAD),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Статус
            Card(
              color: _isListening
                  ? const Color(0xFFE3F2ED)
                  : Colors.grey.shade200,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      _isListening ? Icons.mic : Icons.mic_off,
                      size: 64,
                      color: _isListening
                          ? const Color(0xFF4A8F7E)
                          : Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isListening ? 'Слушаю...' : 'Не активно',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Кнопка Старт / Стоп
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _toggleListening,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isListening
                      ? Colors.red.shade400
                      : const Color(0xFF7CBFAD),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  _isListening ? 'СТОП' : 'СТАРТ',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Лог
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Лог:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _log.length,
                        itemBuilder: (context, index) {
                          return Text(
                            _log[index],
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
