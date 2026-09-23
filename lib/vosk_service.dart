import 'dart:async';
import 'package:vosk_flutter_fixed/vosk_flutter.dart';

class VoskService {
  VoskFlutterPlugin? _vosk;
  Model? _model;
  Recognizer? _recognizer;
  SpeechService? _speechService;

  bool _isRunning = false;

  Function(String text)? onPartial;
  Function(String text)? onResult;

  Future<void> init(String modelPath, {int sampleRate = 16000}) async {
    _vosk = VoskFlutterPlugin.instance();

    _model = await _vosk!.createModel(modelPath);

    _recognizer = await _vosk!.createRecognizer(
      model: _model!,
      sampleRate: sampleRate,
    );
  }

  Future<void> start() async {
    if (_isRunning) return;
    if (_recognizer == null) return;

    _speechService = await _vosk!.initSpeechService(_recognizer!);

    _speechService!.onPartial().listen((text) {
      if (text.isNotEmpty && onPartial != null) {
        onPartial!(text);
      }
    });

    _speechService!.onResult().listen((text) {
      if (text.isNotEmpty && onResult != null) {
        onResult!(text);
      }
    });

    await _speechService!.start();
    _isRunning = true;
  }

  Future<void> stop() async {
    if (!_isRunning) return;
    try {
      await _speechService?.stop();
    } catch (_) {}
    _isRunning = false;
  }

  bool get isRunning => _isRunning;

  Future<void> reinit(String modelPath, {int sampleRate = 16000}) async {
    await dispose();
    await Future.delayed(const Duration(milliseconds: 500));
    await init(modelPath, sampleRate: sampleRate);
  }

  Future<void> dispose() async {
    await stop();
    try {
      _speechService?.dispose();
    } catch (_) {}
    _speechService = null;
    try {
      _recognizer?.dispose();
    } catch (_) {}
    _recognizer = null;
    try {
      _model?.dispose();
    } catch (_) {}
    _model = null;
    _vosk = null;
  }
}
