import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String id;
  final String name;
  final String email;
  final String profileImage;
  final bool isOnline;
  final DateTime lastSeen;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.profileImage,
    required this.isOnline,
    required this.lastSeen,
  });

  // Méthode fromMap manquante
  factory User.fromMap(Map<String, dynamic> data, String id) {
    return User(
      id: id,
      name: data['name'] ?? 'Utilisateur',
      email: data['email'] ?? '',
      profileImage: data['profileImage'] ?? '',
      isOnline: data['isOnline'] ?? false,
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Méthode pour convertir en Map (optionnel)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'profileImage': profileImage,
      'isOnline': isOnline,
      'lastSeen': Timestamp.fromDate(lastSeen),
    };
  }
}