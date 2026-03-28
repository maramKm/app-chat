// models/call_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum CallType { voice }
enum CallStatus { ringing, ongoing, ended, missed }

class CallData {
  final String callId;
  final String callerId;
  final String receiverId;
  final String callerName;
  final String receiverName;
  final CallType callType;
  final CallStatus status;
  final DateTime startedAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;

  CallData({
    required this.callId,
    required this.callerId,
    required this.receiverId,
    required this.callerName,
    required this.receiverName,
    required this.callType,
    required this.status,
    required this.startedAt,
    this.answeredAt,
    this.endedAt,
  });

  factory CallData.fromMap(Map<String, dynamic> data) {
    return CallData(
      callId: data['callId'] ?? '',
      callerId: data['callerId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      callerName: data['callerName'] ?? '',
      receiverName: data['receiverName'] ?? '',
      callType: CallType.values.firstWhere(
        (e) => e.toString().split('.').last == data['callType'],
        orElse: () => CallType.voice,
      ),
      status: CallStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => CallStatus.ringing,
      ),
      startedAt: (data['startedAt'] as Timestamp).toDate(),
      answeredAt: data['answeredAt'] != null 
          ? (data['answeredAt'] as Timestamp).toDate() 
          : null,
      endedAt: data['endedAt'] != null 
          ? (data['endedAt'] as Timestamp).toDate() 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'callId': callId,
      'callerId': callerId,
      'receiverId': receiverId,
      'callerName': callerName,
      'receiverName': receiverName,
      'callType': callType.toString().split('.').last,
      'status': status.toString().split('.').last,
      'startedAt': Timestamp.fromDate(startedAt),
      'answeredAt': answeredAt != null ? Timestamp.fromDate(answeredAt!) : null,
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'participants': [callerId, receiverId], // Pour les requêtes
    };
  }

  // Durée de l'appel
  Duration get duration {
    if (answeredAt == null) return Duration.zero;
    final end = endedAt ?? DateTime.now();
    return end.difference(answeredAt!);
  }

  // Vérifier si l'appel est en cours
  bool get isOngoing => status == CallStatus.ongoing;
  
  // Vérifier si l'appel est manqué
  bool get isMissed => status == CallStatus.missed;
}

class CallResult {
  final bool success;
  final String? callId;
  final String? errorMessage;

  CallResult({
    required this.success,
    this.callId,
    this.errorMessage,
  });
}