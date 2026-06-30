import 'dart:async';
import 'dart:convert';
import 'dart:io';

class PeerDevice {
  final String id;
  final String ip;
  final DateTime lastSeen;

  PeerDevice({required this.id, required this.ip, required this.lastSeen});
}

class LanDiscoveryService {
  final String localId;
  RawDatagramSocket? _udpSocket;
  Timer? _broadcastTimer;
  Timer? _pruneTimer;
  
  final Map<String, PeerDevice> _discoveredPeers = {};
  final StreamController<List<PeerDevice>> _peersStreamController = StreamController.broadcast();

  Stream<List<PeerDevice>> get peersStream => _peersStreamController.stream;

  LanDiscoveryService({required this.localId});

  Future<void> start() async {
    _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 8888);
    _udpSocket?.broadcastEnabled = true;

    _udpSocket?.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        Datagram? dg = _udpSocket?.receive();
        if (dg != null) {
          try {
            String message = utf8.decode(dg.data);
            Map<String, dynamic> data = jsonDecode(message);
            
            if (data['id'] != localId) {
              _discoveredPeers[data['id']] = PeerDevice(
                id: data['id'],
                ip: dg.address.address,
                lastSeen: DateTime.now(),
              );
              _peersStreamController.add(_discoveredPeers.values.toList());
            }
          } catch (_) {}
        }
      }
    });

    _broadcastTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      final data = jsonEncode({'id': localId});
      _udpSocket?.send(utf8.encode(data), InternetAddress('255.255.255.255'), 8888);
    });

    _pruneTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      final now = DateTime.now();
      _discoveredPeers.removeWhere((id, peer) => now.difference(peer.lastSeen).inSeconds > 10);
      _peersStreamController.add(_discoveredPeers.values.toList());
    });
  }

  void stop() {
    _broadcastTimer?.cancel();
    _pruneTimer?.cancel();
    _udpSocket?.close();
  }
}
