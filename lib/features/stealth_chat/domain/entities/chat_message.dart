import 'package:equatable/equatable.dart';

enum MessageType {
  text,
  image,
  file,
  system,
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

class ChatMessage extends Equatable {
  final String id;
  final String? roomId;
  final String senderId;
  final String? senderDeviceId;
  final String receiverId;
  final String content;
  final MessageType type;
  final MessageStatus status;
  final DateTime timestamp;
  final bool isEncrypted;
  final String? encryptedContent;

  const ChatMessage({
    required this.id,
    this.roomId,
    required this.senderId,
    this.senderDeviceId,
    required this.receiverId,
    required this.content,
    this.type = MessageType.text,
    this.status = MessageStatus.sent,
    required this.timestamp,
    this.isEncrypted = true,
    this.encryptedContent,
  });

  bool isMineFor(String deviceId) => senderDeviceId == deviceId;

  ChatMessage copyWith({
    String? id,
    String? roomId,
    String? senderId,
    String? senderDeviceId,
    String? receiverId,
    String? content,
    MessageType? type,
    MessageStatus? status,
    DateTime? timestamp,
    bool? isEncrypted,
    String? encryptedContent,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      senderId: senderId ?? this.senderId,
      senderDeviceId: senderDeviceId ?? this.senderDeviceId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      type: type ?? this.type,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      encryptedContent: encryptedContent ?? this.encryptedContent,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roomId': roomId,
      'senderId': senderId,
      'senderDeviceId': senderDeviceId,
      'receiverId': receiverId,
      'content': content,
      'type': type.name,
      'status': status.name,
      'timestamp': timestamp.toIso8601String(),
      'isEncrypted': isEncrypted,
      'encryptedContent': encryptedContent,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      roomId: json['roomId'] as String?,
      senderId: json['senderId'] as String,
      senderDeviceId: json['senderDeviceId'] as String?,
      receiverId: json['receiverId'] as String,
      content: json['content'] as String,
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.text,
      ),
      status: MessageStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MessageStatus.sent,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      isEncrypted: json['isEncrypted'] as bool? ?? true,
      encryptedContent: json['encryptedContent'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        roomId,
        senderId,
        senderDeviceId,
        receiverId,
        content,
        type,
        status,
        timestamp,
        isEncrypted,
        encryptedContent,
      ];
}
