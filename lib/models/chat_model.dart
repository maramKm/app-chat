import 'package:cloud_firestore/cloud_firestore.dart';

class Chat {
  final String id;
  final String name;
  final String lastMessage;
  final DateTime timestamp;
  final int unreadCount;
  final bool isOnline;
  final String profileImage;
  final bool isGroup;
  final String otherUserId; // ← AJOUTEZ CE CHAMP

  Chat({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.timestamp,
    this.unreadCount = 0,
    this.isOnline = false,
    this.profileImage = '',
    this.isGroup = false,
    required this.otherUserId, // ← AJOUTEZ-LE
  });

  factory Chat.fromMap(Map<String, dynamic> data, String id) {
    return Chat(
      id: id,
      name: data['name'] ?? '',
      lastMessage: data['lastMessage'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadCount: data['unreadCount'] ?? 0,
      isOnline: data['isOnline'] ?? false,
      profileImage: data['profileImage'] ?? '',
      isGroup: data['isGroup'] ?? false,
      otherUserId: data['otherUserId'] ?? '',    
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'lastMessage': lastMessage,
      'timestamp': Timestamp.fromDate(timestamp),
      'unreadCount': unreadCount,
      'isOnline': isOnline,
      'profileImage': profileImage,
      'isGroup': isGroup,
      'otherUserId': otherUserId, // ← AJOUTEZ
    };
  }
}