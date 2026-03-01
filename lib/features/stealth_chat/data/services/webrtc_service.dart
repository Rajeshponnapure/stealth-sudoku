import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCService {
  static final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  static final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;

  static Future<void> initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> createCall(String peerId) async {
    _peerConnection = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    });

    // Add local stream (video + audio)
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'facingMode': 'user',
      },
    };
    final MediaStream stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    stream.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, stream);
    });
    _localRenderer.srcObject = stream;

    // Create offer
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    // Send offer to peer via Supabase
  }

  // Handle incoming call, answer, toggle mic/camera, screen share
}
