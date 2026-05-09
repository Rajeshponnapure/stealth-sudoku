import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

enum CallStatus { idle, ringing, active, ended, rejected }

class CallSignalingService {
  final SupabaseClient _supabase;

  String? _currentCallId;
  RTCPeerConnection? _peerConnection;
  RealtimeChannel? _callChannel;
  RealtimeChannel? _iceChannel;
  RealtimeChannel? _incomingChannel;

  Function(String callId, String callerId, String callerName, bool isVideo)?
      onIncomingCall;
  Function(RTCSessionDescription answer)? onAnswerReceived;
  Function(RTCIceCandidate candidate)? onIceCandidateReceived;
  Function(CallStatus status)? onCallStatusChanged;

  CallSignalingService(this._supabase);

  String get currentUserId => _supabase.auth.currentUser!.id;

  // ── CALLER: Start a call ──
  Future<String> initiateCall({
    required String calleeUserId,
    required String chatId,
    required bool isVideo,
    required RTCPeerConnection peerConnection,
    required String myDeviceId,
  }) async {
    _peerConnection = peerConnection;
    final callId = const Uuid().v4();
    _currentCallId = callId;

    final offer = await peerConnection.createOffer({
      'offerToReceiveVideo': isVideo ? 1 : 0,
      'offerToReceiveAudio': 1,
    });
    await peerConnection.setLocalDescription(offer);

    await _supabase.from('calls').insert({
      'id': callId,
      'chat_id': chatId,
      // NOTE: calls.caller_id / calls.callee_id are UUIDs (auth.users ids)
      'caller_id': currentUserId,
      'callee_id': calleeUserId,
      'call_type': isVideo ? 'video' : 'audio',
      'status': 'ringing',
      'sdp_offer': offer.sdp,
    });

    _subscribeToCallUpdates(callId);
    _subscribeToIceCandidates(callId, myDeviceId);

    peerConnection.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        _sendIceCandidate(callId, candidate, myDeviceId);
      }
    };

    onCallStatusChanged?.call(CallStatus.ringing);
    return callId;
  }

  // ── CALLEE: Answer a call ──
  Future<void> answerCall({
    required String callId,
    required String sdpOffer,
    required RTCPeerConnection peerConnection,
    required bool isVideo,
    required String myDeviceId,
  }) async {
    _peerConnection = peerConnection;
    _currentCallId = callId;

    await peerConnection.setRemoteDescription(
      RTCSessionDescription(sdpOffer, 'offer'),
    );

    final answer = await peerConnection.createAnswer({
      'offerToReceiveVideo': isVideo ? 1 : 0,
      'offerToReceiveAudio': 1,
    });
    await peerConnection.setLocalDescription(answer);

    await _supabase.from('calls').update({
      'sdp_answer': answer.sdp,
      'status': 'active',
    }).eq('id', callId);

    _subscribeToIceCandidates(callId, myDeviceId);
    _subscribeToCallUpdates(callId);

    peerConnection.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        _sendIceCandidate(callId, candidate, myDeviceId);
      }
    };

    onCallStatusChanged?.call(CallStatus.active);
  }

  // ── CALLEE: Reject a call ──
  Future<void> rejectCall(String callId) async {
    await _supabase.from('calls').update({
      'status': 'rejected',
      'ended_at': DateTime.now().toIso8601String(),
    }).eq('id', callId);
    onCallStatusChanged?.call(CallStatus.rejected);
    _cleanup();
  }

  // ── BOTH: End the call ──
  Future<void> endCall() async {
    if (_currentCallId != null) {
      await _supabase.from('calls').update({
        'status': 'ended',
        'ended_at': DateTime.now().toIso8601String(),
      }).eq('id', _currentCallId!);
    }
    onCallStatusChanged?.call(CallStatus.ended);
    _cleanup();
  }

  // ── Listen for incoming calls (filtered by current user id) ──
  void listenForIncomingCalls(String myUserId, {required String myDeviceId}) {
    _incomingChannel = _supabase
        .channel('incoming_calls_$myUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'calls',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'callee_id',
            value: myUserId,
          ),
          callback: (payload) async {
            final call = payload.newRecord;
            // Ignore calls that I initiated!
            if (call['status'] == 'ringing' && call['caller_id'] != myUserId) {
              onIncomingCall?.call(
                call['id'],
                call['caller_id'],
                'Secure Partner',
                call['call_type'] == 'video',
              );
            }
          },
        )
        .subscribe();
  }

  void stopListeningForCalls() {
    _incomingChannel?.unsubscribe();
    _incomingChannel = null;
  }

  // ── PRIVATE: Watch for call status updates ──
  void _subscribeToCallUpdates(String callId) {
    _callChannel = _supabase
        .channel('call_updates_$callId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'calls',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: callId,
          ),
          callback: (payload) async {
            final call = payload.newRecord;
            final status = call['status'];

            if (status == 'active' && call['sdp_answer'] != null) {
              await _peerConnection?.setRemoteDescription(
                RTCSessionDescription(call['sdp_answer'], 'answer'),
              );
              onCallStatusChanged?.call(CallStatus.active);
            } else if (status == 'ended') {
              onCallStatusChanged?.call(CallStatus.ended);
              _cleanup();
            } else if (status == 'rejected') {
              onCallStatusChanged?.call(CallStatus.rejected);
              _cleanup();
            }
          },
        )
        .subscribe();
  }

  // ── PRIVATE: Send ICE candidate ──
  Future<void> _sendIceCandidate(
      String callId, RTCIceCandidate candidate, String myDeviceId) async {
    try {
      await _supabase.from('ice_candidates').insert({
        'call_id': callId,
        'sender_id': myDeviceId, // Store Device ID
        'candidate': candidate.candidate,
        'sdp_mid': candidate.sdpMid,
        'sdp_mline_index': candidate.sdpMLineIndex,
      });
    } catch (e) {
      debugPrint('ICE send error: $e');
    }
  }

  // ── PRIVATE: Receive ICE candidates ──
  void _subscribeToIceCandidates(String callId, String myDeviceId) {
    _iceChannel = _supabase
        .channel('ice_candidates_$callId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'ice_candidates',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'call_id',
            value: callId,
          ),
          callback: (payload) async {
            final data = payload.newRecord;
            if (data['sender_id'] != myDeviceId) {
              final candidate = RTCIceCandidate(
                data['candidate'],
                data['sdp_mid'],
                data['sdp_mline_index'],
              );
              await _peerConnection?.addCandidate(candidate);
            }
          },
        )
        .subscribe();
  }

  void _cleanup() {
    _callChannel?.unsubscribe();
    _iceChannel?.unsubscribe();
    _callChannel = null;
    _iceChannel = null;
    _currentCallId = null;
    _peerConnection = null;
  }

  void dispose() {
    _cleanup();
    stopListeningForCalls();
  }
}
