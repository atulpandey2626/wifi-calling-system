import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'lan_discovery_service.dart';
import 'signaling_service.dart';

enum CallState { idle, incoming, calling, connected }

class CallManager extends ChangeNotifier {
  final LanDiscoveryService discoveryService;
  final SignalingService signalingService;

  CallState _state = CallState.idle;
  PeerDevice? _activePeer;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  final List<RTCIceCandidate> _earlyIceCandidates = [];
  bool _remoteDescriptionSet = false;

  CallState get state => _state;
  PeerDevice? get activePeer => _activePeer;

  CallManager({required this.discoveryService, required this.signalingService}) {
    signalingService.messageStream.listen(_handleIncomingSignaling);
  }

  void _updateState(CallState newState) {
    _state = newState;
    notifyListeners();
  }

  final Map<String, dynamic> _rtcConfig = {
    'iceServers': [],
    'sdpSemantics': 'unified-plan'
  };

  Future<void> initiateCall(PeerDevice peer) async {
    _activePeer = peer;
    _updateState(CallState.calling);

    await _initializeMedia();
    _peerConnection = await createPeerConnection(_rtcConfig);
    _localStream?.getTracks().forEach((track) => _peerConnection?.addTrack(track, _localStream!));

    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      signalingService.sendSignalingMessage(_activePeer!.ip, {
        'type': 'candidate',
        'candidate': candidate.toMap(),
      });
    };

    _peerConnection?.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _updateState(CallState.connected);
      }
    };

    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    signalingService.sendSignalingMessage(_activePeer!.ip, {
      'type': 'offer',
      'sdp': offer.sdp,
    });
  }

  Future<void> _handleIncomingSignaling(Map<String, dynamic> message) async {
    final type = message['type'];

    if (type == 'offer') {
      _updateState(CallState.incoming);
      await _initializeMedia();
      _peerConnection = await createPeerConnection(_rtcConfig);
      _localStream?.getTracks().forEach((track) => _peerConnection?.addTrack(track, _localStream!));

      _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
        if (_activePeer != null) {
          signalingService.sendSignalingMessage(_activePeer!.ip, {
            'type': 'candidate',
            'candidate': candidate.toMap(),
          });
        }
      };

      _peerConnection?.onConnectionState = (state) {
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _updateState(CallState.connected);
        }
      };

      await _peerConnection!.setRemoteDescription(RTCSessionDescription(message['sdp'], 'offer'));
      _remoteDescriptionSet = true;
      await _drainEarlyIceCandidates();

      RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      if (_activePeer != null) {
        signalingService.sendSignalingMessage(_activePeer!.ip, {
          'type': 'answer',
          'sdp': answer.sdp,
        });
      }
    } else if (type == 'answer') {
      await _peerConnection!.setRemoteDescription(RTCSessionDescription(message['sdp'], 'answer'));
      _remoteDescriptionSet = true;
      await _drainEarlyIceCandidates();
    } else if (type == 'candidate') {
      final candidateData = message['candidate'];
      RTCIceCandidate candidate = RTCIceCandidate(
        candidateData['candidate'],
        candidateData['sdpMid'],
        candidateData['sdpMLineIndex'],
      );

      if (_remoteDescriptionSet) {
        await _peerConnection?.addCandidate(candidate);
      } else {
        _earlyIceCandidates.add(candidate);
      }
    }
  }

  Future<void> _drainEarlyIceCandidates() async {
    for (var candidate in _earlyIceCandidates) {
      await _peerConnection?.addCandidate(candidate);
    }
    _earlyIceCandidates.clear();
  }

  Future<void> _initializeMedia() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': {
        'mandatory': {
          'googEchoCancellation': true,
          'googNoiseSuppression': true,
        },
        'optional': [],
      },
      'video': false
    };
    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    
    await Future.delayed(const Duration(milliseconds: 500));
    _localStream?.getAudioTracks()[0].enableSpeakerphone(true);
  }

  void endCall() {
    _localStream?.dispose();
    _peerConnection?.close();
    _peerConnection = null;
    _remoteDescriptionSet = false;
    _earlyIceCandidates.clear();
    _updateState(CallState.idle);
  }
}
