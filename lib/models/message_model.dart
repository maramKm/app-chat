import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType {
  text,
  image,
  file,
  audio,
  system, // Add this for system messages like calls
}

class Message {
  final String id;
  final String text;
  final String senderId;
  final DateTime timestamp;
  final String senderName;
  final String? mediaUrl;
  final MessageType type;
  final Map<String, dynamic>? extraData; // Add the missing semicolon

  Message({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderName,
    required this.timestamp,
    this.mediaUrl,
    this.type = MessageType.text,
    this.extraData, // Add this
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
      extraData: data['extraData'] ?? {}, // Add this line
    );
  }

  static MessageType _parseMessageType(String? typeString) {
    if (typeString == null) return MessageType.text;

    switch (typeString) {
      case 'image':
        return MessageType.image;
      case 'file':
        return MessageType.file;
      case 'audio':
        return MessageType.audio;
      case 'system': // Add this case
        return MessageType.system;
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
      'extraData': extraData, // Add this line
    };
  }

  static String _messageTypeToString(MessageType type) {
    switch (type) {
      case MessageType.image:
        return 'image';
      case MessageType.file:
        return 'file';
      case MessageType.audio:
        return 'audio';
      case MessageType.system: // Add this case
        return 'system';
      default:
        return 'text';
    }
  }

  // Méthode utilitaire pour vérifier si c'est l'utilisateur courant
  bool isFromUser(String currentUserId) {
    return senderId == currentUserId;
  }

  // Helper methods for call messages
  bool get isCallMessage {
    return type == MessageType.system && 
           (text.contains('📞') || (extraData?['isCall'] == true));
  }

  bool get isMissedCall {
    return isCallMessage && (extraData?['isMissedCall'] == true);
  }

  int get callDuration {
    return extraData?['callDuration'] ?? 0;
  }

  // Méthode pour debug
  @override
  String toString() {
    return 'Message{id: $id, text: $text, senderId: $senderId, type: $type, extraData: $extraData}';
  }
}