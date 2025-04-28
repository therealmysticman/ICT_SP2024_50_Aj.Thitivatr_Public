import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Improved method to clean up active chatrooms during app startup
  static Future<void> cleanupActiveChatrooms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get any chatroom data from previous session
      final activeChatroomId = prefs.getString('active_chatroom_id');
      final activeChatroomUserId = prefs.getString('active_chatroom_user_id');
      
      if (activeChatroomId != null && activeChatroomUserId != null) {
        debugPrint("🧹 Checking chatroom: $activeChatroomId for user $activeChatroomUserId");
        
        // Skip friend chatrooms - they should be persistent
        if (activeChatroomId.contains('friend_')) {
          debugPrint("📝 Skipping cleanup for friend chatroom");
          
          // Just clear typing status for friend chatrooms
          try {
            await FirebaseFirestore.instance
                .collection('starrymatch_friend_chatroom')
                .doc(activeChatroomId)
                .collection('typing')
                .doc(activeChatroomUserId)
                .delete();
                
            debugPrint("✅ Cleared typing status for friend chatroom");
          } catch (e) {
            debugPrint("⚠️ Error clearing typing status: $e");
          }
          
          // Clear saved data
          await prefs.remove('active_chatroom_id');
          await prefs.remove('active_chatroom_user_id');
          return;
        }
        
        // Only handle regular chatrooms
        try {
          // First update user status
          await FirebaseFirestore.instance
              .collection("starrymatch_user")
              .doc(activeChatroomUserId)
              .update({"IsInChatroom": false});
          
          // Then update the chatroom participants list
          final roomRef = FirebaseFirestore.instance
              .collection('starrymatch_chatroom')
              .doc(activeChatroomId);
              
          final roomDoc = await roomRef.get();
          if (roomDoc.exists) {
            // Get current participants
            final data = roomDoc.data();
            if (data == null) {
              debugPrint("⚠️ No data in room document");
              return;
            }
            
            List<dynamic> participants = List<dynamic>.from(data['Participants'] ?? []);
            
            // Remove the user
            participants.removeWhere((p) => p == activeChatroomUserId);
            
            // Check if room is now empty or only contains "No one"
            bool onlyNoOne = participants.isEmpty || 
                (participants.length == 1 && participants[0] == "No one");
                
            if (onlyNoOne) {
              debugPrint("🗑️ Room only has 'No one' - deleting room: $activeChatroomId");
              
              // Create history record before deleting
              try {
                final historyRef = FirebaseFirestore.instance
                    .collection('starrymatch_chat_history')
                    .doc(activeChatroomId);
                
                // Add history if it doesn't exist
                if (!(await historyRef.get()).exists) {
                  List<dynamic> participantsHistory = data['ParticipantsHistory'] ?? [];
                  if (participantsHistory.isEmpty) {
                    participantsHistory = List.from(data['Participants'] ?? []);
                  }
                  
                  // Make sure user is in history
                  if (!participantsHistory.contains(activeChatroomUserId)) {
                    participantsHistory.add(activeChatroomUserId);
                  }
                  
                  await historyRef.set({
                    "Participants": participantsHistory,
                    "ParticipantsHistory": participantsHistory,
                    "RoomType": data["RoomType"],
                    "PersonalityCategory": data["PersonalityCategory"],
                    "CreatedAt": data["CreatedAt"],
                    "LastParticipant": activeChatroomUserId,
                  });
                  
                  debugPrint("✅ Created history record for room $activeChatroomId");
                }
                
                // Delete the room and its messages
                // First delete all messages
                final messagesSnapshot = await roomRef.collection('messages').get();
                for (var messageDoc in messagesSnapshot.docs) {
                  await messageDoc.reference.delete();
                }
                
                // Then delete the room itself
                await roomRef.delete();
                debugPrint("✅ Successfully deleted empty room $activeChatroomId");
              } catch (historyError) {
                debugPrint("⚠️ Error handling history: $historyError");
              }
            } else {
              // If room still has other users, just update it
              await roomRef.update({
                'Participants': participants,
                'IsEmpty': false,
              });
              
              // Also remove typing status
              await roomRef.collection('typing').doc(activeChatroomUserId).delete();
              
              debugPrint("✅ Successfully cleaned up user $activeChatroomUserId from chatroom $activeChatroomId");
            }
          } else {
            debugPrint("⚠️ Chatroom $activeChatroomId not found");
          }
        } catch (e) {
          debugPrint("⚠️ Error cleaning up chatroom: $e");
        }
        
        // Always clear saved data regardless of success
        await prefs.remove('active_chatroom_id');
        await prefs.remove('active_chatroom_user_id');
      }
      
      // Also look for any chatrooms where the only participant is "No one" and delete them
      try {
        debugPrint("🧹 Checking for empty chatrooms with only 'No one' participant");
        final emptyRoomsSnapshot = await FirebaseFirestore.instance
            .collection('starrymatch_chatroom')
            .where('Participants', isEqualTo: ["No one"])
            .get();
            
        for (var roomDoc in emptyRoomsSnapshot.docs) {
          final roomId = roomDoc.id;
          debugPrint("🗑️ Found empty room $roomId with only 'No one' - deleting");
          
          try {
            // Create history record if needed
            final historyRef = FirebaseFirestore.instance
                .collection('starrymatch_chat_history')
                .doc(roomId);
                
            if (!(await historyRef.get()).exists) {
              final data = roomDoc.data();
              List<dynamic> participantsHistory = data['ParticipantsHistory'] ?? [];
              
              await historyRef.set({
                "Participants": participantsHistory,
                "ParticipantsHistory": participantsHistory,
                "RoomType": data["RoomType"],
                "PersonalityCategory": data["PersonalityCategory"],
                "CreatedAt": data["CreatedAt"],
                "LastParticipant": "No one",
              });
            }
            
            // Delete all messages
            final messagesSnapshot = await roomDoc.reference.collection('messages').get();
            for (var messageDoc in messagesSnapshot.docs) {
              await messageDoc.reference.delete();
            }
            
            // Delete the room
            await roomDoc.reference.delete();
            debugPrint("✅ Successfully deleted empty room $roomId");
          } catch (e) {
            debugPrint("⚠️ Error deleting empty room $roomId: $e");
          }
        }
      } catch (e) {
        debugPrint("⚠️ Error searching for empty rooms: $e");
      }
    } catch (e) {
      debugPrint("❌ Error in cleanupActiveChatrooms: $e");
    }
  }
  
  // Static helper method to leave a specific chatroom
  static Future<void> _leaveSpecificChatroom(String roomId, String userId) async {
    try {
      // Determine the collection based on the roomId
      final collection = roomId.contains('friend_') 
          ? 'starrymatch_friend_chatroom' 
          : 'starrymatch_chatroom';
      
      // Get the chatroom document
      final roomDoc = await FirebaseFirestore.instance
          .collection(collection)
          .doc(roomId)
          .get();
          
      if (!roomDoc.exists) {
        debugPrint("⚠️ Room $roomId does not exist, skipping cleanup");
        return;
      }
      
      // Retrieve current participants
      List<dynamic> participants = roomDoc.data()?['Participants'] ?? [];
      
      // Remove the user from participants
      participants.remove(userId);
      
      // If we're the only one left, mark room as empty
      bool isEmpty = participants.isEmpty || (participants.length == 1 && participants[0] == "No one");
      
      // Update the room document
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(roomId)
          .update({
        'Participants': isEmpty ? ["No one"] : participants,
        'IsEmpty': isEmpty,
      });
      
      // Also remove typing status if it exists
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(roomId)
          .collection('typing')
          .doc(userId)
          .delete();
          
      debugPrint("✅ Successfully cleaned up user $userId from room $roomId");
    } catch (e) {
      debugPrint("❌ Error in _leaveSpecificChatroom: $e");
    }
  }

  // Add methods for typing indicator functionality
  Future<void> setTypingStatus(String roomId, String userId, bool isTyping) async {
    try {
      // Determine correct collection based on roomId
      final collection = roomId.contains('friend_') 
          ? 'starrymatch_friend_chatroom' 
          : 'starrymatch_chatroom';
      
      final typingRef = _firestore.collection(collection).doc(roomId).collection('typing');
      
      if (isTyping) {
        // Add user to typing collection
        await typingRef.doc(userId).set({
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
        // Remove user from typing collection
        await typingRef.doc(userId).delete();
      }
    } catch (e) {
      print('Error setting typing status: $e');
    }
  }

  Stream<List<String>> getTypingUsersStream(String roomId) {
    // Determine correct collection based on roomId
    final collection = roomId.contains('friend_') 
        ? 'starrymatch_friend_chatroom' 
        : 'starrymatch_chatroom';
    
    return _firestore
        .collection(collection)
        .doc(roomId)
        .collection('typing')
        .snapshots()
        .map((snapshot) {
      // Check for documents created within the last 10 seconds
      final now = DateTime.now();
      return snapshot.docs
          .where((doc) {
            final timestamp = doc.data()['timestamp'] as Timestamp?;
            if (timestamp == null) return true; // Include if no timestamp (fallback)
            
            final messageTime = timestamp.toDate();
            final difference = now.difference(messageTime);
            // Consider typing status valid for 5 seconds
            return difference.inSeconds <= 5;
          })
          .map((doc) => doc.data()['userId'] as String)
          .toList();
    });
  }

  // Mapping of equivalent criteria in different languages
final Map<String, List<String>> _criteriaEquivalents = {
    // Age groups
    "มหาวิทยาลัย": ["University", "College", "มหาวิทยาลัย"],
    "University": ["University", "College", "มหาวิทยาลัย"],
    "วัยทำงาน": ["Working Age", "วัยทำงาน"],
    "Working Age": ["Working Age", "วัยทำงาน"],
    "มัธยม": ["High School", "มัธยม"],
    "High School": ["High School", "มัธยม"],
    
    // Interests
    "อนิเมะ": ["Anime", "อนิเมะ"],
    "Anime": ["Anime", "อนิเมะ"],
    "ภาพยนตร์/ซีรีส์": ["Movies/Series", "ภาพยนตร์/ซีรีส์"],
    "Movies/Series": ["Movies/Series", "ภาพยนตร์/ซีรีส์"],
    "ดนตรี": ["Music", "ดนตรี"],
    "Music": ["Music", "ดนตรี"],
    "ท่องเที่ยว": ["Travel", "ท่องเที่ยว"],
    "Travel": ["Travel", "ท่องเที่ยว"],
    "พูดคุยลึกซึ้ง": ["Deep Talk", "พูดคุยลึกซึ้ง"],
    "Deep Talk": ["Deep Talk", "พูดคุยลึกซึ้ง"],
    "การเรียน": ["Study", "การเรียน"],
    "Study": ["Study", "การเรียน"],
    
    // New interests
    "เกม": ["Games", "เกม"],
    "Games": ["Games", "เกม"],
    "ศิลปะ": ["Art", "ศิลปะ"],
    "Art": ["Art", "ศิลปะ"],
    "อาหาร": ["Food", "อาหาร"],
    "Food": ["Food", "อาหาร"],
    
    // Additional interests
    "การทำงาน": ["Work", "การทำงาน"],
    "Work": ["Work", "การทำงาน"],
    "เทคโนโลยี": ["Technology", "เทคโนโลยี"],
    "Technology": ["Technology", "เทคโนโลยี"],
    "กีฬา": ["Sports", "กีฬา"],
    "Sports": ["Sports", "กีฬา"],
  };

  // Helper function to check if two criteria are equivalent
  bool _areCriteriaEquivalent(String criteria1, String criteria2) {
    // If they're exactly the same, they match
    if (criteria1 == criteria2) return true;

    // Check if they're in the same equivalence group
    List<String>? equivalents1 = _criteriaEquivalents[criteria1];
    List<String>? equivalents2 = _criteriaEquivalents[criteria2];

    if (equivalents1 != null && equivalents2 != null) {
      // Check if they share any equivalent terms
      return equivalents1.any((term) => equivalents2.contains(term));
    }

    return false;
  }

  // Helper function to check if two lists of criteria match
  bool _doCriteriaListsMatch(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;

    // For each item in list1, check if there's an equivalent in list2
    return list1.every(
        (item1) => list2.any((item2) => _areCriteriaEquivalent(item1, item2)));
  }

  Future<String> getOrCreateChatRoom(
      List<String> participants,
      String chatType,
      String criteria,
      String selectedCriteria,
      {String? personalityType,
      String? userPersonalityType,
      bool matchByPersonality = false,
      String? matchType}) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection("starrymatch_user").doc(participants[0]).get();

      if (!userDoc.exists) {
        throw Exception("🚫 User not found!");
      }

      // Extract or use the user's personality type
      String extractedUserPersonalityType = "";
      if (criteria == "MBTI") {
        extractedUserPersonalityType = (userDoc.data() as Map<String, dynamic>)["MBTITypes"] ?? "";
      } else if (criteria == "Enneagram") {
        extractedUserPersonalityType = (userDoc.data() as Map<String, dynamic>)["EnneagramTypes"] ?? "";
      }
      
      // Use provided userPersonalityType if given, otherwise use extracted value
      String finalUserPersonalityType = userPersonalityType ?? extractedUserPersonalityType;

      // Debug log with full detail
      print("🚨 CRITICAL DEBUG - Creating Chat Room:");
      print("⚙️ Parameters: chatType=$chatType");
      print("⚙️ Parameters: participants=$participants");
      print("⚙️ Parameters: personalityCategory=$criteria");
      print("⚙️ Parameters: selectedCriteria=$selectedCriteria");
      print("⚙️ Parameters: personalityType=$personalityType");
      print("⚙️ Parameters: userPersonalityType=$finalUserPersonalityType");
      print("⚙️ Parameters: matchByPersonality=$matchByPersonality");
      print("⚙️ Parameters: matchType=$matchType");

      // Special case for Neutral matchType - need less strict matching
      bool isNeutralMatch = matchType == "Neutral";
      if (isNeutralMatch) {
        print("⚠️ Using NEUTRAL match type for less strict personality matching");
      }
      
      // For group chats, try to find an existing room with space
      if (chatType == "Group") {
        // Split the personalityType string which contains top 3 recommended types
        List<String> targetPersonalities = personalityType?.split(", ") ?? [];

        print(
            "🎯 Looking for group chat with target personalities: $targetPersonalities");

        // Try to find existing groups that match any of the target personalities
        QuerySnapshot existingGroups = await _firestore
            .collection("starrymatch_chatroom")
            .where("RoomType", isEqualTo: "Group")
            .where("IsEmpty", isEqualTo: false)
            .where("IsFull", isEqualTo: false)
            .get(); // ไม่ใช้ arrayContainsAny ตรงนี้เพื่อป้องกันปัญหากับ TargetPersonalityTypes

        // Split our selected criteria for comparison
        List<String> ourCriteria =
            selectedCriteria.split(',').where((s) => s.isNotEmpty).toList();
        ourCriteria.sort(); // Sort for consistent comparison

        // Find first matching room with compatible criteria
        DocumentSnapshot? matchingRoom;
        for (var doc in existingGroups.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          String roomCriteria = data["SelectedCriteria"] ?? "";

          // Split and sort room's criteria for comparison
          List<String> roomCriteriaList =
              roomCriteria.split(',').where((s) => s.isNotEmpty).toList();
          roomCriteriaList.sort();

          // Check if criteria match using the equivalence system
          bool criteriaMatch =
              _doCriteriaListsMatch(ourCriteria, roomCriteriaList);
              
          // ตรวจสอบ TargetPersonalityTypes ว่ามีประเภทที่เราต้องการหรือไม่
          bool targetPersonalityMatch = false;
          List<dynamic>? roomTargetTypes = data["TargetPersonalityTypes"] as List<dynamic>?;
          
          if (roomTargetTypes != null && targetPersonalities.isNotEmpty) {
            // ตรวจสอบว่ามีอย่างน้อยหนึ่ง personality type ที่ตรงกัน
            for (String targetType in targetPersonalities) {
              if (roomTargetTypes.contains(targetType)) {
                targetPersonalityMatch = true;
                break;
              }
            }
          }
          
          // ต้องมีการตรงกันทั้ง criteria และ targetPersonality
          if (!targetPersonalityMatch) {
            continue; // ข้ามห้องนี้ไปถ้าไม่ตรงกัน
          }

          // Perfect match: Room creator wants our type AND room creator's type is what we want AND criteria match
          // Special case for Neutral match type: less strict matching
          bool isMatch = false;
          
          if (isNeutralMatch) {
            // For Neutral matchType, we're less strict - just need the criteria to match
            // We don't strictly check personality types when the match is "Neutral"
            print("🧪 NEUTRAL MATCHING LOGIC - Using less strict requirements");
            isMatch = criteriaMatch;
          } else {
            // Normal case - strict personality matching with array check
            // Check if our type is in the room's target list
            String? roomUserType = data["UserPersonalityType"] as String?;
            bool ourTypeMatched = roomTargetTypes?.contains(finalUserPersonalityType) ?? false;
            bool theirTypeMatched = targetPersonalities.contains(roomUserType);
            
            isMatch = ourTypeMatched && theirTypeMatched && criteriaMatch;
          }
          
          if (isMatch) {
            print("✅ FOUND MATCHING ROOM! Joining...");
            List<dynamic> currentParticipants =
                (data["Participants"] as List<dynamic>?) ?? [];

            // Add user to participants if not already there
            if (!currentParticipants.contains(participants[0])) {
              currentParticipants.add(participants[0]);
            }
            
            // Update the room
            await _firestore
                .collection("starrymatch_chatroom")
                .doc(doc.id)
                .update({
              "Participants": currentParticipants,
              "IsEmpty": false,
              "OtherUserPersonalityType":
                  finalUserPersonalityType // Add the joining user's personality type
            });

            return doc.id;
          }
        }

        // Create new group chat room if no suitable room found
        Map<String, dynamic> roomData = {
          "Participants": participants,
          "RoomType": "Group",
          "PersonalityCategory": criteria,
          "SelectedCriteria": selectedCriteria,
          "CreatedAt": FieldValue.serverTimestamp(),
          "IsEmpty": false,
          "IsFull": false,
          "MaxParticipants": 4,
          "TargetPersonalityTypes":
              targetPersonalities, // Array of target personality types
          "UserPersonalityType": finalUserPersonalityType,
          "ParticipantNames": {
            participants[0]:
                (userDoc.data() as Map<String, dynamic>)["UserID"] ??
                    "Anonymous"
          },
          "ParticipantTypes": {participants[0]: finalUserPersonalityType}
        };

        print(
            "🏗️ Creating new group chat room with target personalities: $targetPersonalities");
        DocumentReference newRoom =
            await _firestore.collection("starrymatch_chatroom").add(roomData);

        // Mark user as in chatroom
        await _firestore
            .collection("starrymatch_user")
            .doc(participants[0])
            .update({"IsInChatroom": true});

        return newRoom.id;
      }

      // Matching by personality if a target personality type is provided
      if (personalityType != null && personalityType.isNotEmpty) {
        String targetPersonalityType =
            personalityType; // This is the selected/target personality

        // Make sure we have the correct user personality type
        if (finalUserPersonalityType.isEmpty) {
          if (criteria == "MBTI") {
            finalUserPersonalityType =
                (userDoc.data() as Map<String, dynamic>)["MBTITypes"] ?? "";
          } else if (criteria == "Enneagram") {
            finalUserPersonalityType =
                (userDoc.data() as Map<String, dynamic>)["EnneagramTypes"] ??
                    "";
          }
        }

        print(
            "✅ User wants to match: Their type=$finalUserPersonalityType, Looking for=$targetPersonalityType");

        // NEW APPROACH: Two-step matching process

        // STEP 1: Try to find a waiting room where:
        // - The creator is looking for OUR personality type (userPersonalityType)
        // - The creator's personality type matches what WE are looking for (targetPersonalityType)
        // - The selected criteria match (age and interest)
        print(
            "🔎 STEP 1: Looking for room where creator is waiting for our type");
        QuerySnapshot matchingRooms = await _firestore
            .collection("starrymatch_chatroom")
            .where("IsEmpty", isEqualTo: true)
            .where("RoomType", isEqualTo: chatType)
            .where("TargetPersonalityType", isEqualTo: targetPersonalityType)
            .get();

        print(
            "🔍 Found ${matchingRooms.docs.length} empty rooms of type $chatType");

        // Split our selected criteria for comparison
        List<String> ourCriteria =
            selectedCriteria.split(',').where((s) => s.isNotEmpty).toList();
        ourCriteria.sort(); // Sort for consistent comparison

        // Manually filter for exact personality type match AND criteria match
        DocumentSnapshot? matchingRoom;
        for (var doc in matchingRooms.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          String roomTargetType = data["TargetPersonalityType"] ?? "";
          String roomUserType = data["UserPersonalityType"] ?? "";
          String roomCriteria = data["SelectedCriteria"] ?? "";

          // Split and sort room's criteria for comparison
          List<String> roomCriteriaList =
              roomCriteria.split(',').where((s) => s.isNotEmpty).toList();
          roomCriteriaList.sort();

          // Check if criteria match using the equivalence system
          bool criteriaMatch =
              _doCriteriaListsMatch(ourCriteria, roomCriteriaList);

          // Perfect match: Room creator wants our type AND room creator's type is what we want AND criteria match
          // Special case for Neutral match type: less strict matching
          bool isMatch = false;
          
          if (isNeutralMatch) {
            // For Neutral matchType, we're less strict - just need the criteria to match
            // We don't strictly check personality types when the match is "Neutral"
            print("🧪 NEUTRAL MATCHING LOGIC - Using less strict requirements");
            isMatch = criteriaMatch;
          } else {
            // Normal case - strict personality matching
            isMatch = data["TargetPersonalityType"] == finalUserPersonalityType &&
                     data["UserPersonalityType"] == targetPersonalityType &&
                     criteriaMatch;
          }
          
          if (isMatch) {
            print("✅ FOUND MATCHING ROOM! Joining...");
            List<dynamic> currentParticipants =
                (data["Participants"] as List<dynamic>?) ?? [];

            // Add user to participants if not already there
            if (!currentParticipants.contains(participants[0])) {
              currentParticipants.add(participants[0]);
            }
            
            // Update the room
            await _firestore
                .collection("starrymatch_chatroom")
                .doc(doc.id)
                .update({
              "Participants": currentParticipants,
              "IsEmpty": false,
              "OtherUserPersonalityType":
                  finalUserPersonalityType // Add the joining user's personality type
            });

            return doc.id;
          }
        }

        // STEP 2: No match found, create a new waiting room
        print("🏗️ STEP 2: No match found, creating new waiting room");

        Map<String, dynamic> roomData = {
          "Participants": participants,
          "RoomType": chatType,
          "PersonalityCategory": criteria,
          "SelectedCriteria": selectedCriteria,
          "CreatedAt": FieldValue.serverTimestamp(),
          "IsEmpty": true, // This is a waiting room
          "TargetPersonalityType":
              targetPersonalityType, // The personality type we want to match with
          "UserPersonalityType":
              finalUserPersonalityType, // The current user's personality type
          "OtherUserPersonalityType":
              null // Will be set when another user joins
        };

        print("🏗️ CREATING NEW WAITING ROOM with data: $roomData");

        DocumentReference newRoom =
            await _firestore.collection("starrymatch_chatroom").add(roomData);
        String newRoomId = newRoom.id;

        print("✅ SUCCESSFULLY created new waiting room: $newRoomId");
        print("   - We are: $finalUserPersonalityType");
        print("   - We want: $targetPersonalityType");
        print("   - Our criteria: $ourCriteria");

        return newRoomId;
      }

      // This part only executes if not matching by personality

      // Create new chatroom (standard)
      Map<String, dynamic> roomData = {
        "Participants": participants,
        "RoomType": chatType,
        "PersonalityCategory": criteria,
        "SelectedCriteria": selectedCriteria,
        "CreatedAt": FieldValue.serverTimestamp(),
        "IsEmpty": participants.length == 1,
        "TargetPersonalityType": personalityType,
        "UserPersonalityType": finalUserPersonalityType,
        "OtherUserPersonalityType": null
      };

      print("🏗️ CREATING STANDARD ROOM with data: $roomData");

      try {
        DocumentReference newRoom =
            await _firestore.collection("starrymatch_chatroom").add(roomData);
        String newRoomId = newRoom.id;
        print("✅ SUCCESSFULLY created standard room: $newRoomId");

        // Verify room was created correctly
        DocumentSnapshot verifyRoom = await _firestore
            .collection("starrymatch_chatroom")
            .doc(newRoomId)
            .get();
        if (verifyRoom.exists) {
          Map<String, dynamic> verifyData =
              verifyRoom.data() as Map<String, dynamic>;
          print("✓ VERIFICATION: Standard room exists with data: $verifyData");
        } else {
          print("❌ CRITICAL ERROR: Standard room was not created properly!");
        }

        return newRoomId;
      } catch (roomError) {
        print("❌ CRITICAL ERROR creating standard room: $roomError");
        rethrow;
      }
    } catch (e) {
      print("❌ CRITICAL ERROR in getOrCreateChatRoom: $e");
      rethrow;
    }
  }

  // Find a chatroom with a matching personality type
  // WARNING: This function is deprecated. Use getOrCreateChatRoom instead.
  Future<String?> findRoomByPersonalityType(
      String userId,
      String targetPersonalityType,
      String userPersonalityType,
      String chatType) async {
    print(
        "⚠️ WARNING: findRoomByPersonalityType is deprecated. Use getOrCreateChatRoom instead.");
    return null;
  }

  Future<void> deleteChatRoomAndMessages(String roomId) async {
    try {
      print("🗑️ Starting deletion of chatroom: $roomId");

      // First, get the chatroom document to check participants
      DocumentSnapshot chatroomDoc =
          await _firestore.collection('starrymatch_chatroom').doc(roomId).get();

      if (!chatroomDoc.exists) {
        print("⚠️ Chatroom $roomId does not exist");
        return;
      }

      // Get participants before deletion
      List<dynamic> participants = chatroomDoc["Participants"] ?? [];

      // Create a batch for all operations
      final batch = _firestore.batch();

      // Delete all messages in the chatroom
      final messagesSnapshot = await _firestore
          .collection('starrymatch_chatroom')
          .doc(roomId)
          .collection('messages')
          .get();

      for (var doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete the chatroom document
      final chatroomRef =
          _firestore.collection('starrymatch_chatroom').doc(roomId);
      batch.delete(chatroomRef);

      // Update IsInChatroom status for all participants
      for (var participantId in participants) {
        final userRef =
            _firestore.collection('starrymatch_user').doc(participantId);
        batch.update(userRef, {'IsInChatroom': false});
      }

      // Commit all operations
      await batch.commit();
      print("✅ Successfully deleted chatroom $roomId and all its messages");
    } catch (e) {
      print("❌ Error deleting chatroom $roomId: $e");
      rethrow;
    }
  }

  Stream<List<Message>> getMessages(String roomId) {
    // Print the roomId for debugging
    print("🔍 DEBUG - getMessages roomId: $roomId");
    
    // Use the same improved detection logic as sendMessage
    bool isFriendRoom = roomId.startsWith("friend_") || roomId.contains("_friend_");
    
    print("🔍 DEBUG - getMessages isFriendRoom: $isFriendRoom");
    
    // Get the collection name based on the room type
    String collection = isFriendRoom ? 'starrymatch_friend_chatroom' : 'starrymatch_chatroom';
    
    print("🔍 DEBUG - getMessages using collection: $collection");
    
    return FirebaseFirestore.instance
        .collection(collection)
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Message.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> sendMessage(String roomId, String senderId, String text) async {
    try {
      final timestamp = Timestamp.now();
      
      final message = Message(
        id: '', // Firestore will generate this
        text: text,
        senderId: senderId,
        timestamp: timestamp,
      );

      // Print the roomId for debugging
      print("🔍 DEBUG - sendMessage roomId: $roomId");
      
      // Check if this is a friend chatroom (more precise check)
      bool isFriendRoom = roomId.startsWith("friend_") || roomId.contains("_friend_");
      
      print("🔍 DEBUG - isFriendRoom: $isFriendRoom");
      
      final roomCollection = isFriendRoom
          ? "starrymatch_friend_chatroom"
          : "starrymatch_chatroom";
      
      print("🔍 DEBUG - using collection: $roomCollection");
      
      // Check if the document exists before proceeding
      final docSnapshot = await FirebaseFirestore.instance
          .collection(roomCollection)
          .doc(roomId)
          .get();
          
      if (!docSnapshot.exists) {
        print("❌ Error: Chatroom document $roomId does not exist in collection $roomCollection");
        
        // If it's not found in the first collection, try the other one
        final alternativeCollection = isFriendRoom 
            ? "starrymatch_chatroom" 
            : "starrymatch_friend_chatroom";
            
        print("🔄 Retrying with alternative collection: $alternativeCollection");
        
        final altDocSnapshot = await FirebaseFirestore.instance
            .collection(alternativeCollection)
            .doc(roomId)
            .get();
            
        if (!altDocSnapshot.exists) {
          print("❌ Error: Chatroom document $roomId does not exist in either collection");
          return;
        }
        
        // If found in alternative collection, update our variables
        isFriendRoom = !isFriendRoom;
        print("✅ Found document in alternative collection. isFriendRoom updated to: $isFriendRoom");
      }
      
      // 1. Add message to collection first
      final messageCollection = isFriendRoom
          ? "starrymatch_friend_chatroom"
          : "starrymatch_chatroom";
          
      await FirebaseFirestore.instance
          .collection(messageCollection)
          .doc(roomId)
          .collection('messages')
          .add(message.toMap());
      
      // 2. Update lastMessage field in the chatroom document
      if (isFriendRoom) {
        // For friend chatroom - use camelCase keys
        await FirebaseFirestore.instance
            .collection(messageCollection)
            .doc(roomId)
            .update({
              'lastMessage': text,
              'lastMessageTime': timestamp,
            });
      } else {
        // For regular chatroom - use PascalCase keys
        await FirebaseFirestore.instance
            .collection(messageCollection)
            .doc(roomId)
            .update({
              'LastMessage': text,
              'LastMessageTime': timestamp,
            });
      }
      
      print("✅ Message sent and lastMessage updated successfully");
    } catch (error) {
      print("❌ Error in sendMessage: $error");
    }
  }

  // Add method to handle user leaving any type of chat room (private or group)
  Future<String> leaveChatroom(String roomId, String userId) async {
    try {
      // ถ้าห้องเป็น friend chatroom ให้ทำแค่ลบ typing status แต่ไม่ลบห้อง
      if (roomId.contains('friend_')) {
        debugPrint("📝 Friend chatroom $roomId - only clearing typing status");
        try {
          await _firestore
              .collection("starrymatch_friend_chatroom")
              .doc(roomId)
              .collection('typing')
              .doc(userId)
              .delete();
          
          // อัพเดทสถานะผู้ใช้
          await _firestore
              .collection("starrymatch_user")
              .doc(userId)
              .update({"IsInChatroom": false});
              
          return userId;
        } catch (e) {
          debugPrint("❌ Error clearing typing in friend chatroom: $e");
          return userId;
        }
      }

      final chatroomRef = _firestore.collection("starrymatch_chatroom").doc(roomId);
      final chatHistoryRef = _firestore.collection("starrymatch_chat_history").doc(roomId);

      // ✅ Fetch chatroom data
      DocumentSnapshot chatroomSnapshot = await chatroomRef.get();
      
      if (!chatroomSnapshot.exists) {
        debugPrint("❌ Chatroom does not exist: $roomId");
        return "No one";
      }
      
      Map<String, dynamic>? chatroomData = chatroomSnapshot.data() as Map<String, dynamic>?;

      // ✅ Get current participants and history
      List<dynamic> currentParticipants = chatroomData?["Participants"] ?? [];
      List<dynamic> participantsHistory = chatroomData?["ParticipantsHistory"] ?? [];
          
      // Make sure ParticipantsHistory exists and includes all current participants
      if (participantsHistory.isEmpty) {
        participantsHistory = List.from(currentParticipants);
      } else {
        // Add any current participants who are not in history
        for (var participant in currentParticipants) {
          if (!participantsHistory.contains(participant)) {
            participantsHistory.add(participant);
          }
        }
      }

      // ✅ Find other participant before removing current user
      String otherUserId = "No one";
      for (var participant in currentParticipants) {
        if (participant != userId && participant != "No one") {
          otherUserId = participant;
          break;
        }
      }
      
      debugPrint("ℹ️ Current participants: $currentParticipants");
      debugPrint("ℹ️ Other user ID: $otherUserId");

      // ✅ Add to history if not already there
      if (!participantsHistory.contains(userId)) {
        participantsHistory.add(userId);
      }
      if (otherUserId != "No one" && !participantsHistory.contains(otherUserId)) {
        participantsHistory.add(otherUserId);
      }

      // ✅ Find last participant that is not the current user
      String lastParticipant = "No one";
      if (otherUserId != "No one") {
        lastParticipant = otherUserId;
      } else {
        // Try to find from history
        for (var participant in participantsHistory.reversed) {
          if (participant != userId && participant != "No one") {
            lastParticipant = participant;
            break;
          }
        }
      }

      // ✅ Remove user from participants
      currentParticipants.remove(userId);
      
      // ✅ Remove "No one" placeholder if there are real users
      currentParticipants.remove("No one");
      
      // ตรวจสอบว่าห้องว่างหรือไม่
      bool roomIsEmpty = currentParticipants.isEmpty;
      
      debugPrint("ℹ️ After removal - participants: $currentParticipants, isEmpty: $roomIsEmpty");

      // ✅ Update user's status
      await _firestore
          .collection("starrymatch_user")
          .doc(userId)
          .update({"IsInChatroom": false});

      // ✅ ถ้าเหลือคนอื่นอยู่ในห้อง
      if (!roomIsEmpty) {
        // Always update participants history
        await chatroomRef.update({
          "Participants": currentParticipants,
          "ParticipantsHistory": participantsHistory,
          "IsEmpty": false
        });

        debugPrint("✅ Updated room $roomId with remaining users");
        return otherUserId;
      } else {
        // ห้องว่าง (ไม่มีผู้ใช้จริงเหลืออยู่)
        // If the room is now empty, we'll add "No one" as placeholder
        currentParticipants = ["No one"];
        
        // ✅ If no one remains, create chat history before deleting room
        debugPrint("🗑️ No one left in room $roomId - saving history and deleting room");
        
        if (!await chatHistoryRef.get().then((doc) => doc.exists)) {
          await chatHistoryRef.set({
            "Participants": participantsHistory,
            "ParticipantsHistory": participantsHistory,
            "RoomType": chatroomData?["RoomType"],
            "PersonalityCategory": chatroomData?["PersonalityCategory"],
            "CreatedAt": chatroomData?["CreatedAt"],
            "LastParticipant": lastParticipant,
          });
          debugPrint("✅ Created history record for room $roomId");
        } else {
          await chatHistoryRef.update({
            "Participants": participantsHistory,
            "ParticipantsHistory": participantsHistory,
            "LastParticipant": lastParticipant,
          });
          debugPrint("✅ Updated history record for room $roomId");
        }

        // Delete the room and its messages
        await deleteChatRoomAndMessages(roomId);
        debugPrint("✅ Successfully deleted empty room $roomId");
        
        return lastParticipant;
      }
    } catch (e) {
      debugPrint("❌ Error leaving chatroom: $e");
      rethrow;
    }
  }

  // Deprecated: Use leaveChatroom instead
  Future<void> leaveGroupChat(String roomId, String userId) async {
    print(
        "⚠️ Warning: leaveGroupChat is deprecated. Please use leaveChatroom instead.");
    await leaveChatroom(roomId, userId);
  }

  // Get message stream with a limit parameter to improve performance
  Stream<List<Message>> getMessagesWithLimit(String roomId, int limit) {
    // First, try to get from regular chatroom collection
    return _firestore
        .collection('starrymatch_chatroom')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .limitToLast(limit)
        .snapshots()
        .map((snapshot) {
      try {
        List<Message> messages = snapshot.docs
            .map((doc) => Message.fromMap(doc.data(), doc.id))
            .toList();
        
        // If we got messages, return them
        if (messages.isNotEmpty) {
          return messages;
        }
        
        // If no messages, we'll return an empty list and let the UI handle it
        return <Message>[];
      } catch (e) {
        debugPrint("❌ Error decoding messages: $e");
        // Return an empty list on error
        return <Message>[];
      }
    }).handleError((error) {
      // If there's an error (likely because the document doesn't exist in this collection),
      // try the friend chatroom collection instead
      return _firestore
          .collection('starrymatch_friend_chatroom')
          .doc(roomId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .limitToLast(limit)
          .snapshots()
          .map<List<Message>>((snapshot) {
        try {
          return snapshot.docs
              .map((doc) => Message.fromMap(doc.data(), doc.id))
              .toList();
        } catch (e) {
          debugPrint("❌ Error decoding friend messages: $e");
          return <Message>[];
        }
      });
    });
  }

  // Get username for a user ID
  Future<String> getUserName(String userId) async {
    try {
      final doc = await _firestore
          .collection("starrymatch_user")
          .doc(userId)
          .get();

      if (doc.exists) {
        // First try to get the anonymous username
        final anonymousName = doc.data()?["AnnonymousUsername"];
        if (anonymousName != null) {
          return anonymousName.toString();
        }
        
        // Fall back to UserID if AnonymousUsername is not available
        final userID = doc.data()?["UserID"];
        if (userID != null) {
          return userID.toString();
        }
      }
      
      // Default fallback
      return "Unknown";
    } catch (e) {
      debugPrint("❌ Error fetching user name: $e");
      return "Unknown";
    }
  }
}
