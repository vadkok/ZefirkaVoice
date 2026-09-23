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
  String _wakeWord = 'зефирка';
  List<VoiceCommand> _commands = [];

  String get url => _url;
  String get wakeWord => _wakeWord;
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
    _wakeWord = (data['wake_word'] ?? 'малыш,малышка')
        .toString()
        .toLowerCase()
        .trim();

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

  // Проверка: содержит ли текст wake word
  bool hasWakeWord(String text) {
    final lower = text.toLowerCase().trim();
    return lower.contains(_wakeWord);
  }

  // Убрать wake word из текста
  String stripWakeWord(String text) {
    final lower = text.toLowerCase();
    final idx = lower.indexOf(_wakeWord);
    if (idx < 0) return text.trim();
    return text.substring(0, idx) + text.substring(idx + _wakeWord.length);
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
