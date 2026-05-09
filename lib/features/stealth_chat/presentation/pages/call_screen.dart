import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/services/call_signaling_service.dart';

class CallScreen extends ConsumerStatefulWidget {
  final String chatId;
  final bool isVideo;
  final String? incomingCallId;
  final String? incomingSdpOffer;

  const CallScreen({
    super.key, 
    required this.chatId, 
    required this.isVideo,
    this.incomingCallId,
    this.incomingSdpOffer,
  });

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  late CallSignalingService _signalingService;

  bool _micMuted = false;
  bool _cameraOff = false;
  bool _isSpeaker = true;
  bool _isScreenSharing = false;
  bool _isConnecting = true;
  bool _isConnected = false;
  bool _isFrontCamera = true; // Track camera facing
  String _audioOutput = 'speaker'; // 'speaker', 'earpiece', 'headset', 'bluetooth'
  Duration _callDuration = Duration.zero;
  List<MediaDeviceInfo> _audioOutputs = [];

  @override
  void initState() {
    super.initState();

    // ✅ Skip full init on web (JS interop not ready yet)
    if (kIsWeb) return;

    _signalingService = ref.read(callSignalingServiceProvider);
    
    // ✅ Initialize speakerphone on start
    Helper.setSpeakerphoneOn(_isSpeaker);
    
    // ✅ Load available audio output devices
    _getAudioOutputs();
    
    if (widget.incomingCallId != null && widget.incomingSdpOffer != null) {
      _initRenderers().then((_) => _answerCall());
    } else {
      _initRenderers().then((_) => _startCall());
    }
    
    _setupSignalingCallbacks();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  void _setupSignalingCallbacks() {
    _signalingService.onCallStatusChanged = (status) {
      if (!mounted) return;
      if (status == CallStatus.ended || status == CallStatus.rejected) {
        _handleCallEnded(status);
      } else if (status == CallStatus.active) {
        setState(() {
          _isConnecting = false;
          _isConnected = true;
        });
        _startCallTimer();
      }
    };
  }

  void _handleCallEnded(CallStatus status) {
    if (!mounted) return;
    final msg =
        status == CallStatus.rejected ? 'Call rejected' : 'Call ended';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
    context.pop();
  }

  Future<void> _startCall() async {
    try {
      final myDeviceId = ref.read(deviceIdProvider);
      final myUserId = Supabase.instance.client.auth.currentUser?.id;
      if (myUserId == null) {
        throw Exception('Not authenticated');
      }

      // Resolve the other participant (1:1 chat) from chat_sessions.participant_ids
      final session = await Supabase.instance.client
          .from('chat_sessions')
          .select('participant_ids')
          .eq('id', widget.chatId)
          .maybeSingle();

      final participantIds = session?['participant_ids'] as List?;
      final participants = participantIds?.map((e) => e.toString()).toList() ?? const <String>[];
      final calleeUserId = participants.firstWhere(
        (id) => id != myUserId,
        orElse: () => '',
      );
      if (calleeUserId.isEmpty) {
        throw Exception('Could not resolve call recipient for this chat');
      }

      // ── Get mic / camera stream ──
      final Map<String, dynamic> mediaConstraints = {
        'audio': true,
        'video': widget.isVideo
            ? {'facingMode': 'user', 'width': 640, 'height': 480}
            : false,
      };

      _localStream =
          await navigator.mediaDevices.getUserMedia(mediaConstraints);

      if (mounted) {
        setState(() => _localRenderer.srcObject = _localStream);
      }

      // ── Create peer connection ──
      _peerConnection = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
        'sdpSemantics': 'unified-plan',
      });

      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      _peerConnection!.onTrack = (event) {
        if (event.streams.isNotEmpty && mounted) {
          setState(() => _remoteRenderer.srcObject = event.streams[0]);
        }
      };

      // ── Initiate Signaling ──
      await _signalingService.initiateCall(
        calleeUserId: calleeUserId,
        chatId: widget.chatId,
        isVideo: widget.isVideo,
        peerConnection: _peerConnection!,
        myDeviceId: myDeviceId,
      );

      if (mounted) setState(() => _isConnecting = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Call Error: $e')),
        );
        context.pop();
      }
    }
  }

  Future<void> _answerCall() async {
    try {
      final myDeviceId = ref.read(deviceIdProvider);
      
      // ── Get mic / camera stream ──
      final Map<String, dynamic> mediaConstraints = {
        'audio': true,
        'video': widget.isVideo
            ? {'facingMode': 'user', 'width': 640, 'height': 480}
            : false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);

      if (mounted) {
        setState(() => _localRenderer.srcObject = _localStream);
      }

      // ── Create peer connection ──
      _peerConnection = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
        'sdpSemantics': 'unified-plan',
      });

      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      _peerConnection!.onTrack = (event) {
        if (event.streams.isNotEmpty && mounted) {
          setState(() => _remoteRenderer.srcObject = event.streams[0]);
        }
      };

      // ── Answer Signaling ──
      await _signalingService.answerCall(
        callId: widget.incomingCallId!,
        sdpOffer: widget.incomingSdpOffer!,
        peerConnection: _peerConnection!,
        isVideo: widget.isVideo,
        myDeviceId: myDeviceId,
      );

      if (mounted) {
        setState(() {
          _isConnecting = false;
          _isConnected = true;
        });
      }
      _startCallTimer();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Answer Error: $e')));
        context.pop();
      }
    }
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeaker = !_isSpeaker;
      Helper.setSpeakerphoneOn(_isSpeaker);
    });
  }

  void _startCallTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _isConnected) {
        setState(() => _callDuration += const Duration(seconds: 1));
        _startCallTimer();
      }
    });
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  void _toggleMic() {
    _localStream?.getAudioTracks().forEach((t) => t.enabled = _micMuted);
    setState(() => _micMuted = !_micMuted);
  }

  void _toggleCamera() {
    _localStream?.getVideoTracks().forEach((t) => t.enabled = _cameraOff);
    setState(() => _cameraOff = !_cameraOff);
  }

  // Flip between front and back camera
  Future<void> _flipCamera() async {
    if (!widget.isVideo || _localStream == null) return;
    
    try {
      // Stop current video track
      _localStream?.getVideoTracks().forEach((track) => track.stop());
      
      // Toggle camera facing
      _isFrontCamera = !_isFrontCamera;
      
      // Get new stream with flipped camera
      final newStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': _isFrontCamera ? 'user' : 'environment',
          'width': 640,
          'height': 480,
        },
      });
      
      // Get new video track
      final newVideoTrack = newStream.getVideoTracks().first;
      
      // Replace track in peer connection
      final senders = await _peerConnection?.getSenders();
      final videoSender = senders?.firstWhere(
        (s) => s.track?.kind == 'video',
        orElse: () => senders.first,
      );
      await videoSender?.replaceTrack(newVideoTrack);
      
      // Update local renderer
      if (mounted) {
        setState(() {
          _localStream = newStream;
          _localRenderer.srcObject = newStream;
        });
      }
    } catch (e) {
      debugPrint('Camera flip error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera flip failed: $e')),
        );
      }
    }
  }

  // Get available audio output devices
  Future<void> _getAudioOutputs() async {
    try {
      final devices = await navigator.mediaDevices.enumerateDevices();
      _audioOutputs = devices.where((d) => d.kind == 'audiooutput').toList();
      debugPrint('Found ${_audioOutputs.length} audio output devices');
    } catch (e) {
      debugPrint('Error getting audio outputs: $e');
    }
  }

  // Show audio output selection dialog
  void _showAudioOutputSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Audio Output',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _buildAudioOption(
              icon: Icons.volume_up,
              label: 'Speaker',
              value: 'speaker',
              isSelected: _audioOutput == 'speaker',
            ),
            _buildAudioOption(
              icon: Icons.phone,
              label: 'Earpiece',
              value: 'earpiece',
              isSelected: _audioOutput == 'earpiece',
            ),
            _buildAudioOption(
              icon: Icons.headphones,
              label: 'Headphones',
              value: 'headset',
              isSelected: _audioOutput == 'headset',
            ),
            _buildAudioOption(
              icon: Icons.bluetooth_audio,
              label: 'Bluetooth',
              value: 'bluetooth',
              isSelected: _audioOutput == 'bluetooth',
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioOption({
    required IconData icon,
    required String label,
    required String value,
    required bool isSelected,
  }) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.blue : Colors.white70),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.blue : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Colors.blue)
          : null,
      onTap: () {
        _setAudioOutput(value);
        Navigator.pop(context);
      },
    );
  }

  // Set audio output route
  Future<void> _setAudioOutput(String output) async {
    try {
      _audioOutput = output;
      
      switch (output) {
        case 'speaker':
          await Helper.setSpeakerphoneOn(true);
          break;
        case 'earpiece':
          await Helper.setSpeakerphoneOn(false);
          break;
        case 'headset':
        case 'bluetooth':
          // For headset/Bluetooth, try to set specific device if available
          await Helper.setSpeakerphoneOn(false);
          // Note: Specific device selection requires platform-specific code
          break;
      }
      
      setState(() {});
      debugPrint('Audio output set to: $output');
    } catch (e) {
      debugPrint('Error setting audio output: $e');
    }
  }

  Future<void> _toggleScreenShare() async {
    if (_isScreenSharing) {
      // Switch back to camera
      try {
        final camStream = await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': widget.isVideo
              ? {'facingMode': 'user', 'width': 640, 'height': 480}
              : false,
        });
        if (mounted) {
          setState(() {
            _localStream = camStream;
            _localRenderer.srcObject = camStream;
            _isScreenSharing = false;
          });
        }
      } catch (e) {
        debugPrint('Switch back to camera error: $e');
      }
    } else {
      // Start screen share
      try {
        final screenStream = await navigator.mediaDevices
            .getDisplayMedia({'video': true, 'audio': false});
        if (mounted) {
          setState(() {
            _localRenderer.srcObject = screenStream;
            _isScreenSharing = true;
          });
          // Replace video track in peer connection
          final senders = await _peerConnection?.getSenders();
          final videoSender = senders?.firstWhere(
            (s) => s.track?.kind == 'video',
            orElse: () => senders.first,
          );
          final screenTrack = screenStream.getVideoTracks().first;
          await videoSender?.replaceTrack(screenTrack);
        }
      } catch (e) {
        debugPrint('Screen share error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Screen share failed: $e')),
          );
        }
      }
    }
  }

  void _endCall() {
    _signalingService.endCall();
    _localStream?.getTracks().forEach((t) => t.stop());
    _peerConnection?.close();
    if (mounted) context.pop();
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _localStream?.getTracks().forEach((t) => t.stop());
    _peerConnection?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ── Web: not supported yet ──
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text('Call',
              style: TextStyle(color: Colors.white)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off,
                  color: Colors.white54, size: 80),
              const SizedBox(height: 24),
              const Text(
                'Calls are not supported on web yet.',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Text(
                'Please use the Windows or mobile app.',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    // ── Native: full call screen ──
    const partnerName = 'Secure Partner';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Remote video / background ──
          if (widget.isVideo && _isConnected)
            Positioned.fill(
              child: RTCVideoView(
                _remoteRenderer,
                objectFit:
                    RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            )
          else
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade900, Colors.black],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

          // ── Connecting spinner ──
          if (_isConnecting)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Calling...',
                        style: TextStyle(
                            color: Colors.white, fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Local video PiP (video call only) ──
          if (widget.isVideo &&
              _isConnected &&
              !_cameraOff &&
              !_isScreenSharing)
            Positioned(
              top: 110,
              right: 16,
              child: Container(
                width: 110,
                height: 155,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 8)
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: RTCVideoView(
                    _localRenderer,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit
                        .RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            ),
          // ── Top bar: name + timer ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Back button
                    GestureDetector(
                      onTap: _endCall,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back,
                            color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            partnerName,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _isConnecting
                                ? 'Ringing...'
                                : _isConnected
                                    ? _formatDuration(_callDuration)
                                    : 'Connecting...',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    // Screen share badge
                    if (_isScreenSharing)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.screen_share,
                                color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text('Sharing',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── Avatar for audio call ──
          if (!widget.isVideo)
            Positioned(
              top: 0,
              bottom: 220,
              left: 0,
              right: 0,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.blue.shade700,
                      child: const Text(
                        'S',
                        style: TextStyle(
                            fontSize: 48,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      partnerName,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isConnecting
                          ? 'Ringing...'
                          : _isConnected
                              ? _formatDuration(_callDuration)
                              : 'Connecting...',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

          // ── Bottom controls ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    // Mute
                    _buildControlBtn(
                      icon: _micMuted ? Icons.mic_off : Icons.mic,
                      label: _micMuted ? 'Unmute' : 'Mute',
                      onTap: _toggleMic,
                      isActive: _micMuted,
                    ),
                    // Camera toggle (video only)
                    if (widget.isVideo)
                      _buildControlBtn(
                        icon: _cameraOff
                            ? Icons.videocam_off
                            : Icons.videocam,
                        label: _cameraOff ? 'Cam On' : 'Cam Off',
                        onTap: _toggleCamera,
                        isActive: _cameraOff,
                      ),
                    // Camera flip (video only)
                    if (widget.isVideo)
                      _buildControlBtn(
                        icon: _isFrontCamera ? Icons.camera_front : Icons.camera_rear,
                        label: 'Flip',
                        onTap: _flipCamera,
                        isActive: false,
                      ),
                    // Screen share (video only)
                    if (widget.isVideo)
                      _buildControlBtn(
                        icon: _isScreenSharing
                            ? Icons.stop_screen_share
                            : Icons.screen_share,
                        label: _isScreenSharing ? 'Stop' : 'Share',
                        onTap: _toggleScreenShare,
                        isActive: _isScreenSharing,
                        activeColor: Colors.blue,
                      ),
                    // Audio Output Selector (long press for options)
                    _buildControlBtn(
                      icon: _audioOutput == 'speaker'
                          ? Icons.volume_up
                          : _audioOutput == 'earpiece'
                              ? Icons.phone
                              : _audioOutput == 'bluetooth'
                                  ? Icons.bluetooth_audio
                                  : Icons.headphones,
                      label: _audioOutput == 'speaker'
                          ? 'Speaker'
                          : _audioOutput == 'earpiece'
                              ? 'Earpiece'
                              : _audioOutput == 'bluetooth'
                                  ? 'Bluetooth'
                                  : 'Headset',
                      onTap: _toggleSpeaker,
                      onLongPress: _showAudioOutputSelector,
                      isActive: _audioOutput != 'speaker',
                    ),
                    // End call
                    _buildControlBtn(
                      icon: Icons.call_end,
                      label: 'End',
                      onTap: _endCall,
                      bgColor: Colors.red,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    bool isActive = false,
    Color? bgColor,
    Color activeColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: bgColor ??
                  (isActive
                      ? activeColor.withValues(alpha: 0.35)
                      : Colors.white.withValues(alpha: 0.2)),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
