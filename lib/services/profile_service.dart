import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _imagePicker = ImagePicker();

  String get uid => _auth.currentUser!.uid;

  Stream<Map<String, dynamic>?> get userProfileStream {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((s) => s.data());
  }

  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update(data);
  }

  /// Sélectionner une image et renvoyer le Base64
  Future<String?> pickProfileImageBase64() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );

    if (image != null) {
      final bytes = await File(image.path).readAsBytes();
      final base64Image = base64Encode(bytes);
      await updateUserProfile({'profileImageBase64': base64Image});
      return base64Image;
    }
    return null;
  }
}
