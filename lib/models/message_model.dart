import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType {
  text,
  image,
  file,
  audio,
}

class Message {
  final String id;
  final String text;
  final String senderId;
  final DateTime timestamp;
  final String senderName;
  final String? mediaUrl;
  final MessageType type;

  Message({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderName,
    required this.timestamp,
    this.mediaUrl,
    this.type = MessageType.text,
  });

  // Factory method pour créer un Message depuis Firestore
  factory Message.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Message(
      id: doc.id,
      text: data['text'] ?? '',
      senderId: data['senderId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      senderName: data['senderName'] ?? 'Utilisateur',
      mediaUrl: data['mediaUrl'],
      type: _parseMessageType(data['type']),
    );
  }

  static MessageType _parseMessageType(String? typeString) {
    if (typeString == null) return MessageType.text;

    switch (typeString) {
      case 'image':
        return MessageType.image;
      case 'file':
        return MessageType.file;
      default:
        return MessageType.text;
    }
  }

  // Convertir en Map pour Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'text': text,
      'senderId': senderId,
      'senderName': senderName,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': _messageTypeToString(type),
      'mediaUrl': mediaUrl,
    };
  }

  static String _messageTypeToString(MessageType type) {
    switch (type) {
      case MessageType.image:
        return 'image';
      case MessageType.file:
        return 'file';
      default:
        return 'text';
    }
  }

  // Méthode utilitaire pour vérifier si c'est l'utilisateur courant
  bool isFromUser(String currentUserId) {
    return senderId == currentUserId;
  }

  // Méthode pour debug
  @override
  String toString() {
    return 'Message{id: $id, text: $text, senderId: $senderId, type: $type}';
  }
}