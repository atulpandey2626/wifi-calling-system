import 'dart:async';
import 'dart:convert';
import 'dart:io';

class SignalingService {
  ServerSocket? _serverSocket;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final List<String> _outgoingQueue = [];
  bool _isSending = false;

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  Future<void> startServer() async {
    _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 8889);
    _serverSocket?.listen((Socket clientSocket) {
      _handleIncomingConnection(clientSocket);
    });
  }

  void _handleIncomingConnection(Socket socket) {
    socket
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((String line) {
      try {
        final Map<String, dynamic> message = jsonDecode(line);
        _messageController.add(message);
      } catch (_) {}
    }, onDone: () => socket.destroy());
  }

  void sendSignalingMessage(String targetIp, Map<String, dynamic> message) {
    final payload = jsonEncode(message) + '\n';
    _outgoingQueue.add(payload);
    _processQueue(targetIp);
  }

  Future<void> _processQueue(String targetIp) async {
    if (_isSending || _outgoingQueue.isEmpty) return;
    _isSending = true;

    while (_outgoingQueue.isNotEmpty) {
      final currentPayload = _outgoingQueue.removeAt(0);
      try {
        final socket = await Socket.connect(targetIp, 8889, timeout: const Duration(seconds: 2));
        socket.write(currentPayload);
        await socket.flush();
        await socket.close();
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 100));
    }
    _isSending = false;
  }

  void stop() {
    _serverSocket?.close();
  }
}
