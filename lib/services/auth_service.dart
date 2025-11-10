import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up
  Future<String?> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      // Create user in Firebase Auth
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name in Firebase Auth
      await credential.user!.updateDisplayName(name);

     await _firestore.collection('users').doc(credential.user!.uid).set({
  'uid': credential.user!.uid,
  'email': email,
  'name': name,
  'phone': '', // Champ téléphone vide par défaut
  'createdAt': FieldValue.serverTimestamp(),
  'lastSeen': FieldValue.serverTimestamp(),
  'isOnline': true,
  'profileImage': '', // Champ photo de profil vide par défaut
  'bio': 'Hey there! I am using KONVO', // Bio par défaut
 
});

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // Sign in
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update user status to online
      if (_auth.currentUser != null) {
        await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
          'isOnline': true,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // Sign out
  Future<void> signOut() async {
    // Update user status to offline
    if (_auth.currentUser != null) {
      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }

    await _auth.signOut();
  }

  // Get user data from Firestore
  Stream<Map<String, dynamic>?> getUserData(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snapshot) => snapshot.data());
  }

  // Get current user data
  Map<String, dynamic>? getCurrentUserData() {
    if (_auth.currentUser == null) return null;
    
    return {
      'uid': _auth.currentUser!.uid,
      'email': _auth.currentUser!.email,
      'name': _auth.currentUser!.displayName,
      'phone': _auth.currentUser!.phoneNumber,
      'profileImage': _auth.currentUser!.photoURL,
    };
  }

  // Update user email
  Future<String?> updateEmail(String newEmail) async {
    try {
      await _auth.currentUser!.updateEmail(newEmail);
      
      // Also update in Firestore
      if (_auth.currentUser != null) {
        await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
          'email': newEmail,
        });
      }
      
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // Update user display name
  Future<String?> updateDisplayName(String newName) async {
    try {
      await _auth.currentUser!.updateDisplayName(newName);
      
      // Also update in Firestore
      if (_auth.currentUser != null) {
        await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
          'name': newName,
        });
      }
      
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // Update user phone number
  Future<String?> updatePhoneNumber(String newPhone) async {
    try {
      // Update in Firestore (phone number in Auth requires verification)
      if (_auth.currentUser != null) {
        await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
          'phone': newPhone,
        });
      }
      
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Update user bio
  Future<String?> updateBio(String newBio) async {
    try {
      if (_auth.currentUser != null) {
        await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
          'bio': newBio,
        });
      }
      
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Update profile image
  Future<String?> updateProfileImage(String imageUrl) async {
    try {
      await _auth.currentUser!.updatePhotoURL(imageUrl);
      
      // Also update in Firestore
      if (_auth.currentUser != null) {
        await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
          'profileImage': imageUrl,
        });
      }
      
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // Get user by ID
  Future<Map<String, dynamic>?> getUserById(String uid) async {
    try {
      DocumentSnapshot snapshot = await _firestore.collection('users').doc(uid).get();
      return snapshot.data() as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  // Check if user exists
  Future<bool> userExists(String uid) async {
    try {
      DocumentSnapshot snapshot = await _firestore.collection('users').doc(uid).get();
      return snapshot.exists;
    } catch (e) {
      return false;
    }
  }

  // Delete user account
  Future<String?> deleteAccount() async {
    try {
      if (_auth.currentUser != null) {
        // Delete from Firestore first
        await _firestore.collection('users').doc(_auth.currentUser!.uid).delete();
        
        // Then delete from Auth
        await _auth.currentUser!.delete();
      }
      
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // Send password reset email
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // Reauthenticate user (required for sensitive operations)
  Future<String?> reauthenticate(String password) async {
    try {
      AuthCredential credential = EmailAuthProvider.credential(
        email: _auth.currentUser!.email!,
        password: password,
      );
      await _auth.currentUser!.reauthenticateWithCredential(credential);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }
}

extension on User {
  Future<void> updateEmail(String newEmail) async {}
}