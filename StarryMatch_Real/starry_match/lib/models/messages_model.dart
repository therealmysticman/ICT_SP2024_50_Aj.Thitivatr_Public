import 'package:cloud_firestore/cloud_firestore.dart';
class Message {
  String senderId;
  String text;
  String roomId; // ✅ Added this to link with `RoomID`
  Timestamp timeStamp;

  Message({
    required this.senderId,
    required this.text,
    required this.roomId,
    required this.timeStamp,
  });

  factory Message.fromMap(Map<String, dynamic> data) {
    return Message(
      senderId: data["SenderID"] ?? "",
      text: data["Text"] ?? "",
      roomId: data["RoomID"] ?? "", // ✅ Added `RoomID`
      timeStamp: data["TimeStamp"] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "SenderID": senderId,
      "Text": text,
      "RoomID": roomId, // ✅ Ensure `RoomID` is in Firestore
      "TimeStamp": timeStamp,
    };
  }
}
