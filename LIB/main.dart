import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'lan_discovery_service.dart';
import 'signaling_service.dart';
import 'call_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final String localId = const Uuid().v4();
  late LanDiscoveryService discoveryService;
  late SignalingService signalingService;
  late CallManager callManager;
  bool _permissionsGranted = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    final micStatus = await Permission.microphone.request();
    final networkStatus = await Permission.nearbyWifiDevices.request();

    if (micStatus.isGranted && networkStatus.isGranted) {
      discoveryService = LanDiscoveryService(localId: localId);
      signalingService = SignalingService();
      callManager = CallManager(discoveryService: discoveryService, signalingService: signalingService);

      await signalingService.startServer();
      await discoveryService.start();

      setState(() {
        _permissionsGranted = true;
      });
      
      callManager.addListener(() {
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    discoveryService.stop();
    signalingService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext MaterialApp) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('WiFi Local Communicator')),
        body: !_permissionsGranted
            ? const Center(child: Text("Granting required system permissions..."))
            : callManager.state != CallState.idle
                ? _buildCallScreen()
                : _buildDiscoveryScreen(),
      ),
    );
  }

  Widget _buildDiscoveryScreen() {
    return StreamBuilder<List<PeerDevice>>(
      stream: discoveryService.peersStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("Searching for nearby devices on the LAN..."));
        }
        final peers = snapshot.data!;
        return ListView.builder(
          itemCount: peers.count,
          itemBuilder: (context, index) {
            final peer = peers[index];
            return ListTile(
              title: Text("Device ID: ${peer.id.substring(0, 8)}"),
              subtitle: Text("IP Address: ${peer.ip}"),
              trailing: IconButton(
                icon: const Icon(Icons.phone, color: Colors.green),
                onPressed: () => callManager.initiateCall(peer),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCallScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Call State: ${callManager.state.name.toUpperCase()}",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => callManager.endCall(),
            child: const Text("Disconnect", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

extension on List<PeerDevice> {
  int get count => length;
}
