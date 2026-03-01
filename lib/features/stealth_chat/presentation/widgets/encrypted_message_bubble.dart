import 'package:flutter/material.dart';
import '../../domain/entities/chat_message.dart';

class EncryptedMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;

  const EncryptedMessageBubble({
    super.key,
    required this.message,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        left: isMine ? 64 : 8,
        right: isMine ? 8 : 64,
        bottom: 8,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMine ? Colors.blue : Colors.grey[300],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, size: 12, color: Colors.white70),
              const SizedBox(width: 4),
              Text(
                'Encrypted',
                style: TextStyle(
                  fontSize: 10,
                  color: isMine ? Colors.white70 : Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            message.content,
            style: TextStyle(
              color: isMine ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
