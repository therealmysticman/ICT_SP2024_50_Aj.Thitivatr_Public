import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoom {
  final String roomId;
  final List<String> participants;
  final int roomQuantity;
  final String roomType;
  final Timestamp createdAt;
  final int maxParticipants; // Maximum number of participants for group chat
  final Map<String, String> participantNames;
  final Map<String, String> participantTypes;
  final List<String>? targetPersonalityTypes; // For group chat - top 3 recommended types
  final String? userPersonalityType;
  final String? otherUserPersonalityType;

  ChatRoom({
    required this.roomId,
    required this.participants,
    required this.roomQuantity,
    required this.roomType,
    required this.createdAt,
    this.maxParticipants = 4,
    required this.participantNames,
    required this.participantTypes,
    this.targetPersonalityTypes,
    this.userPersonalityType,
    this.otherUserPersonalityType,
  });

  // Factory method to create an instance from Firestore data
  factory ChatRoom.fromMap(Map<String, dynamic> data) {
    return ChatRoom(
      roomId: data["RoomID"],
      participants: List<String>.from(data["Participants"]),
      roomQuantity: data["RoomQuantity"],
      roomType: data["RoomType"],
      createdAt: data["CreatedAt"] ?? Timestamp.now(),
      maxParticipants: data["MaxParticipants"] ?? 4,
      participantNames: Map<String, String>.from(data["ParticipantNames"] ?? {}),
      participantTypes: Map<String, String>.from(data["ParticipantTypes"] ?? {}),
      targetPersonalityTypes: data["TargetPersonalityTypes"] != null 
          ? List<String>.from(data["TargetPersonalityTypes"]) 
          : null,
      userPersonalityType: data["UserPersonalityType"],
      otherUserPersonalityType: data["OtherUserPersonalityType"],
    );
  }

  // Convert object to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      "RoomID": roomId,
      "Participants": participants,
      "RoomQuantity": roomQuantity,
      "RoomType": roomType,
      "CreatedAt": createdAt,
      "MaxParticipants": maxParticipants,
      "ParticipantNames": participantNames,
      "ParticipantTypes": participantTypes,
      "TargetPersonalityTypes": targetPersonalityTypes,
      "UserPersonalityType": userPersonalityType,
      "OtherUserPersonalityType": otherUserPersonalityType,
    };
  }

  // Helper method to check if room is full
  bool get isFull => participants.length >= maxParticipants;

  // Helper method to check if this is a group chat
  bool get isGroupChat => roomType == "Group";

  // Helper method to check if a personality type matches target types
  bool matchesTargetPersonality(String personalityType) {
    if (!isGroupChat || targetPersonalityTypes == null) return false;
    return targetPersonalityTypes!.contains(personalityType);
  }

  // Helper method to get participant's personality type
  String? getParticipantType(String userId) => participantTypes[userId];

  // Helper method to get participant's display name
  String getParticipantName(String userId) => participantNames[userId] ?? "Anonymous";
}
