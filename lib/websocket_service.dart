import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  String _url = '';
  bool _isConnected = false;

  bool get isConnected => _isConnected;
  String get url => _url;

  Function(String text)? onMessage;
  Function()? onConnect;
  Function()? onDisconnect;

  void init(String url) {
    _url = url;
  }

  Future<void> connect() async {
    if (_isConnected) return;
    if (_url.isEmpty) return;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_url));

      // >>> Таймаут 3 сек на подключение
      await _channel!.ready.timeout(const Duration(seconds: 3));

      _isConnected = true;

      _subscription = _channel!.stream.listen(
        (data) {
          if (onMessage != null) onMessage!(data.toString());
        },
        onDone: () {
          _isConnected = false;
          if (onDisconnect != null) onDisconnect!();
        },
        onError: (_) {
          _isConnected = false;
          if (onDisconnect != null) onDisconnect!();
        },
      );

      if (onConnect != null) onConnect!();
    } catch (e) {
      _isConnected = false;
      _channel = null;
    }
  }

  bool send(String message) {
    if (!_isConnected || _channel == null) return false;
    try {
      _channel!.sink.add(message);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> disconnect() async {
    // >>> Таймаут 2 сек на отмену подписки
    try {
      await _subscription?.cancel().timeout(const Duration(seconds: 2));
    } catch (_) {}
    _subscription = null;

    // >>> Таймаут 2 сек на закрытие канала
    try {
      await _channel?.sink.close().timeout(const Duration(seconds: 2));
    } catch (_) {}
    _channel = null;
    _isConnected = false;
  }
}
