import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;

class VoiceCommand {
  final List<String> phrases;
  final String json;
  VoiceCommand({required this.phrases, required this.json});
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

  Future<void> load() async {
    bool loaded = await _tryLoadFromDownload();
    if (!loaded) {
      await _tryLoadFromAssets();
    }
  }

  Future<bool> _tryLoadFromDownload() async {
    try {
      final file =
          File('/storage/emulated/0/Download/ZefirkaVoice/commands.json');
      if (!await file.exists()) return false;
      final raw = await file.readAsString();
      _parse(raw);
      _source = 'Download';
      return true;
    } catch (e) {
      _source = 'Download: ошибка';
      return false;
    }
  }

  Future<void> _tryLoadFromAssets() async {
    try {
      final raw = await rootBundle.loadString('assets/commands.json');
      _parse(raw);
      _source = 'assets';
    } catch (e) {
      _commands = [];
      _source = 'assets: ошибка';
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
      final phrases = <String>[];
      if (cmd['phrases'] != null) {
        for (final p in (cmd['phrases'] as List)) {
          final s = p.toString().toLowerCase().trim();
          if (s.isNotEmpty) phrases.add(s);
        }
      } else if (cmd['phrase'] != null) {
        final s = cmd['phrase'].toString().toLowerCase().trim();
        if (s.isNotEmpty) phrases.add(s);
      }

      final json = (cmd['json'] ?? '').toString();
      if (phrases.isNotEmpty) {
        _commands.add(VoiceCommand(phrases: phrases, json: json));
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
