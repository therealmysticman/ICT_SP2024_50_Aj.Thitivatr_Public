import 'package:flutter/material.dart';
import 'package:starry_match/theme/AppThemeExtension.dart';
import 'home.dart'; // ✅ Import Home Page
import 'services/endorsement_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:starry_match/localization/app_localizations.dart';
import 'package:starry_match/services/notification_service.dart';

class UserListPage extends StatefulWidget {
  final String userId; // ✅ Keep userId
  final String otherUserId;
  final bool isHistory; // ✅ Declare isHistory
  final List<dynamic> allParticipants; // List of all participants from the chat

  const UserListPage({
    super.key,
      required this.userId,
    required this.otherUserId,
    required this.isHistory,
    this.allParticipants = const [], // Default to empty list
  });

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  final EndorsementService _endorsementService = EndorsementService();
  final NotificationService _notificationService = NotificationService();
  bool _isLoading = false;
  int _userPlasma = 0;
  Map<String, dynamic> _otherUserData = {};
  bool _isLoadingUserData = true;
  List<Map<String, dynamic>> _groupParticipants = [];
  bool _isGroupChat = false;

  @override
  void initState() {
    super.initState();
    _loadUserPlasma();
    _loadParticipantsFromRoom();
    
    // Fix any inconsistent friend relationships
    if (widget.otherUserId.isNotEmpty) {
      _fixFriendshipIfNeeded();
    }
  }

