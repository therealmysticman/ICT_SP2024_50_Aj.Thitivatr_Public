import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String userId;
  final String type; // 'endorsement', 'message', etc.
  final String title;
  final String message;
  final bool isRead;
  final Timestamp timestamp;
  final String? status; // 'accepted', 'rejected', etc.
  final Map<String, dynamic>? data;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    required this.timestamp,
    this.status,
    this.data,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      userId: map['userId'] ?? '',
      type: map['type'] ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      isRead: map['isRead'] ?? false,
      timestamp: map['timestamp'] ?? Timestamp.now(),
      status: map['status'],
      data: map['data'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type,
      'title': title,
      'message': message,
      'isRead': isRead,
      'timestamp': timestamp,
      'status': status,
      'data': data,
    };
  }
} 