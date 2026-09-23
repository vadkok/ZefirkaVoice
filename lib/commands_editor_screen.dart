import 'package:flutter/material.dart';
import 'commands_service.dart';

class CommandsEditorScreen extends StatefulWidget {
  final CommandsService commands;
  final VoidCallback onSaved;

  const CommandsEditorScreen({
    super.key,
    required this.commands,
    required this.onSaved,
  });

  @override
  State<CommandsEditorScreen> createState() => _CommandsEditorScreenState();
}

class _CommandsEditorScreenState extends State<CommandsEditorScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = true;
  String _status = '';

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
        backgroundColor: const Color(0xFF1a1a1a),
        title: const Text('Сбросить?', style: TextStyle(color: Color(0xFF7CBFAD))),
        content: const Text(
          'Вернуть команды к стандартным?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Сбросить', style: TextStyle(color: Color(0xFF7CBFAD))),
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a1a),
        foregroundColor: const Color(0xFF7CBFAD),
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
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF7CBFAD)),
            )
          : Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      expands: true,
                      style: const TextStyle(
                        color: Color(0xFF7CBFAD),
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF0a0a0a),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: const Color(0xFF7CBFAD).withOpacity(0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: const Color(0xFF7CBFAD).withOpacity(0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF7CBFAD),
                          ),
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
                            : const Color(0xFF7CBFAD),
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
                            backgroundColor: const Color(0xFF1a1a1a),
                            foregroundColor: Colors.grey,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Отмена'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7CBFAD),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
