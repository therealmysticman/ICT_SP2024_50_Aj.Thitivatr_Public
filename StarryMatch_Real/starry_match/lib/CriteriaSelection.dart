import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:starry_match/theme/AppThemeExtension.dart';
import 'Chatroom.dart';
import '../services/chat_services.dart';
import 'package:starry_match/localization/app_localizations.dart';

class CriteriaSelectionPage extends StatefulWidget {
  final String userPersonalityType;
  final String selectedPersonality;
  final String matchType;
  final String userId;
  final String chatType;
  final String personalityCategory;

  const CriteriaSelectionPage({
    super.key,
    required this.userPersonalityType,
    required this.selectedPersonality,
    required this.matchType,
    required this.userId,
    required this.chatType,
    required this.personalityCategory,
  });

  @override
  _CriteriaSelectionPageState createState() => _CriteriaSelectionPageState();
}

class _CriteriaSelectionPageState extends State<CriteriaSelectionPage> {
  String? selectedAgeGroup;
  String? selectedInterest;
  List<String> ageGroups = [];
  List<String> interests = [];

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
    return list1.every((item1) => 
      list2.any((item2) => _areCriteriaEquivalent(item1, item2))
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        ageGroups = [
          AppLocalizations.of(context)!.translate("age_highschool"),
          AppLocalizations.of(context)!.translate("age_university"),
          AppLocalizations.of(context)!.translate("age_working"),
        ];
        interests = [
          AppLocalizations.of(context)!.translate("interest_anime"),
          AppLocalizations.of(context)!.translate("interest_movies"),
          AppLocalizations.of(context)!.translate("interest_music"),
          AppLocalizations.of(context)!.translate("interest_travel"),
          AppLocalizations.of(context)!.translate("interest_deeptalk"),
          AppLocalizations.of(context)!.translate("interest_study"),
          AppLocalizations.of(context)!.translate("interest_games"),
          AppLocalizations.of(context)!.translate("interest_art"),
          AppLocalizations.of(context)!.translate("interest_food"),
          AppLocalizations.of(context)!.translate("interest_work"),
          AppLocalizations.of(context)!.translate("interest_technology"),
          AppLocalizations.of(context)!.translate("interest_sports"),
        ];
      });
    });
  }

  void toggleSelection(String category, String value) {
    setState(() {
      if (category == "age_group") {
        selectedAgeGroup = (selectedAgeGroup == value) ? null : value;
      } else if (category == "interest") {
        selectedInterest = (selectedInterest == value) ? null : value;
      }
    });
  }

  Widget _buildCategory(String title, List<String> options, String? selectedOption) {
    // Calculate grid layout based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth = (screenWidth - 50) / 3; // 3 buttons per row with margins
    final buttonHeight = 40.0; // Fixed button height
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.translate(title),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black45, blurRadius: 3, offset: Offset(1, 1))],
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, // Fixed 3 buttons per row
            childAspectRatio: buttonWidth / buttonHeight, // Calculate aspect ratio from width/height
            crossAxisSpacing: 8, // Spacing between buttons horizontally
            mainAxisSpacing: 8, // Spacing between buttons vertically
          ),
          itemCount: options.length,
          itemBuilder: (context, index) {
            final option = options[index];
            bool isSelected = selectedOption == option;
            return GestureDetector(
              onTap: () => toggleSelection(title, option),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? const Color.fromARGB(255, 255, 210, 113) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))],
                ),
                child: Center(
                  child: Text(
                    option,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // Debug method for personality matchType
  void _debugPersonalityMatchType() {
    if (widget.matchType != null && widget.matchType!.isNotEmpty) {
      debugPrint("🔍 MatchType Analysis:");
      debugPrint("   - matchType: ${widget.matchType}");
      debugPrint("   - userPersonalityType: ${widget.userPersonalityType}");
      debugPrint("   - selectedPersonality: ${widget.selectedPersonality}");
      
      // Check for Neutral matchType specifically
      if (widget.matchType == "Neutral") {
        debugPrint("⚠️ NEUTRAL MATCH TYPE DETECTED - Special handling needed!");
      }
    }
  }

  void _createChatRoomAndNavigate() async {
    // Debug the personality matching
    _debugPersonalityMatchType();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    List<String> selectedCriteria = [];
    if (selectedInterest != null) selectedCriteria.add(selectedInterest!);
    if (widget.chatType == "Private" && selectedAgeGroup != null) {
      selectedCriteria.add(selectedAgeGroup!);
    }

    try {
      // CRITICAL DEBUG - เพิ่มการตรวจสอบข้อมูลก่อนสร้างห้อง
      print("🚨🚨🚨 CREATING CHATROOM - INITIAL PARAMS:");
      print("🚨 User ID: ${widget.userId}");
      print("🚨 Chat Type: ${widget.chatType}");
      print("🚨 User Personality Type: ${widget.userPersonalityType}");
      print("🚨 Selected Personality: ${widget.selectedPersonality}");
      print("🚨 Match Type: ${widget.matchType}");
      print("🚨 Selected Criteria: $selectedCriteria");
      
      String matchedUserId = "";

      // Load the user's personality data to match by type
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection("starrymatch_user")
          .doc(widget.userId)
          .get();
          
      if (!userDoc.exists) {
        throw Exception("User document not found");
      }
      
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      String personalityType = "";
      
      // Set personality type correctly based on the matching method
      if (widget.selectedPersonality.isNotEmpty) {
        // If there's a selectedPersonality, use it for matching regardless of matchType
        personalityType = widget.selectedPersonality;
        print("📱 Using selected personality for matching: $personalityType");
      } else if (widget.userPersonalityType == "MBTI") {
        // Regular method to get user's own MBTI
        personalityType = userData["MBTITypes"] ?? "";
      } else if (widget.userPersonalityType == "Enneagram") {
        // Regular method to get user's own Enneagram
        personalityType = userData["EnneagramTypes"] ?? "";
      }
      
      // Only proceed with personality matching if a type is set
      bool hasPersonalityType = personalityType.isNotEmpty && personalityType != "Not set";
      
      // Check if this is a personality-based matching
      // Case 1: Explicitly matching by personality (matchType == "Personality")
      // Case 2: Using matchType "Neutral" but with a specific selectedPersonality
      bool isPersonalityMatching = widget.matchType == "Personality" || 
           (widget.matchType == "Neutral" && widget.selectedPersonality.isNotEmpty);
      
      print("📱 Personality type: $personalityType");
      print("📱 Is personality matching: $isPersonalityMatching");
      print("📱 Has personality type: $hasPersonalityType");
      print("📱 User personality type: ${widget.userPersonalityType}");
      print("📱 Match type: ${widget.matchType}");
      print("📱 Selected personality: ${widget.selectedPersonality}");
      
      // CASE 1: If we're matching by personality and user has a valid personality type
      if (isPersonalityMatching && hasPersonalityType) {
        print("✅ Looking for ${widget.userPersonalityType} type: $personalityType");
        print("🔍 DEBUG: selectedPersonality=${widget.selectedPersonality}, userPersonalityType=${widget.userPersonalityType}");
        
        // Special case for "Neutral" matchType - needs less strict matching
        bool isNeutralMatch = widget.matchType == "Neutral";
        if (isNeutralMatch) {
          debugPrint("⚠️ Using less strict matching for Neutral personalities");
          
          // If this is a Neutral matchType, explicitly search for rooms with Type2 personalities or same type
          String targetPersonalityType = widget.selectedPersonality.isNotEmpty ? widget.selectedPersonality : widget.userPersonalityType;
          
          // Run a query to find ANY room with this personality type
          final firestore = FirebaseFirestore.instance;
          QuerySnapshot potentialRooms = await firestore
              .collection("starrymatch_chatroom")
              .where("IsEmpty", isEqualTo: true)
              .where("RoomType", isEqualTo: widget.chatType)
              .where("UserPersonalityType", isEqualTo: targetPersonalityType)
              .limit(5)
              .get();
          
          if (potentialRooms.docs.isNotEmpty) {
            debugPrint("✅ For NEUTRAL match: Found ${potentialRooms.docs.length} potential rooms with personality type ${targetPersonalityType}");
            
            // Try to join the first suitable room
            String roomId = potentialRooms.docs.first.id;
            Map<String, dynamic> roomData = potentialRooms.docs.first.data() as Map<String, dynamic>;
            
            // Join this room
            List<dynamic> participants = roomData["Participants"] ?? [];
            if (!participants.contains(widget.userId)) {
              participants.add(widget.userId);
            }
            
            // Update room data
            await firestore
                .collection("starrymatch_chatroom")
                .doc(roomId)
                .update({
              "Participants": participants,
              "IsEmpty": false,
              "OtherUserPersonalityType": widget.userPersonalityType,
            });
            
            // Mark user as in chatroom
            await firestore.collection("starrymatch_user").doc(widget.userId).update({
              "IsInChatroom": true
            });
            
            Navigator.pop(context); // Close loading dialog
            
            // Navigate to chatroom with the other user
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatRoomPage(
                  roomId: roomId,
                  userId: widget.userId,
                  otherUserId: participants.firstWhere((id) => id != widget.userId, orElse: () => "Waiting..."),
                  roomType: widget.chatType,
                  criteria: widget.personalityCategory,
                  selectedCriteria: selectedCriteria.join(","),
                  userPersonalityType: widget.userPersonalityType,
                  selectedPersonality: widget.selectedPersonality,
                ),
              ),
            );
            return;
          } else {
            debugPrint("⚠️ No NEUTRAL match rooms found, proceeding with normal flow");
          }
        }
        
        // CRITICAL FIX: If we have a selected personality from recommendation, use that as the type to match with
        // หมายความว่า หากเราเป็น ENFP เลือกคุยกับ ESTP จะต้องสร้างห้องที่มี TargetPersonalityType = "ESTP" และ UserPersonalityType = "ENFP"
        String targetPersonalityType = widget.selectedPersonality.isNotEmpty ? widget.selectedPersonality : personalityType;
        String userPersonalityType = widget.userPersonalityType; // Use the actual user personality type
        
        print("🔑 Setting targetPersonalityType=$targetPersonalityType (ต้องการคุยกับใคร)");
        print("🔑 Setting userPersonalityType=$userPersonalityType (เราเป็นใคร)");
        
        // Use the ChatService to handle personality matching
        String newRoomId = await ChatService().getOrCreateChatRoom(
          [widget.userId],
          widget.chatType,
          widget.personalityCategory,
          selectedCriteria.join(","),
          personalityType: targetPersonalityType,
          matchByPersonality: true,
          matchType: widget.matchType // Pass the matchType to the chat service
        );
        
        // Debug logs
        print("🏛️ Creating/joining personality room - ID: $newRoomId, Target: $targetPersonalityType, User: $userPersonalityType");
        
        // Always check if PersonalityType exists and fix it if needed
        DocumentSnapshot createdRoom = await FirebaseFirestore.instance
            .collection("starrymatch_chatroom")
            .doc(newRoomId)
            .get();
            
        if (createdRoom.exists) {
          // Force update the room's personality fields
          await FirebaseFirestore.instance
              .collection("starrymatch_chatroom")
              .doc(newRoomId)
              .update({
                "TargetPersonalityType": targetPersonalityType,
                "UserPersonalityType": userPersonalityType
              });
          print("✅ Forced update of personality types - Target: $targetPersonalityType, User: $userPersonalityType");
        }
        
        // Get room info to check participants
        DocumentSnapshot roomDoc = await FirebaseFirestore.instance
            .collection("starrymatch_chatroom")
            .doc(newRoomId)
            .get();
            
        if (roomDoc.exists) {
          Map<String, dynamic> roomData = roomDoc.data() as Map<String, dynamic>;
          List<dynamic> participants = roomData["Participants"] ?? [];
          matchedUserId = participants.length > 1 
              ? participants.firstWhere((id) => id != widget.userId, orElse: () => "Waiting...") 
              : "Waiting...";
          
          // Mark as "in chatroom"
          await FirebaseFirestore.instance.collection("starrymatch_user").doc(widget.userId).update({
            "IsInChatroom": true
          });
          
          Navigator.pop(context); // Close loading dialog
          
          // Navigate to chatroom
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatRoomPage(
                roomId: newRoomId,
                userId: widget.userId,
                otherUserId: matchedUserId,
                roomType: widget.chatType,
                criteria: widget.personalityCategory,
                selectedCriteria: selectedCriteria.join(","),
                userPersonalityType: userPersonalityType,
                selectedPersonality: widget.selectedPersonality,
              ),
            ),
          );
          return;
        }
        
      } else {
        // CASE 2: Standard matching (not by personality)
        print("ℹ️ Using standard matching (not by personality)");
        
        // Always use the user's actual personality type and selected personality
        String userPersonalityType = widget.userPersonalityType;
        String targetPersonalityType = widget.selectedPersonality;
        print("🔑 Standard match - User personality type: $userPersonalityType");
        print("🔑 Standard match - Target personality type: $targetPersonalityType");
        
        // If we didn't find a matching room, check for any empty room
        QuerySnapshot emptyRooms = await FirebaseFirestore.instance
            .collection("starrymatch_chatroom")
            .where("IsEmpty", isEqualTo: true)
            .where("RoomType", isEqualTo: widget.chatType)
            .where("UserPersonalityType", isEqualTo: targetPersonalityType)
            .limit(1)
            .get();

        // Split our selected criteria for comparison
        List<String> ourCriteria = selectedCriteria;
        ourCriteria.sort(); // Sort for consistent comparison

        // Manually filter for criteria match
        DocumentSnapshot? matchingRoom;
        for (var doc in emptyRooms.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          String roomCriteria = data["SelectedCriteria"] ?? "";
          
          // Split and sort room's criteria for comparison
          List<String> roomCriteriaList = roomCriteria.split(',').where((s) => s.isNotEmpty).toList();
          roomCriteriaList.sort();
          
          print("📋 Checking empty room ${doc.id}:");
          print("   - Room criteria: $roomCriteriaList");
          print("   - Our criteria: $ourCriteria");
          
          // Check if criteria match using the equivalence system
          bool criteriaMatch = _doCriteriaListsMatch(ourCriteria, roomCriteriaList);
          
          if (criteriaMatch) {
            print("✅ FOUND MATCHING EMPTY ROOM: ${doc.id}");
            matchingRoom = doc;
            break;
          }
        }

       if (matchingRoom != null) {
  Map<String, dynamic> roomData = matchingRoom.data() as Map<String, dynamic>;
  List<dynamic> participants = roomData["Participants"] ?? [];
  
  // เพิ่ม user เข้าไปถ้ายังไม่อยู่
  if (!participants.contains(widget.userId)) {
    participants.add(widget.userId);
    
    Map<String, dynamic> updateData = {
      "Participants": participants,
      "IsEmpty": false
    };

    // ถ้ามี personalityType ให้ใส่ลงไป
    if (hasPersonalityType) {
      updateData["OtherUserPersonalityType"] = widget.userPersonalityType;
      print("🔑 Adding OtherUserPersonalityType=${widget.userPersonalityType} to existing room");
    }

    await FirebaseFirestore.instance
        .collection("starrymatch_chatroom")
        .doc(matchingRoom.id)
        .update(updateData);
  }

  matchedUserId = participants.firstWhere((id) => id != widget.userId, orElse: () => "Waiting...");

  // อัปเดตสถานะว่าอยู่ในห้อง
  await FirebaseFirestore.instance.collection("starrymatch_user").doc(widget.userId).update({
    "IsInChatroom": true
  });

  Navigator.pop(context);

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ChatRoomPage(
        roomId: matchingRoom!.id,
        userId: widget.userId,
        otherUserId: matchedUserId,
        roomType: widget.chatType,
        criteria: widget.personalityCategory,
        userPersonalityType: widget.userPersonalityType,
        selectedPersonality: widget.selectedPersonality,
        selectedCriteria: selectedCriteria.join(","),
      ),
    ),
  );
  return;
}
 else {
          // If we still haven't matched, create a new room
          List<String> participants = [widget.userId];

          // Check if we should create a room with personality matching
          bool createWithPersonality = isPersonalityMatching && hasPersonalityType;
          
          // ต้องใช้บุคลิกภาพที่เลือกเป็นค่า TargetPersonalityType ในห้อง
          String targetPersonalityType = widget.selectedPersonality.isNotEmpty ? widget.selectedPersonality : personalityType;
          String userPersonalityType = personalityType;
          print("🔑 Creating fallback room - Target: $targetPersonalityType, User: $userPersonalityType");
          
          // Create a new room - Always send both personality types
          String roomId = await ChatService().getOrCreateChatRoom(
            participants,
            widget.chatType,
            widget.personalityCategory,
            selectedCriteria.join(","),
            personalityType: targetPersonalityType,  // Use selected personality as target
            matchByPersonality: true  // Set to true to ensure personality types are used
          );
          
          print("⚠️ FORCED DEBUG - Created room ID: $roomId");
          print("⚠️ FORCED DEBUG - Parameters: Target=$targetPersonalityType, User=$userPersonalityType");
          
          // Log creation
          print("✅ Created new room: $roomId${createWithPersonality ? " with personality types - Target: $targetPersonalityType, User: $userPersonalityType" : ""}");
          
          // Force update personality types if we're doing personality matching
          if (createWithPersonality) {
            await FirebaseFirestore.instance
                .collection("starrymatch_chatroom")
                .doc(roomId)
                .update({
                  "TargetPersonalityType": targetPersonalityType,
                  "UserPersonalityType": userPersonalityType
                });
            print("✅ Forced update of personality types - Target: $targetPersonalityType, User: $userPersonalityType");
          }

          Navigator.pop(context);

          // Mark as "in chatroom"
          await FirebaseFirestore.instance.collection("starrymatch_user").doc(widget.userId).update({
              "IsInChatroom": true
          });

          // Navigate to the empty chatroom
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatRoomPage(
                roomId: roomId,
                userId: widget.userId,
                otherUserId: "Waiting...",
                roomType: widget.chatType,
                criteria: createWithPersonality ? targetPersonalityType : widget.personalityCategory,
                userPersonalityType: userPersonalityType,
                selectedPersonality: widget.selectedPersonality,
                selectedCriteria: selectedCriteria.join(","),
              ),
            ),
          );
          return;
        }
      }

      // In case we somehow reach here without navigating
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find or create a suitable chatroom')),
      );

    } catch (e) {
      Navigator.pop(context);
      print("❌ Error finding users or creating chatroom: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeExt = Theme.of(context).extension<AppThemeExtension>();
    final bgImage = themeExt?.bgCriteria ?? 'assets/bg_pastel_criteria.jpg';
    // Get screen size for responsive design
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(AppLocalizations.of(context)!.translate("criteria_selection"), style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(bgImage),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Main content with scrolling
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF9C4), // Light yellow from screenshot
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 2,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.translate("criteria_description"),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14, 
                              fontWeight: FontWeight.w500, 
                              color: Colors.black87
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (widget.chatType == "Private") ...[
                          _buildCategory("age_group", ageGroups, selectedAgeGroup),
                          const SizedBox(height: 20),
                        ],
                        _buildCategory("interest", interests, selectedInterest),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
              // Fixed bottom button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: selectedInterest != null ? _createChatRoomAndNavigate : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedInterest != null
                          ? Theme.of(context).colorScheme.primary // Purple color from screenshot
                          : Colors.grey,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.translate("go_button"),
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimary),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
