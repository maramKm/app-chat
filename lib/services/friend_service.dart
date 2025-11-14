import 'package:cloud_firestore/cloud_firestore.dart';

class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 🔹 Envoyer une demande d’ami
  Future<void> sendFriendRequest({
    required String fromUserId,
    required String toUserId,
    required Map<String, dynamic> fromUserInfo,
    required Map<String, dynamic> toUserInfo,
  }) async {
    try {
      // Vérifier si une demande "active" existe déjà (pending ou accepted)
      final existingRequest = await _firestore
          .collection('friend_requests')
          .where(Filter.or(
        Filter.and(
          Filter('fromUserId', isEqualTo: fromUserId),
          Filter('toUserId', isEqualTo: toUserId),
        ),
        Filter.and(
          Filter('fromUserId', isEqualTo: toUserId),
          Filter('toUserId', isEqualTo: fromUserId),
        ),
      ))
          .where('status', whereIn: ['pending', 'accepted'])
          .get();

      if (existingRequest.docs.isNotEmpty) {
        throw Exception('Une demande existe déjà entre ces utilisateurs.');
      }

      await _firestore.collection('friend_requests').add({
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'fromUserInfo': fromUserInfo,
        'toUserInfo': toUserInfo,
      });

      print('✅ Demande d’ami envoyée');
    } catch (e) {
      print('❌ Erreur envoi demande: $e');
      rethrow;
    }
  }

  /// 🔹 Accepter une demande d’ami
  Future<void> acceptFriendRequest(String requestId,
      Map<String, dynamic> requestData) async {
    try {
      final fromUserId = requestData['fromUserId'];
      final toUserId = requestData['toUserId'];
      final fromUserInfo = requestData['fromUserInfo'] ?? {};
      final toUserInfo = requestData['toUserInfo'] ?? {};

      await _firestore
          .collection('friend_requests')
          .doc(requestId)
          .update({'status': 'accepted'});

      // Créer la relation inverse si elle n'existe pas
      final reverseExists = await _firestore
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: toUserId)
          .where('toUserId', isEqualTo: fromUserId)
          .where('status', isEqualTo: 'accepted')
          .get();

      if (reverseExists.docs.isEmpty) {
        await _firestore.collection('friend_requests').add({
          'fromUserId': toUserId,
          'toUserId': fromUserId,
          'status': 'accepted',
          'timestamp': FieldValue.serverTimestamp(),
          'fromUserInfo': toUserInfo,
          'toUserInfo': fromUserInfo,
        });
      }

      print('✅ Demande d’ami acceptée dans les deux sens');
    } catch (e) {
      print('❌ Erreur acceptation: $e');
      rethrow;
    }
  }

  /// 🔹 Refuser une demande
  Future<void> rejectFriendRequest(String requestId) async {
    await _firestore
        .collection('friend_requests')
        .doc(requestId)
        .update({'status': 'rejected'});
  }

  /// 🔹 Supprimer un ami / toutes relations bidirectionnelles
  Future<void> removeFriend({
    required String userId,
    required String friendId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('friend_requests')
          .where(Filter.or(
        Filter.and(
          Filter('fromUserId', isEqualTo: userId),
          Filter('toUserId', isEqualTo: friendId),
        ),
        Filter.and(
          Filter('fromUserId', isEqualTo: friendId),
          Filter('toUserId', isEqualTo: userId),
        ),
      ))
          .get();

      for (final doc in snapshot.docs) {
        await _firestore.collection('friend_requests').doc(doc.id).delete();
      }

      print('✅ Ami supprimé avec succès');
    } catch (e) {
      print('❌ Erreur suppression ami: $e');
      rethrow;
    }
  }

  /// 🔹 Récupérer les amis (fusion unique)
  Stream<List<Map<String, dynamic>>> getFriendsUsers(String userId) {
    try {
      return _firestore
          .collection('friend_requests')
          .where('status', isEqualTo: 'accepted')
          .where(Filter.or(
        Filter('fromUserId', isEqualTo: userId),
        Filter('toUserId', isEqualTo: userId),
      ))
          .snapshots()
          .map((snapshot) {
        final friendsMap = <String, Map<String, dynamic>>{};

        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final friendId =
          data['fromUserId'] == userId ? data['toUserId'] : data['fromUserId'];
          final friendInfo =
          data['fromUserId'] == userId ? data['toUserInfo'] ?? {} : data['fromUserInfo'] ?? {};

          friendsMap[friendId] = {
            'id': friendId,
            'name': friendInfo['name'] ?? 'Utilisateur',
            'email': friendInfo['email'] ?? '',
            'profileImage': friendInfo['profileImage'] ?? '',
            'isOnline': friendInfo['isOnline'] ?? false,
            'lastSeen': friendInfo['lastSeen'] ?? Timestamp.now(),
          };
        }

        return friendsMap.values.toList();
      });
    } catch (e) {
      print('❌ Erreur getFriendsUsers: $e');
      return Stream.value([]);
    }
  }

  /// 🔹 Récupérer les demandes d’ami reçues en "pending"
  Stream<QuerySnapshot> getReceivedRequests(String userId) {
    return _firestore
        .collection('friend_requests')
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

}
