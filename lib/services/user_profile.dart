import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Récupère les infos d'un user à partir de son uid
  Future<Map<String, dynamic>?> getUser(String uid) async {
    DocumentSnapshot snap =
        await _db.collection('users').doc(uid).get();

    if (!snap.exists) return null;
    return snap.data() as Map<String, dynamic>;
  }

  /// Ajoute comme ami
  Future<void> addFriend(String myUid, String friendUid) async {
    await _db.collection('users')
        .doc(myUid)
        .collection('friends')
        .doc(friendUid)
        .set({'addedAt': DateTime.now()});
  }
}
