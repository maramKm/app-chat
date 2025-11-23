import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:konvo/models/message_model.dart';
import 'package:konvo/models/chat_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String chatId;

  ChatService({required this.chatId});

  // Référence à la collection des messages pour un chat spécifique
  CollectionReference get _messagesCollection =>
      _firestore.collection('chats').doc(chatId).collection('messages');

  // Stream des messages en temps réel
  Stream<List<Message>> getMessagesStream() {
    return _messagesCollection
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Message.fromFirestore(doc);
      }).toList();
    });
  }

  Future<void> sendMessage(Message message) async {
    try {
      await _messagesCollection.doc(message.id).set({
        'text': message.text,
        'senderId': message.senderId,
        'senderName': message.senderName,
        'timestamp': Timestamp.fromDate(message.timestamp),
        'type': _messageTypeToString(message.type),
        'mediaUrl': message.mediaUrl,
      });
    } catch (e) {
      throw Exception('Erreur lors de l\'envoi du message: $e');
    }
  }

  String _messageTypeToString(MessageType type) {
    switch (type) {
      case MessageType.image:
        return 'image';
      case MessageType.file:
        return 'file';
      case MessageType.audio:
        return 'audio';
      default:
        return 'text';
    }
  }

  Future<bool> isChatEmpty() async {
    try {
      final snapshot = await _messagesCollection.limit(1).get();
      return snapshot.docs.isEmpty;
    } catch (e) {
      throw Exception('Erreur lors de la vérification du chat: $e');
    }
  }

  Future<void> updateLastMessage(String text, String senderId, String senderName) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': text,
        'lastSenderId': senderId,
        'lastSenderName': senderName,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour du dernier message: $e');
    }
  }

  Future<void> markMessagesAsRead(String userId) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'unreadCount': 0,
      });
    } catch (e) {
      throw Exception('Erreur lors du marquage des messages comme lus: $e');
    }
  }

  static Stream<List<Chat>> getChatsStream() {
    return FirebaseFirestore.instance
        .collection('chats')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Chat> chats = [];
      for (var doc in snapshot.docs) {
        final chat = await _mapFirestoreToChat(doc);
        chats.add(chat);
      }
      return chats;
    });
  }

  static Stream<List<Chat>> getUserChatsStream(String userId) {
    return FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Chat> chats = [];
      for (var doc in snapshot.docs) {
        final chat = await _mapFirestoreToChatWithOtherUser(doc, userId);
        chats.add(chat);
      }
      return chats;
    });
  }

  static Future<Chat> createChat({
    required String currentUserId,
    required String otherUserId,
    required String otherUserName,
    required String otherUserProfileImage,
  }) async {
    try {
      final chatId = _generateChatId(currentUserId, otherUserId);

      final chat = Chat(
        id: chatId,
        name: otherUserName,
        lastMessage: 'Démarrer la conversation',
        timestamp: DateTime.now(),
        unreadCount: 0,
        isOnline: false,
        profileImage: otherUserProfileImage,
        isGroup: false,
        otherUserId: otherUserId, 
      );

      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'id': chatId,
        'name': otherUserName,
        'lastMessage': 'Démarrer la conversation',
        'timestamp': FieldValue.serverTimestamp(),
        'unreadCount': 0,
        'isOnline': false,
        'profileImage': otherUserProfileImage,
        'isGroup': false,
        'participants': [currentUserId, otherUserId],
        'otherUserId': otherUserId, 
        'createdAt': FieldValue.serverTimestamp(),
      });

      return chat;
    } catch (e) {
      throw Exception('Erreur lors de la création du chat: $e');
    }
  }

  static Future<Chat> getOrCreateChat({
    required String currentUserId,
    required String otherUserId,
    required String otherUserName,
    required String otherUserProfileImage,
  }) async {
    try {
      final chatId = _generateChatId(currentUserId, otherUserId);
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();

      Chat chat;
      if (chatDoc.exists) {
        chat = await _mapFirestoreToChatWithOtherUser(chatDoc, currentUserId);
      } else {
        chat = await createChat(
          currentUserId: currentUserId,
          otherUserId: otherUserId,
          otherUserName: otherUserName,
          otherUserProfileImage: otherUserProfileImage,
        );
      }

      return chat;
    } catch (e) {
      throw Exception('Erreur lors de la récupération/création du chat: $e');
    }
  }

  static Future<Chat> _mapFirestoreToChatWithOtherUser(DocumentSnapshot doc, String currentUserId) async {
    final data = doc.data() as Map<String, dynamic>;
    final participants = List<String>.from(data['participants'] ?? []);
    
    // Récupérer l'ID de l'autre utilisateur
    String otherUserId = participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => currentUserId,
    );
    
    // Récupérer le nom de l'autre utilisateur
    String otherUserName = await _getUserName(otherUserId);

    return Chat(
      id: data['id'] ?? doc.id,
      name: otherUserName,
      lastMessage: data['lastMessage'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadCount: data['unreadCount'] ?? 0,
      isOnline: data['isOnline'] ?? false,
      profileImage: data['profileImage'] ?? '',
      isGroup: data['isGroup'] ?? false,
      otherUserId: data['otherUserId'] ?? otherUserId, 
    );
  }

  static Future<Chat> _mapFirestoreToChat(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    return Chat(
      id: data['id'] ?? doc.id,
      name: data['name'] ?? 'Sans nom',
      lastMessage: data['lastMessage'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadCount: data['unreadCount'] ?? 0,
      isOnline: data['isOnline'] ?? false,
      profileImage: data['profileImage'] ?? '',
      isGroup: data['isGroup'] ?? false,
      otherUserId: data['otherUserId'] ?? '', 
    );
  }

  static Future<String> _getUserName(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        return userData?['name'] ?? 'Utilisateur inconnu';
      } else {
        return 'Utilisateur inconnu';
      }
    } catch (e) {
      return 'Utilisateur inconnu';
    }
  }

  static String _generateChatId(String user1, String user2) {
    List<String> users = [user1, user2];
    users.sort();
    return '${users[0]}_${users[1]}';
  }

  Future<void> deleteChatInstance() async {
    try {
      final messages = await _messagesCollection.get();
      for (final doc in messages.docs) {
        await doc.reference.delete();
      }
      await _firestore.collection('chats').doc(chatId).delete();
    } catch (e) {
      throw Exception('Erreur lors de la suppression du chat: $e');
    }
  }

  static Future<void> deleteChat(String chatId) async {
    try {
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      await FirebaseFirestore.instance.collection('chats').doc(chatId).delete();

    } catch (e) {
      throw Exception('Erreur lors de la suppression de la conversation: $e');
    }
  }

  Future<Chat> getChatInfo() async {
    try {
      final doc = await _firestore.collection('chats').doc(chatId).get();
      if (doc.exists) {
        return await _mapFirestoreToChat(doc);
      } else {
        throw Exception('Chat non trouvé');
      }
    } catch (e) {
      throw Exception('Erreur lors de la récupération des infos du chat: $e');
    }
  }

  Future<int> getUnreadCount(String userId) async {
    try {
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      final data = chatDoc.data() as Map<String, dynamic>;
      return data['unreadCount'] ?? 0;
    } catch (e) {
      return 0;
    }
  }
}