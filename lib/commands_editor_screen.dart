import 'package:flutter/material.dart';
import 'commands_service.dart';

class CommandsEditorScreen extends StatefulWidget {
  final CommandsService commands;
  final VoidCallback onSaved;
  final bool isDark;

  const CommandsEditorScreen({
    super.key,
    required this.commands,
    required this.onSaved,
    required this.isDark,
  });

  @override
  State<CommandsEditorScreen> createState() => _CommandsEditorScreenState();
}

class _CommandsEditorScreenState extends State<CommandsEditorScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = true;
  String _status = '';

  // ============ ЦВЕТА ПОД ТЕМУ ============
  bool get _isDark => widget.isDark;

  Color get _bgColor =>
      _isDark ? Colors.black : const Color(0xFFF4FAF8);

  Color get _appBarBg =>
      _isDark ? const Color(0xFF1a1a1a) : Colors.white;

  Color get _accent =>
      _isDark ? const Color(0xFF7CBFAD) : const Color(0xFF5FA896);

  Color get _inputBg =>
      _isDark ? const Color(0xFF0a0a0a) : Colors.white;

  Color get _border => _isDark
      ? const Color(0xFF7CBFAD).withOpacity(0.3)
      : const Color(0xFFC8E6DD);

  Color get _dialogBg =>
      _isDark ? const Color(0xFF1a1a1a) : Colors.white;

  Color get _dialogText =>
      _isDark ? Colors.white70 : const Color(0xFF3D7A6B);

  Color get _cancelBtnBg =>
      _isDark ? const Color(0xFF1a1a1a) : const Color(0xFFE3F2ED);

  Color get _cancelBtnText =>
      _isDark ? Colors.grey : const Color(0xFF3D7A6B);

  Color get _saveBtnText =>
      _isDark ? Colors.black : Colors.white;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final json = await widget.commands.getCurrentJson();
    _controller.text = json;
    setState(() {
      _loading = false;
      _status = 'Загружено';
    });
  }

  Future<void> _save() async {
    final text = _controller.text;
    final ok = await widget.commands.saveFromText(text);

    setState(() {
      _status = ok ? 'Сохранено ✓' : 'Ошибка: неверный JSON';
    });

    if (ok) {
      widget.onSaved();
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  Future<void> _reset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _dialogBg,
        title: Text('Сбросить?', style: TextStyle(color: _accent)),
        content: Text(
          'Вернуть команды к стандартным?',
          style: TextStyle(color: _dialogText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Отмена',
              style: TextStyle(
                color: _isDark ? Colors.grey : const Color(0xFF5FA896),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Сбросить', style: TextStyle(color: _accent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await widget.commands.resetToDefault();
      if (ok) {
        await _load();
        widget.onSaved();
        setState(() => _status = 'Сброшено ✓');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _appBarBg,
        foregroundColor: _accent,
        elevation: 0,
        title: const Text('Редактор команд'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Сбросить',
            onPressed: _reset,
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: _accent))
          : Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      expands: true,
                      style: TextStyle(
                        color: _accent,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: _inputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _accent),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_status.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _status,
                      style: TextStyle(
                        color: _status.contains('Ошибка')
                            ? Colors.red.shade300
                            : _accent,
                        fontSize: 13,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _cancelBtnBg,
                            foregroundColor: _cancelBtnText,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                          child: const Text('Отмена'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: _saveBtnText,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Сохранить',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
