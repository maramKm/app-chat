import 'package:cloud_firestore/cloud_firestore.dart';

class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Envoyer une demande d'ami
  Future<void> sendFriendRequest({
    required String fromUserId,
    required String toUserId,
    required Map<String, dynamic> fromUserInfo,
  }) async {
    try {
      // Vérifier si une demande existe déjà
      final existingRequest = await _firestore
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: fromUserId)
          .where('toUserId', isEqualTo: toUserId)
          .where('status', whereIn: ['pending', 'accepted'])
          .get();

      if (existingRequest.docs.isNotEmpty) {
        throw Exception('Demande déjà envoyée');
      }

      // Créer la demande automatiquement
      await _firestore.collection('friend_requests').add({
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'fromUserInfo': fromUserInfo,
      });

      print(' Demande d\'ami envoyée!');
    } catch (e) {
      print('Erreur envoi demande: $e');
      rethrow;
    }
  }

  // Accepter une demande (sans créer friendships)
  Future<void> acceptFriendRequest(String requestId, Map<String, dynamic> requestData) async {
    try {
      await _firestore
          .collection('friend_requests')
          .doc(requestId)
          .update({'status': 'accepted'});
      
      print('Demande acceptée!');
    } catch (e) {
      print('Erreur acceptation: $e');
      rethrow;
    }
  }

  // Refuser une demande
  Future<void> rejectFriendRequest(String requestId) async {
    await _firestore
        .collection('friend_requests')
        .doc(requestId)
        .update({'status': 'rejected'});
  }

  // Récupérer les demandes reçues (SANS le orderBy timestamp)
Stream<QuerySnapshot> getReceivedRequests(String userId) {
  return _firestore
      .collection('friend_requests')
      .where('toUserId', isEqualTo: userId)
      .where('status', isEqualTo: 'pending')
      // .orderBy('timestamp', descending: true) // ← ENLEVÉ temporairement
      .snapshots();
}

  // Récupérer les demandes envoyées
  Stream<QuerySnapshot> getSentRequests(String userId) {
    return _firestore
        .collection('friend_requests')
        .where('fromUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

 // Récupérer les amis
Stream<List<Map<String, dynamic>>> getFriendsUsers(String userId) {
  try {
    return _firestore
        .collection('friend_requests')
        .where('status', isEqualTo: 'accepted')
        .where('toUserId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      
      final friendsData = <Map<String, dynamic>>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final fromUserInfo = data['fromUserInfo'] as Map<String, dynamic>?;
        
        if (fromUserInfo != null) {
          friendsData.add({
            'id': data['fromUserId'],
            'name': fromUserInfo['name'] ?? 'Utilisateur',
            'email': fromUserInfo['email'] ?? '',
            'profileImage': fromUserInfo['profileImage'] ?? '',
            'isOnline': fromUserInfo['isOnline'] ?? false,
            'lastSeen': Timestamp.now(), // ← CORRECTION: Utiliser Timestamp au lieu de DateTime
          });
        }
      }

      return friendsData;
    });
  } catch (e) {
    print('Erreur getFriendsUsers: $e');
    return Stream.value([]);
  }
}

  // Vérifier si deux users sont amis
  Future<bool> areFriends(String user1, String user2) async {
    try {
      final friendship = await _firestore
          .collection('friend_requests')
          .where('status', isEqualTo: 'accepted')
          .where('fromUserId', isEqualTo: user1)
          .where('toUserId', isEqualTo: user2)
          .limit(1)
          .get();

      return friendship.docs.isNotEmpty;
    } catch (e) {
      print('Erreur areFriends: $e');
      return false;
    }
  }

  // Méthode legacy pour compatibilité
  Stream<QuerySnapshot> getFriends(String userId) {
    return _firestore
        .collection('friend_requests')
        .where('status', isEqualTo: 'accepted')
        .where('toUserId', isEqualTo: userId)
        .snapshots();
  }
}