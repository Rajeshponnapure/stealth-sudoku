import 'package:equatable/equatable.dart';

enum MessageType {
  text,
  image,
  audio,
  video,
  file,
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

class Message extends Equatable {
  final String id;
  final String chatId;
  final String? roomId;
  final String senderId;
  final String? senderDeviceId;
  final String receiverId;
  final String content;
  final MessageType type;
  final MessageStatus status;
  final DateTime timestamp;
  final String? filePath;
  final String? fileName;
  final int? fileSize;
  final bool isSelfDestruct;
  final DateTime? destructAt;
  final bool isEncrypted;
  final DateTime? readAt;
  final DateTime? deliveredAt;

  const Message({
    required this.id,
    required this.chatId,
    this.roomId,
    required this.senderId,
    this.senderDeviceId,
    required this.receiverId,
    required this.content,
    required this.type,
    required this.status,
    required this.timestamp,
    this.filePath,
    this.fileName,
    this.fileSize,
    this.isSelfDestruct = false,
    this.destructAt,
    this.isEncrypted = false,
    this.readAt,
    this.deliveredAt,
  });

  Message copyWith({
    String? id,
    String? chatId,
    String? roomId,
    String? senderId,
    String? senderDeviceId,
    String? receiverId,
    String? content,
    MessageType? type,
    MessageStatus? status,
    DateTime? timestamp,
    String? filePath,
    String? fileName,
    int? fileSize,
    bool? isSelfDestruct,
    DateTime? destructAt,
    bool? isEncrypted,
    DateTime? readAt,
    DateTime? deliveredAt,
  }) {
    return Message(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      roomId: roomId ?? this.roomId,
      senderId: senderId ?? this.senderId,
      senderDeviceId: senderDeviceId ?? this.senderDeviceId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      type: type ?? this.type,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      isSelfDestruct: isSelfDestruct ?? this.isSelfDestruct,
      destructAt: destructAt ?? this.destructAt,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      readAt: readAt ?? this.readAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chatId': chatId,
      'roomId': roomId,
      'senderId': senderId,
      'senderDeviceId': senderDeviceId,
      'receiverId': receiverId,
      'content': content,
      'type': type.name,
      'status': status.name,
      'timestamp': timestamp.toIso8601String(),
      'filePath': filePath,
      'fileName': fileName,
      'fileSize': fileSize,
      'isSelfDestruct': isSelfDestruct,
      'destructAt': destructAt?.toIso8601String(),
      'isEncrypted': isEncrypted,
      'readAt': readAt?.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      chatId: json['chatId'] as String,
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
      filePath: json['filePath'] as String?,
      fileName: json['fileName'] as String?,
      fileSize: json['fileSize'] as int?,
      isSelfDestruct: json['isSelfDestruct'] as bool? ?? false,
      destructAt: json['destructAt'] != null
          ? DateTime.parse(json['destructAt'] as String)
          : null,
      isEncrypted: json['isEncrypted'] as bool? ?? false,
      readAt: json['readAt'] != null
          ? DateTime.parse(json['readAt'] as String)
          : null,
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.parse(json['deliveredAt'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [
        id,
        chatId,
        roomId,
        senderId,
        senderDeviceId,
        receiverId,
        content,
        type,
        status,
        timestamp,
        filePath,
        fileName,
        fileSize,
        isSelfDestruct,
        destructAt,
        isEncrypted,
        readAt,
        deliveredAt,
      ];
}
