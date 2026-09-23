import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;

class VoiceCommand {
  final String phrase;
  final String json;
  VoiceCommand({required this.phrase, required this.json});
}

class CommandsService {
  String _url = '';
  List<String> _wakeWords = ['малышка', 'малыш'];
  List<VoiceCommand> _commands = [];

  String get url => _url;
  List<String> get wakeWords => _wakeWords;
  List<VoiceCommand> get commands => _commands;

  Future<void> load() async {
    // Сначала пробуем Download/ZefirkaVoice/commands.json
    bool loaded = await _tryLoadFromDownload();

    // Если не получилось — из assets
    if (!loaded) {
      await _tryLoadFromAssets();
    }
  }

  Future<bool> _tryLoadFromDownload() async {
    try {
      final file = File('/storage/emulated/0/Download/ZefirkaVoice/commands.json');
      if (!await file.exists()) return false;

      final raw = await file.readAsString();
      _parse(raw);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _tryLoadFromAssets() async {
    try {
      final raw = await rootBundle.loadString('assets/commands.json');
      _parse(raw);
    } catch (e) {
      _commands = [];
    }
  }

  void _parse(String raw) {
    final data = json.decode(raw);

    _url = (data['url'] ?? '').toString();

    _wakeWords = [];
    final wakeList = data['wake_words'] as List?;
    if (wakeList != null) {
      for (final w in wakeList) {
        final s = w.toString().toLowerCase().trim();
        if (s.isNotEmpty) _wakeWords.add(s);
      }
    }
    if (_wakeWords.isEmpty) {
      _wakeWords = ['малышка', 'малыш'];
    }

    _commands = [];
    final list = data['commands'] as List? ?? [];
    for (final cmd in list) {
      final phrase = (cmd['phrase'] ?? '').toString().toLowerCase().trim();
      final json = (cmd['json'] ?? '').toString();
      if (phrase.isNotEmpty) {
        _commands.add(VoiceCommand(phrase: phrase, json: json));
      }
    }
  }

  // Проверка: содержит ли текст хотя бы один wake word
  bool hasWakeWord(String text) {
    final lower = text.toLowerCase().trim();
    for (final w in _wakeWords) {
      if (lower.contains(w)) return true;
    }
    return false;
  }

  // Убрать wake word из текста (первое совпадение)
  String stripWakeWord(String text) {
    final lower = text.toLowerCase();
    for (final w in _wakeWords) {
      final idx = lower.indexOf(w);
      if (idx >= 0) {
        return (text.substring(0, idx) + text.substring(idx + w.length)).trim();
      }
    }
    return text.trim();
  }

  // Найти команду
  VoiceCommand? findCommand(String text) {
    final lower = text.toLowerCase().trim();
    for (final cmd in _commands) {
      if (lower.contains(cmd.phrase)) {
        return cmd;
      }
    }
    return null;
  }
}
