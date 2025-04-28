import 'package:cloud_firestore/cloud_firestore.dart';

class Endorsement {
  final String id;
  final String endorserId;
  final String endorserName;
  final String endorsedUserId;
  final String skill;
  final Timestamp timestamp;

  Endorsement({
    required this.id,
    required this.endorserId,
    required this.endorserName,
    required this.endorsedUserId,
    required this.skill,
    required this.timestamp,
  });

  factory Endorsement.fromMap(Map<String, dynamic> map, String id) {
    return Endorsement(
      id: id,
      endorserId: map['endorserId'] ?? '',
      endorserName: map['endorserName'] ?? '',
      endorsedUserId: map['endorsedUserId'] ?? '',
      skill: map['skill'] ?? '',
      timestamp: map['timestamp'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'endorserId': endorserId,
      'endorserName': endorserName,
      'endorsedUserId': endorsedUserId,
      'skill': skill,
      'timestamp': timestamp,
    };
  }
} 