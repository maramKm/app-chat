// lib/services/presence_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class PresenceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const int HEARTBEAT_INTERVAL = 30; // secondes
  static const int OFFLINE_THRESHOLD = 65; // secondes

  // Mettre à jour le statut en ligne
  Future<void> updateOnlineStatus() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    
    await _firestore.collection('users').doc(user.uid).update({
      'isOnline': true,
      'lastHeartbeat': now,
      'lastSeen': now,
    });
  }

  // Mettre à jour le statut hors ligne
  Future<void> updateOfflineStatus() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'isOnline': false,
      'lastSeen': DateTime.now(),
    });
  }

  // Vérifier si un utilisateur est vraiment en ligne
  bool isUserOnline(Map<String, dynamic> userData) {
    try {
      final isOnline = userData['isOnline'] ?? false;
      final lastHeartbeat = userData['lastHeartbeat'];
      
      // Si pas de heartbeat, utiliser lastSeen
      if (lastHeartbeat == null) {
        final lastSeen = userData['lastSeen'];
        if (lastSeen == null) return false;
        
        final lastSeenTime = _parseTimestamp(lastSeen);
        final difference = DateTime.now().difference(lastSeenTime);
        return difference.inSeconds < OFFLINE_THRESHOLD;
      }
      
      // Vérifier le heartbeat
      final heartbeatTime = _parseTimestamp(lastHeartbeat);
      final difference = DateTime.now().difference(heartbeatTime);
      
      return isOnline && difference.inSeconds < OFFLINE_THRESHOLD;
      
    } catch (e) {
      print('Erreur vérification statut: $e');
      return false;
    }
  }

  DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    } else if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else if (timestamp is String) {
      return DateTime.parse(timestamp);
    } else {
      return DateTime.now();
    }
  }

  // Démarrer le heartbeat
  void startHeartbeat() {
    // Mettre à jour immédiatement
    updateOnlineStatus();
    
    // Puis toutes les 30 secondes
    Future.delayed(const Duration(seconds: HEARTBEAT_INTERVAL), () {
      if (_auth.currentUser != null) {
        updateOnlineStatus();
        startHeartbeat(); 
      }
    });
  }

  // Obtenir le stream de présence d'un utilisateur
  Stream<Map<String, dynamic>> getUserPresenceStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) => snapshot.data() ?? {});
  }

  // Formater le texte "last seen"
  String getLastSeenText(Map<String, dynamic> userData) {
    final lastSeen = userData['lastSeen'];
    if (lastSeen == null) return 'Hors ligne';
    
    final lastSeenTime = _parseTimestamp(lastSeen);
    final difference = DateTime.now().difference(lastSeenTime);
    
    if (difference.inSeconds < 60) return 'En ligne';
    if (difference.inMinutes < 1) return 'À l\'instant';
    if (difference.inMinutes < 60) return 'Il y a ${difference.inMinutes} min';
    if (difference.inHours < 24) return 'Il y a ${difference.inHours} h';
    if (difference.inDays < 7) return 'Il y a ${difference.inDays} j';
    return 'Il y a ${(difference.inDays / 7).floor()} sem';
  }
}