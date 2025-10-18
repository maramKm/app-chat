class Message {
  final String id;
  final String text;
  final String senderId;
  final DateTime timestamp;
  final bool isMe;
  final String? mediaUrl;
  final MessageType type;

  Message({
    required this.id,
    required this.text,
    required this.senderId,
    required this.timestamp,
    required this.isMe,
    this.mediaUrl,
    this.type = MessageType.text,
  });
}

enum MessageType {
  text,
  image,
  file,
  location,
}