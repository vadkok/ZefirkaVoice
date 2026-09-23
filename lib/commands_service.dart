import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;

class VoiceCommand {
  final List<String> phrases;
  final String json;
  VoiceCommand({required this.phrases, required this.json});

  Map<String, dynamic> toJson() => {
        'phrases': phrases,
        'json': json,
      };

  factory VoiceCommand.fromJson(Map<String, dynamic> data) {
    final phrases = <String>[];
    if (data['phrases'] != null) {
      for (final p in (data['phrases'] as List)) {
        final s = p.toString().toLowerCase().trim();
        if (s.isNotEmpty) phrases.add(s);
      }
    } else if (data['phrase'] != null) {
      final s = data['phrase'].toString().toLowerCase().trim();
      if (s.isNotEmpty) phrases.add(s);
    }
    return VoiceCommand(
      phrases: phrases,
      json: (data['json'] ?? '').toString(),
    );
  }
}

class CommandsService {
  String _url = '';
  List<String> _wakeWords = ['малышка', 'малыш'];
  List<VoiceCommand> _commands = [];
  String _source = 'не загружено';

  String get url => _url;
  List<String> get wakeWords => _wakeWords;
  List<VoiceCommand> get commands => _commands;
  String get source => _source;

  static Future<File> getCommandsFile() async {
    final dir = Directory('/data/data/com.example.zefirka_voice/files');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}/commands.json');
  }

  Future<void> load() async {
    try {
      final file = await getCommandsFile();

      if (!await file.exists()) {
        final raw = await rootBundle.loadString('assets/commands.json');
        await file.writeAsString(raw);
        _parse(raw);
        _source = 'создан из assets';
        return;
      }

      final raw = await file.readAsString();
      _parse(raw);
      _source = 'файл приложения';
    } catch (e) {
      try {
        final raw = await rootBundle.loadString('assets/commands.json');
        _parse(raw);
        _source = 'assets (ошибка файла)';
      } catch (e2) {
        _commands = [];
        _source = 'ошибка';
      }
    }
  }

  Future<bool> saveFromText(String text) async {
    try {
      final data = json.decode(text);
      if (data['commands'] == null) return false;

      final file = await getCommandsFile();
      await file.writeAsString(text);

      _parse(text);
      _source = 'файл приложения (сохранён)';
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String> getCurrentJson() async {
    try {
      final file = await getCommandsFile();
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (_) {}

    try {
      return await rootBundle.loadString('assets/commands.json');
    } catch (_) {
      return '{}';
    }
  }

  Future<bool> resetToDefault() async {
    try {
      final raw = await rootBundle.loadString('assets/commands.json');
      final file = await getCommandsFile();
      await file.writeAsString(raw);
      _parse(raw);
      _source = 'сброшено из assets';
      return true;
    } catch (e) {
      return false;
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
      final voiceCmd = VoiceCommand.fromJson(cmd);
      if (voiceCmd.phrases.isNotEmpty) {
        _commands.add(voiceCmd);
      }
    }
  }

  bool hasWakeWord(String text) {
    final lower = text.toLowerCase().trim();
    for (final w in _wakeWords) {
      if (lower.contains(w)) return true;
    }
    return false;
  }

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

  VoiceCommand? findCommand(String text) {
    final lower = text.toLowerCase().trim();
    for (final cmd in _commands) {
      for (final phrase in cmd.phrases) {
        if (lower.contains(phrase)) {
          return cmd;
        }
      }
    }
    return null;
  }

  String primaryPhrase(VoiceCommand cmd) {
    return cmd.phrases.isNotEmpty ? cmd.phrases.first : '';
  }
}