  Future<void> _loadParticipantsFromRoom() async {
    try {
      print("Searching for any chat room containing both users...");
      
      // First check if we have a chat room document ID (from ChatRoom page)
      String? chatRoomId;
      
      // Get rooms from both collections to find the most recent one containing both users
      List<DocumentSnapshot> allRooms = [];
      
      // Get chat history rooms
      QuerySnapshot chatHistories = await FirebaseFirestore.instance
          .collection('starrymatch_chat_history')
          .orderBy('CreatedAt', descending: true)
          .get();
          
      // Get active chatrooms
      QuerySnapshot activeRooms = await FirebaseFirestore.instance
          .collection('starrymatch_chatroom')
          .orderBy('CreatedAt', descending: true)
          .get();
      
      // Combine both collections, with active rooms first (they're more recent)
      allRooms.addAll(activeRooms.docs);
      allRooms.addAll(chatHistories.docs);
      
      print("Found ${allRooms.length} total rooms to check");
      
      // Find the first room containing both users
      DocumentSnapshot? matchingRoom;
      String? roomType;
      
      for (var room in allRooms) {
        Map<String, dynamic>? data = room.data() as Map<String, dynamic>?;
        if (data == null) continue;
        
        List<dynamic> participants = data['Participants'] ?? [];
        List<dynamic> participantsHistory = data['ParticipantsHistory'] ?? [];
        String thisRoomType = data['RoomType'] ?? 'Private';
        
        bool containsCurrentUser = participants.contains(widget.userId) || participantsHistory.contains(widget.userId);
        bool containsOtherUser = widget.otherUserId.isEmpty || 
                                participants.contains(widget.otherUserId) || 
                                participantsHistory.contains(widget.otherUserId);
        
        if (containsCurrentUser && containsOtherUser) {
          matchingRoom = room;
          roomType = thisRoomType;
          print("Found matching room: ${room.id}, type: $thisRoomType");
          break;
        }
      }
      
      // Process the matching room based on its type
      if (matchingRoom != null && roomType != null) {
          if (roomType == 'Group') {
          // Handle group chat
          print("Processing GROUP chat room: ${matchingRoom.id}");
          Map<String, dynamic> data = matchingRoom.data() as Map<String, dynamic>;
          List<dynamic> participants = data['Participants'] ?? [];
          List<dynamic> participantsHistory = data['ParticipantsHistory'] ?? [];
          
          // Combine participants from both lists
          Set<String> allParticipantIds = {...participants.cast<String>(), ...participantsHistory.cast<String>()};
          List<Map<String, dynamic>> groupParticipants = [];
          List<String> notFoundUsers = [];
          
          for (String participantId in allParticipantIds) {
            if (participantId == widget.userId) continue; // Skip current user
            if (participantId == "No one") continue; // Skip placeholder - don't localize DB constant
            
            try {
              DocumentSnapshot userDoc = await FirebaseFirestore.instance
                .collection('starrymatch_user')
                .doc(participantId)
                .get();
              
              if (userDoc.exists) {
                Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
                userData['UserID'] = userDoc.id;
                groupParticipants.add(userData);
                print("Added participant: ${userDoc.id} to group");
              } else {
                print("User $participantId not found in database");
                notFoundUsers.add(participantId);
              }
            } catch (e) {
              print("Error loading user $participantId: $e");
              notFoundUsers.add(participantId);
            }
          }
            
          if (mounted) {
            setState(() {
              _groupParticipants = groupParticipants;
              _isGroupChat = true;
              _isLoadingUserData = false;
            });
            
            // Show warning if some users were not found
            if (notFoundUsers.isNotEmpty && mounted) {
              // ใช้ ScaffoldMessenger เพื่อแสดงข้อความแจ้งเตือน
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("${notFoundUsers.length} ${AppLocalizations.of(context)!.translate("users_not_found")}"),
                    duration: const Duration(seconds: 3),
                  ),
                );
              });
            }
            
            return;
          }
        } else {
          // Handle private chat
          print("Processing PRIVATE chat room: ${matchingRoom.id}");
          // Load other user's data
          if (widget.otherUserId.isNotEmpty) {
            try {
              DocumentSnapshot userDoc = await FirebaseFirestore.instance
                .collection('starrymatch_user')
                .doc(widget.otherUserId)
                .get();
            
              if (userDoc.exists) {
                if (mounted) {
                  setState(() {
                    _otherUserData = userDoc.data() as Map<String, dynamic>;
                    // บังคับให้ UserID เป็น doc.id จริง เพื่อให้แน่ใจว่าการส่งคำขอเป็นเพื่อนใช้ ID ที่ถูกต้อง
                    _otherUserData['UserID'] = userDoc.id;
                    _isGroupChat = false;
                    _isLoadingUserData = false;
                  });
                }
                return;
              } else {
                print("User ${widget.otherUserId} not found");
                if (mounted) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.of(context)!.translate("user_not_found")),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  });
                }
              }
            } catch (e) {
              print("Error loading user ${widget.otherUserId}: $e");
            }
          }
        }
      }

      // If we get here, we didn't find a valid room or couldn't process it
      // Try to load the other user's data directly as a fallback
      print("No valid chat room found, loading user data directly");
      _loadOtherUserData();
    } catch (e) {
      print('Error loading participants: $e');
      _loadOtherUserData();
    }
  }

  Future<void> _loadOtherUserData() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('starrymatch_user')
          .doc(widget.otherUserId)
          .get();
      
      if (userDoc.exists) {
        setState(() {
          _otherUserData = userDoc.data() as Map<String, dynamic>;
          // บังคับให้ UserID เป็น doc.id จริง เพื่อให้แน่ใจว่าการส่งคำขอเป็นเพื่อนใช้ ID ที่ถูกต้อง
          _otherUserData['UserID'] = userDoc.id;
          _isLoadingUserData = false;
        });
      } else {
        // Handle the case when the other user doesn't exist
        setState(() {
          _isLoadingUserData = false;
        });
      }
    } catch (e) {
      print('Error loading other user data: $e');
      setState(() => _isLoadingUserData = false);
    }
  }

  Future<void> _loadUserPlasma() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('starrymatch_user')
          .doc(widget.userId)
          .get();
      
      if (userDoc.exists) {
        setState(() {
          _userPlasma = userDoc['StarryPlasma'] ?? 0;
        });
      }
    } catch (e) {
      print('Error loading user plasma: $e');
    }
  }

  Future<void> _handleEndorsement(int plasmaAmount) async {
    if (_userPlasma < plasmaAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough Starry Plasma')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('starrymatch_user')
          .doc(widget.userId)
          .update({
        'StarryPlasma': FieldValue.increment(-plasmaAmount),
      });

      await _endorsementService.addEndorsement(
        fromUserId: widget.userId,
        toUserId: widget.otherUserId,
        plasmaAmount: plasmaAmount,
      );

      // Get the current user's data to get the username
      DocumentSnapshot currentUserDoc = await FirebaseFirestore.instance
          .collection('starrymatch_user')
          .doc(widget.userId)
          .get();
      
      Map<String, dynamic> currentUserData = {};
      if (currentUserDoc.exists) {
        currentUserData = currentUserDoc.data() as Map<String, dynamic>;
      }
      
      String endorserName = currentUserData['AnnonymousUsername'] ?? 'A user';
      
      // Create notification for endorsement
      await _notificationService.createEndorsementNotification(
        userId: widget.otherUserId,
        endorserName: endorserName,
        skill: 'conversation', // You can customize this based on your app's context
      );

      setState(() {
        _userPlasma -= plasmaAmount;
      });
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Endorsement added successfully with $plasmaAmount Starry Plasma!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add endorsement')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAddFriend() async {
    try {
      await _sendFriendRequestTo(widget.otherUserId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.translate("friend_request_failed"))),
        );
      }
    }
  }

  Future<void> _fixFriendshipIfNeeded() async {
    try {
      await _notificationService.fixFriendshipConsistency(
        widget.userId, 
        widget.otherUserId
      );
    } catch (e) {
      print('Error fixing friendship consistency: $e');
    }
  }

  // ฟังก์ชันใหม่สำหรับส่งคำขอเป็นเพื่อนที่ใช้ targetUserId แทน widget.otherUserId
  Future<void> _sendFriendRequestTo(String targetUserId) async {
    try {
      print("👤 Sending friend request to: $targetUserId");
      
      // ตรวจสอบว่าผู้ใช้ที่ต้องการเพิ่มเป็นเพื่อนมีอยู่จริงก่อน
      DocumentSnapshot otherUserDoc = await FirebaseFirestore.instance
          .collection('starrymatch_user')
          .doc(targetUserId)
          .get();
          
      if (!otherUserDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("This user is no longer available")),
        );
        return;
      }
      
      // ตรวจสอบว่าตนเองมีอยู่ในฐานข้อมูล
      DocumentSnapshot currentUserDoc = await FirebaseFirestore.instance
          .collection('starrymatch_user')
          .doc(widget.userId)
          .get();
      
      if (!currentUserDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not retrieve your profile")),
        );
        return;
      }
          
      // ตรวจสอบสถานะคำขอเป็นเพื่อน
      Map<String, dynamic> requestStatus = await _notificationService.checkFriendRequestStatus(
        fromUserId: widget.userId,
        toUserId: targetUserId,
      );
      
      String status = requestStatus['status'] as String;
      print("🔄 Friend request status: $status");
      
      // จัดการกับสถานะต่างๆ
      if (status != 'ok') {
        String message;
        
        switch (status) {
          case 'already_friends':
            message = AppLocalizations.of(context)!.translate("already_friends");
            break;
          case 'request_exists':
            message = AppLocalizations.of(context)!.translate("friend_request_exists");
            break;
          case 'reverse_request_exists':
            message = AppLocalizations.of(context)!.translate("reverse_friend_request_exists");
            break;
          case 'error':
            message = "Could not process friend request. Please try again.";
            break;
          default:
            message = AppLocalizations.of(context)!.translate("error");
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        return;
      }
      
      // ทุกอย่างพร้อม - เพิ่มคำขอเป็นเพื่อน
      Map<String, dynamic> currentUserData = currentUserDoc.data() as Map<String, dynamic>;
      String senderName = currentUserData['AnnonymousUsername'] ?? 'A user';

      // อัปเดตรายการ pendingFriends ของผู้ใช้อื่น
      await FirebaseFirestore.instance
          .collection('starrymatch_user')
          .doc(targetUserId)
          .update({
        'pendingFriends': FieldValue.arrayUnion([widget.userId])
      });

      // ส่งการแจ้งเตือนคำขอเป็นเพื่อนโดยตรง
      await _notificationService.sendDirectFriendRequest(
        fromUserId: widget.userId,
        toUserId: targetUserId,
        senderName: senderName,
      );

      print("✅ Successfully sent friend request to: $targetUserId");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.translate("friend_request_sent"))),
      );
    } catch (e) {
      print("❌ Error sending friend request: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not send friend request")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeExt = Theme.of(context).extension<AppThemeExtension>();
    final bgImage = themeExt?.bgMain ?? 'assets/bg_pastel_main.jpg';
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final avatarSize = isSmallScreen ? 35.0 : 45.0;
    final fontSize = isSmallScreen ? 16.0 : 18.0;
    final padding = isSmallScreen ? 12.0 : 16.0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          _isGroupChat ? "Group Members" : AppLocalizations.of(context)!.translate("userlist_title"),
          style: TextStyle(
            color: const Color.fromARGB(255, 82, 82, 82),
            fontSize: isSmallScreen ? 18 : 20,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 246, 200, 94),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color.fromARGB(255, 82, 82, 82)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.exit_to_app,
              color: Color.fromARGB(255, 82, 82, 82),
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Colors.white.withOpacity(0.9),
                  title: Text(
                    AppLocalizations.of(context)!.translate("leave_room"),
                    style: const TextStyle(
                      color: Color.fromARGB(255, 73, 34, 117),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: Text(
                    AppLocalizations.of(context)!.translate("leave_room_confirmation"),
                    style: const TextStyle(
                      color: Color.fromARGB(255, 82, 82, 82),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        AppLocalizations.of(context)!.translate("cancel"),
                        style: const TextStyle(
                          color: Color.fromARGB(255, 147, 88, 164),
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HomePage(userId: widget.userId),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 147, 88, 164),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.translate("leave"),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              bgImage,
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: _isLoadingUserData
                ? const Center(child: CircularProgressIndicator())
                : _isGroupChat
                    ? _buildGroupParticipantsList()
                    : _buildSingleUserProfile(),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupParticipantsList() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final fontSize = isSmallScreen ? 16.0 : 18.0;
    final padding = isSmallScreen ? 12.0 : 16.0;

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Text(
                  AppLocalizations.of(context)!.translate("userlist_description").split('\n')[0],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: const [Shadow(color: Colors.black45, blurRadius: 3)],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.translate("userlist_description").split('\n')[1],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSize - 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "${AppLocalizations.of(context)!.translate("your_plasma_amount")}: $_userPlasma",
                  style: TextStyle(
                    fontSize: fontSize - 2,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    itemCount: _groupParticipants.length,
                    itemBuilder: (context, index) {
                      final participant = _groupParticipants[index];
                      final avatar = participant['UserAvatar'] ?? {};
                      final userId = participant['UserID'] ?? '';
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: EdgeInsets.all(padding),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 147, 88, 164).withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            _buildAvatar(avatar, size: 60),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    participant['AnnonymousUsername'] ?? 'Mystery User',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    participant['MBTITypes'] ?? "MBTI: Not set",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  Text(
                                    participant['EnneagramTypes'] ?? "Type: Not set",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  Text(
                                    AppLocalizations.of(context)!.translate("chat_partner"),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.person_add, color: Colors.white),
                                  onPressed: () async {
                                    try {
                                      await _sendFriendRequestTo(participant['UserID']);
                                      print("Sending friend request in group: ${participant['UserID']}");
                                    } catch (e) {
                                      print("Error sending friend request: $e");
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text("Could not send friend request")),
                                      );
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.star, color: Colors.amber),
                                  onPressed: () => _showEndorsementDialog(context),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(padding),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Colors.white.withOpacity(0.9),
                    title: Text(
                      AppLocalizations.of(context)!.translate("leave_room"),
                      style: const TextStyle(
                        color: Color.fromARGB(255, 73, 34, 117),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    content: Text(
                      AppLocalizations.of(context)!.translate("leave_room_confirmation"),
                      style: const TextStyle(
                        color: Color.fromARGB(255, 82, 82, 82),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          AppLocalizations.of(context)!.translate("cancel"),
                          style: const TextStyle(
                            color: Color.fromARGB(255, 147, 88, 164),
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HomePage(userId: widget.userId),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 147, 88, 164),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.translate("leave"),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.exit_to_app, color: Colors.white),
              label: Text(
                AppLocalizations.of(context)!.translate("return_home"),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 147, 88, 164),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(Map<String, dynamic> avatarMap, {double size = 50}) {
    bool isUserMissing = avatarMap.isEmpty || avatarMap["selectedSkin"] == null;
    
    // Check if user has enough endorsements for badge
    bool showEndorsementBadge = false;
    if (!isUserMissing) {
      int endorsementGet = 0;
      if (avatarMap.containsKey("EndorsementGet")) {
        endorsementGet = avatarMap["EndorsementGet"] is int 
            ? avatarMap["EndorsementGet"] 
            : int.tryParse(avatarMap["EndorsementGet"].toString()) ?? 0;
      }
      showEndorsementBadge = endorsementGet >= 200;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Image.asset(
          isUserMissing
              ? 'assets/Avatar/placeholder.png'
              : 'assets/Avatar/Skin/${avatarMap["selectedSkin"]}.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
        if (!isUserMissing && avatarMap["selectedHat"] != "")
          Positioned(
            child: Image.asset(
              'assets/Avatar/Decoration/Accessories/${avatarMap["selectedHat"]}.png',
              width: size,
            ),
          ),
        if (!isUserMissing && avatarMap["selectedClothes"] != "")
          Positioned(
            child: Image.asset(
              'assets/Avatar/Decoration/Clothing/${avatarMap["selectedClothes"]}.png',
              width: size,
            ),
          ),
        // Show endorsement badge if user has 200+ endorsements
        if (showEndorsementBadge)
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: () {
                // Create an OverlayEntry for the tooltip
                final overlay = Overlay.of(context);
                OverlayEntry? entry;
                
                // Calculate position of badge for tooltip placement
                final RenderBox box = context.findRenderObject() as RenderBox;
                final position = box.localToGlobal(Offset.zero);
                
                // Calculate the width of the tooltip for proper centering
                const tooltipWidth = 200.0;
                
                entry = OverlayEntry(
                  builder: (context) => Positioned(
                    // Position the tooltip centered above the badge
                    left: position.dx - (tooltipWidth / 2) + (size / 2),
                    top: position.dy - 80,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: tooltipWidth,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple[700],
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              AppLocalizations.of(context)?.translate("valuable_user_message") ??
                              "This user is valuable, feel free to talk with them!",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            // Small triangle pointing down
                            CustomPaint(
                              painter: _TrianglePainter(
                                color: Colors.purple[700]!,
                              ),
                              size: const Size(16, 8),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
                
                overlay.insert(entry!);
                
                // Remove the tooltip after a few seconds
                Future.delayed(const Duration(seconds: 2), () {
                  entry?.remove();
                });
              },
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  'assets/endorsement_badge.PNG',
                  width: size * 0.3,
                  height: size * 0.3,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSingleUserProfile() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final fontSize = isSmallScreen ? 16.0 : 18.0;
    final padding = isSmallScreen ? 12.0 : 16.0;
    final userAvatar = _otherUserData['UserAvatar'] ?? {};
    final anonymousUsername = _otherUserData['AnnonymousUsername'] ?? 'Anonymous User';
    
    if (_otherUserData.isEmpty) {
      return _buildNoUserView(screenSize, isSmallScreen, fontSize, padding);
    }

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Text(
                  AppLocalizations.of(context)!.translate("userlist_description").split('\n')[0],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: const [Shadow(color: Colors.black45, blurRadius: 3)],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.translate("userlist_description").split('\n')[1],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSize - 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "${AppLocalizations.of(context)!.translate("your_plasma_amount")}: $_userPlasma",
                  style: TextStyle(
                    fontSize: fontSize - 2,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: EdgeInsets.all(padding),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 147, 88, 164).withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildAvatar(userAvatar, size: 60),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              anonymousUsername,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              _otherUserData['MBTITypes'] ?? "MBTI: Not set",
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                            Text(
                              _otherUserData['EnneagramTypes'] ?? "Type: Not set",
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                            Text(
                              AppLocalizations.of(context)!.translate("chat_partner"),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.person_add, color: Colors.white),
                            onPressed: () async {
                              try {
                                await _sendFriendRequestTo(widget.otherUserId);
                              } catch (e) {
                                print("Error sending friend request: $e");
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Could not send friend request")),
                                );
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.star, color: Colors.amber),
                            onPressed: _isLoading ? null : () => _showEndorsementDialog(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(padding),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Colors.white.withOpacity(0.9),
                    title: Text(
                      AppLocalizations.of(context)!.translate("leave_room"),
                      style: const TextStyle(
                        color: Color.fromARGB(255, 73, 34, 117),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    content: Text(
                      AppLocalizations.of(context)!.translate("leave_room_confirmation"),
                      style: const TextStyle(
                        color: Color.fromARGB(255, 82, 82, 82),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          AppLocalizations.of(context)!.translate("cancel"),
                          style: const TextStyle(
                            color: Color.fromARGB(255, 147, 88, 164),
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HomePage(userId: widget.userId),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 147, 88, 164),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.translate("leave"),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.exit_to_app, color: Colors.white),
              label: Text(
                AppLocalizations.of(context)!.translate("return_home"),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 147, 88, 164),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoUserView(Size screenSize, bool isSmallScreen, double fontSize, double padding) {
    return Center(
      child: Container(
        padding: EdgeInsets.all(padding * 2),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 5,
              offset: Offset(2, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_off,
              size: 50,
              color: Color.fromARGB(255, 147, 88, 164),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.translate("no_one_is_there"),
              style: TextStyle(
                fontSize: fontSize + 2,
                fontWeight: FontWeight.bold,
                color: const Color.fromARGB(255, 73, 34, 117),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.translate("user_left_chat"),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fontSize - 2,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEndorsementDialog(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final plasmaOptions = [10, 20, 30];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context)!.translate('give_endorsement'),
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${AppLocalizations.of(context)!.translate('your_plasma_amount')}: $_userPlasma',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.translate('select_plasma_amount'),
                style: const TextStyle(
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              ...plasmaOptions.map((amount) => 
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ElevatedButton(
                    onPressed: _userPlasma >= amount ? () => _handleEndorsement(amount) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 147, 88, 164),
                      minimumSize: Size(screenWidth * 0.5, 45),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: Text(
                      '$amount ${AppLocalizations.of(context)!.translate('starry_plasma')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  minimumSize: Size(screenWidth * 0.5, 45),
                ),
                child: Text(
                  AppLocalizations.of(context)!.translate('cancel'),
                  style: const TextStyle(
                    color: Color.fromARGB(255, 147, 88, 164),
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  
  _TrianglePainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final Path path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
