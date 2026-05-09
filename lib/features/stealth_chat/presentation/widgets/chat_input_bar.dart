import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'emoji_picker.dart';

class ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttachment;
  final Function(bool)? onTyping;
  final Function(String path, int duration)? onVoiceMessage;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onAttachment,
    this.onTyping,
    this.onVoiceMessage,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar>
    with SingleTickerProviderStateMixin {
  bool _isTyping = false;
  bool _showEmojiPicker = false;
  bool _isRecording = false;
  int _recordingSeconds = 0;

  final FocusNode _focusNode = FocusNode();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  late AnimationController _recordingAnimation;
  DateTime? _recordingStart;
  bool _recorderInitialized = false;
  String? _recordingPath;

  // Voice recording is only supported on mobile platforms
  bool get _voiceSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _showEmojiPicker) {
        setState(() => _showEmojiPicker = false);
      }
    });
    _recordingAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    if (_voiceSupported) {
      _initRecorder();
    }
  }

  Future<void> _initRecorder() async {
    try {
      await _recorder.openRecorder();
      setState(() => _recorderInitialized = true);
    } catch (e) {
      debugPrint('Recorder init error: $e');
    }
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _isTyping) {
      setState(() => _isTyping = hasText);
      widget.onTyping?.call(hasText);
    }
  }

  void _toggleEmojiPicker() {
    setState(() => _showEmojiPicker = !_showEmojiPicker);
    if (_showEmojiPicker) {
      _focusNode.unfocus();
    } else {
      _focusNode.requestFocus();
    }
  }

  Future<void> _startRecording() async {
    // Not supported on desktop/web
    if (!_voiceSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Voice messages work on Android & iOS only')),
      );
      return;
    }

    if (!_recorderInitialized) {
      await _initRecorder();
    }

    // Request mic permission
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
      return;
    }

    try {
      final dir = await getTemporaryDirectory();
      _recordingPath =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';

      await _recorder.startRecorder(
        toFile: _recordingPath,
        codec: Codec.aacADTS,
      );

      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
        _recordingStart = DateTime.now();
      });
      _tickTimer();
    } catch (e) {
      debugPrint('Start recording error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start recording: $e')),
        );
      }
    }
  }

  void _tickTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_isRecording && mounted) {
        setState(() => _recordingSeconds++);
        _tickTimer();
      }
    });
  }

  Future<void> _stopRecording({bool send = true}) async {
    try {
      final path = await _recorder.stopRecorder();
      final duration = _recordingStart != null
          ? DateTime.now().difference(_recordingStart!).inSeconds
          : 0;

      setState(() => _isRecording = false);

      if (send && path != null && widget.onVoiceMessage != null) {
        widget.onVoiceMessage!(path, duration);
      }
    } catch (e) {
      debugPrint('Stop recording error: $e');
      setState(() => _isRecording = false);
    }
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    _recordingAnimation.dispose();
    if (_voiceSupported && _recorderInitialized) {
      _recorder.closeRecorder();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 15,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: _isRecording
                ? _buildRecordingRow()
                : _buildNormalRow(),
          ),
        ),
        if (_showEmojiPicker)
          EmojiPickerWidget(
            controller: widget.controller,
          ),
      ],
    );
  }

  Widget _buildNormalRow() {
    return Row(
      children: [
        // Attachment button
        IconButton(
          icon: const Icon(Icons.add_rounded, color: Colors.black),
          onPressed: widget.onAttachment,
          padding: EdgeInsets.zero,
        ),
        const SizedBox(width: 4),
        // Text field
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              maxLines: 5,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Secure message...',
                hintStyle: const TextStyle(color: Colors.black26),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showEmojiPicker ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined,
                    color: Colors.black38,
                    size: 20,
                  ),
                  onPressed: _toggleEmojiPicker,
                ),
              ),
              onSubmitted: (_) {
                if (_isTyping) widget.onSend();
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Send or Mic button
        GestureDetector(
          onLongPressStart: (!_isTyping && _voiceSupported)
              ? (_) => _startRecording()
              : null,
          onLongPressEnd: (!_isTyping && _voiceSupported)
              ? (_) => _stopRecording(send: true)
              : null,
          onTap: _isTyping
              ? widget.onSend
              : (!_voiceSupported
                  ? () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Voice messages work on Android & iOS'),
                        ),
                      )
                  : null),
          child: Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isTyping
                  ? Icons.arrow_upward_rounded
                  : (_voiceSupported ? Icons.mic_none_rounded : Icons.mic_off_rounded),
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingRow() {
    return Row(
      children: [
        // Cancel
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
          onPressed: () => _stopRecording(send: false),
        ),
        // Indicator + timer
        Expanded(
          child: Row(
            children: [
              FadeTransition(
                opacity: _recordingAnimation,
                child: const Icon(Icons.circle, color: Colors.red, size: 8),
              ),
              const SizedBox(width: 12),
              Text(
                _formatTime(_recordingSeconds),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black, letterSpacing: 1.0),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'ENCRYPTING AUDIO...',
                  style: TextStyle(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                ),
              ),
            ],
          ),
        ),
        // Send button
        GestureDetector(
          onTap: () => _stopRecording(send: true),
          child: Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 24),
          ),
        ),
      ],
    );
  }
}
