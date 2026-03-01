import 'package:equatable/equatable.dart';
import 'message.dart';

class ChatSession extends Equatable {
  final String id;
  final String peerId;
  final String peerName;
  final String? peerAvatar;
  final Message? lastMessage;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime? lastActivityAt;
  final bool isPinned;
  final bool isMuted;
  final String? encryptionKey;

  const ChatSession({
    required this.id,
    required this.peerId,
    required this.peerName,
    this.peerAvatar,
    this.lastMessage,
    this.unreadCount = 0,
    required this.createdAt,
    this.lastActivityAt,
    this.isPinned = false,
    this.isMuted = false,
    this.encryptionKey,
  });

  ChatSession copyWith({
    String? id,
    String? peerId,
    String? peerName,
    String? peerAvatar,
    Message? lastMessage,
    int? unreadCount,
    DateTime? createdAt,
    DateTime? lastActivityAt,
    bool? isPinned,
    bool? isMuted,
    String? encryptionKey,
  }) {
    return ChatSession(
      id: id ?? this.id,
      peerId: peerId ?? this.peerId,
      peerName: peerName ?? this.peerName,
      peerAvatar: peerAvatar ?? this.peerAvatar,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt ?? this.createdAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      encryptionKey: encryptionKey ?? this.encryptionKey,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'peerId': peerId,
      'peerName': peerName,
      'peerAvatar': peerAvatar,
      'lastMessage': lastMessage?.toJson(),
      'unreadCount': unreadCount,
      'createdAt': createdAt.toIso8601String(),
      'lastActivityAt': lastActivityAt?.toIso8601String(),
      'isPinned': isPinned,
      'isMuted': isMuted,
      'encryptionKey': encryptionKey,
    };
  }

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] as String,
      peerId: json['peerId'] as String,
      peerName: json['peerName'] as String,
      peerAvatar: json['peerAvatar'] as String?,
      lastMessage: json['lastMessage'] != null
          ? Message.fromJson(json['lastMessage'] as Map<String, dynamic>)
          : null,
      unreadCount: json['unreadCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastActivityAt: json['lastActivityAt'] != null
          ? DateTime.parse(json['lastActivityAt'] as String)
          : null,
      isPinned: json['isPinned'] as bool? ?? false,
      isMuted: json['isMuted'] as bool? ?? false,
      encryptionKey: json['encryptionKey'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        peerId,
        peerName,
        peerAvatar,
        lastMessage,
        unreadCount,
        createdAt,
        lastActivityAt,
        isPinned,
        isMuted,
        encryptionKey,
      ];
}
