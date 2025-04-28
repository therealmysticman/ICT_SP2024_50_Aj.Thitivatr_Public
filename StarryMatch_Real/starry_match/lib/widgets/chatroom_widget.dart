import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../services/chat_services.dart';
import '../models/message.dart';
import '../localization/app_localizations.dart';

///Chat Header Widget
class ChatHeader extends StatelessWidget {
  final VoidCallback onBackPressed;

  const ChatHeader({super.key, required this.onBackPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.4)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: onBackPressed,
          ),
          const Text(
            "CHATROOM",
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const Icon(Icons.menu, color: Colors.white),
        ],
      ),
    );
  }
}

class ChatAvatars extends StatefulWidget {
  final String userId;
  final String roomId;
  final bool isFriendRoom;
  final String? forcedCollection;

  const ChatAvatars({
    super.key,
    required this.userId,
    required this.roomId,
    this.isFriendRoom = false,
    this.forcedCollection,
  });

  @override
  _ChatAvatarsState createState() => _ChatAvatarsState();
}

class _ChatAvatarsState extends State<ChatAvatars> {
  Map<String, dynamic> userAvatar = {};
  Map<String, dynamic> otherUserAvatar = {};
  Map<String, List<dynamic>> participantAvatars = {};
  Set<String> currentParticipants = {};
  String otherUserAnonymousName = "Waiting...";
  bool isFetching = true;
  String matchedUserId = "Waiting...";
  bool isGroupChat = false;
  final GlobalKey _badgeKey = GlobalKey(); // Add global key for badge position

  // Add getter for isFriendRoom
  bool get isFriendRoom => widget.isFriendRoom || widget.roomId.startsWith("friend_") || widget.roomId.contains("_friend_");

  @override
  void initState() {
    super.initState();
    _listenForRoomUpdates();
  }

  void _listenForRoomUpdates() {
    final roomCollection = widget.forcedCollection ?? 
      (isFriendRoom
        ? "starrymatch_friend_chatroom"
        : "starrymatch_chatroom");
        
    print("🔍 ChatAvatars using collection: $roomCollection");

    FirebaseFirestore.instance
        .collection(roomCollection)
        .doc(widget.roomId)
        .snapshots()
        .listen((roomDoc) async {
      if (!roomDoc.exists) return;

      // Check if it's a friend chatroom or regular chatroom
      if (isFriendRoom) {
        // For friend chatroom
        List<dynamic> participants = roomDoc['members'] ?? [];
        isGroupChat = false; // Friend chatrooms are always private
        
        // Remove "No one" from participants
        participants = participants.where((p) => p != "No one").toList();
        
        // Convert to Set for easier comparison
        Set<String> newParticipants = Set<String>.from(participants.map((p) => p.toString()));
        
        // Process users who left
        Set<String> departedParticipants = currentParticipants.difference(newParticipants);
        for (String departedId in departedParticipants) {
          if (departedId != widget.userId) { // Don't remove current user
            print("✨ User left friend chatroom: $departedId");
          }
        }
        
        if (mounted) {
          setState(() {
            isFetching = false;
            currentParticipants = newParticipants;
            
            // Clear avatars for participants who left
            if (matchedUserId != "Waiting..." && !currentParticipants.contains(matchedUserId)) {
              otherUserAvatar = {};
              matchedUserId = "Waiting...";
              print("✨ Friend chat partner left");
            }
          });
        }
        
        // Always fetch current user's avatar
        _fetchUserAvatar(widget.userId, isCurrentUser: true);
        
        // For friend chat, only fetch other user if they're in the room
        if (participants.length > 1) {
          String? otherParticipant;
          for (String participantId in participants) {
            if (participantId != widget.userId) {
              otherParticipant = participantId;
              break;
            }
          }
          
          if (otherParticipant != null) {
            matchedUserId = otherParticipant;
            
            // Try to get name from memberNames map if available
            Map<String, dynamic>? memberNames = roomDoc['memberNames'] as Map<String, dynamic>?;
            if (memberNames != null && memberNames.containsKey(otherParticipant)) {
              otherUserAnonymousName = memberNames[otherParticipant] ?? "Unknown";
            }
            
            _fetchUserAvatar(matchedUserId, isCurrentUser: false);
          }
        } else {
          // No other participants, clear other user avatar
          if (mounted) {
            setState(() {
              otherUserAvatar = {};
              matchedUserId = "Waiting...";
            });
          }
        }
      } else {
        // For regular chatroom (starrymatch_chatroom)
        const keyName = "Participants";
        List<dynamic> participants = roomDoc[keyName] ?? [];
        isGroupChat = roomDoc["RoomType"] == "Group";
        
        // Remove "No one" from participants
        participants = participants.where((p) => p != "No one").toList();
        
        // Convert to Set for easier comparison
        Set<String> newParticipants = Set<String>.from(participants.map((p) => p.toString()));
        
        // Process users who left
        Set<String> departedParticipants = currentParticipants.difference(newParticipants);
        for (String departedId in departedParticipants) {
          if (departedId != widget.userId) { // Don't remove current user
            print("✨ User left: $departedId");
          }
        }
        
        if (mounted) {
          setState(() {
            isFetching = false;
            // Update current participants first
            currentParticipants = newParticipants;
            
            // Clear avatars for participants who are no longer in the room
            if (isGroupChat) {
              // Remove departed participants from the avatars map
              participantAvatars.removeWhere((key, _) => !currentParticipants.contains(key));
            } else {
              // For private chat, if other user left, clear their avatar
              if (matchedUserId != "Waiting..." && !currentParticipants.contains(matchedUserId)) {
                otherUserAvatar = {};
                matchedUserId = "Waiting...";
                print("✨ Private chat partner left");
              }
            }
          });
        }

        // Always fetch current user's avatar
        _fetchUserAvatar(widget.userId, isCurrentUser: true);

        if (isGroupChat) {
          // Fetch all participants' avatars for group chat
          for (String participantId in newParticipants) {
            if (participantId != widget.userId) {
              _fetchParticipantAvatar(participantId);
            }
          }
        } else {
          // For private chat, only fetch other user if they're in the room
          if (participants.length > 1) {
            // Find first participant that isn't current user
            String? otherParticipant;
            for (String participantId in participants) {
              if (participantId != widget.userId) {
                otherParticipant = participantId;
                break;
              }
            }
            
            // Only fetch if we found a valid participant
            if (otherParticipant != null) {
              matchedUserId = otherParticipant;
              _fetchUserAvatar(matchedUserId, isCurrentUser: false);
            }
          } else {
            // No other participants, clear other user avatar
            if (mounted) {
              setState(() {
                otherUserAvatar = {};
                matchedUserId = "Waiting...";
              });
            }
          }
        }
      }
    });
  }

  void _fetchParticipantAvatar(String userId) async {
    try {
      // Skip "No one" placeholder
      if (userId == "No one") return;
      
      print("✨ Fetching avatar for: $userId");
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection("starrymatch_user")
          .doc(userId)
          .get();

      if (userDoc.exists && mounted) {
        setState(() {
          participantAvatars[userId] = [
            userDoc["UserAvatar"] ?? {},
            userDoc["AnnonymousUsername"] ?? "Mystery Guest",
            userDoc["MBTITypes"] ?? "Not set",
            userDoc["EnneagramTypes"] ?? "Not set",
            userDoc["EndorsementGet"] ?? 0,  // Store endorsement count
          ];
          print("✨ Added participant: ${userDoc["AnnonymousUsername"]}");
        });
      }
    } catch (e) {
      print("❌ Error fetching participant avatar: $e");
    }
  }

  void _fetchUserAvatar(String userId, {required bool isCurrentUser}) async {
    // เพิ่ม delay เพื่อป้องกันการโหลดพร้อมกันจำนวนมาก
    await Future.delayed(const Duration(milliseconds: 150));
    
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection("starrymatch_user")
          .doc(userId)
          .get();

      if (userDoc.exists && mounted) {
        // ใช้ updates เก็บค่าที่จะอัพเดททั้งหมด แล้วค่อยเรียก setState ครั้งเดียว
        if (isCurrentUser) {
          Map<String, dynamic> updates = {};
          updates["userAvatar"] = userDoc["UserAvatar"] ?? {};
          updates["userAvatar"]["UserID"] = userDoc["UserID"] ?? "";
          updates["userAvatar"]["AnnonymousUsername"] = userDoc["AnnonymousUsername"] ?? "";
          updates["userAvatar"]["MBTI"] = userDoc["MBTITypes"] ?? "Not set";
          updates["userAvatar"]["Enneagram"] = userDoc["EnneagramTypes"] ?? "Not set";
          updates["userAvatar"]["EndorsementGet"] = userDoc["EndorsementGet"] ?? 0;
          
          setState(() {
            userAvatar = updates["userAvatar"];
          });
        } else if (!isGroupChat) {
          Map<String, dynamic> updates = {};
          updates["otherUserAvatar"] = userDoc["UserAvatar"] ?? {};
          updates["otherUserAvatar"]["UserID"] = userDoc["UserID"] ?? "";
          updates["otherUserAvatar"]["AnnonymousUsername"] = userDoc["AnnonymousUsername"] ?? "";
          updates["otherUserAvatar"]["MBTI"] = userDoc["MBTITypes"] ?? "Not set";
          updates["otherUserAvatar"]["Enneagram"] = userDoc["EnneagramTypes"] ?? "Not set";
          updates["otherUserAvatar"]["EndorsementGet"] = userDoc["EndorsementGet"] ?? 0;
          updates["otherUserAnonymousName"] = userDoc["AnnonymousUsername"] ?? "Mystery Guest";
          
          setState(() {
            otherUserAvatar = updates["otherUserAvatar"];
            otherUserAnonymousName = updates["otherUserAnonymousName"];
          });
        }
      }
    } catch (e) {
      print("❌ Error fetching avatars: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: isFetching
          ? const Center(child: CircularProgressIndicator())
          : isGroupChat
              ? _buildGroupAvatars()
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildAvatar(userAvatar, "You"),
                    const SizedBox(width: 20),
                    // Only show other user if they have avatar data
                    if (otherUserAvatar.isNotEmpty && otherUserAvatar["selectedSkin"] != null)
                      _buildAvatar(otherUserAvatar, isFriendRoom 
                          ? (otherUserAvatar["AnnonymousUsername"] ?? otherUserAnonymousName)
                          : (otherUserAvatar["AnnonymousUsername"] ?? otherUserAnonymousName)),
                  ],
                ),
    );
  }

  Widget _buildGroupAvatars() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAvatar(userAvatar, "You"),
          ...participantAvatars.entries.map((entry) {
            final avatarData = entry.value[0] as Map<String, dynamic>;
            final username = entry.value[1] as String;
            final mbti = entry.value[2];
            final enneagram = entry.value[3];
            final endorsementGet = entry.value[4] as int?;
            
            avatarData["MBTI"] = mbti;
            avatarData["Enneagram"] = enneagram;
            avatarData["EndorsementGet"] = endorsementGet ?? 0;
            
            // Only show avatars for users that are currently in the room
            if (!currentParticipants.contains(entry.key)) {
              // Skip avatar if user has left
              return const SizedBox.shrink();
            }
            
            // Skip if no valid avatar data
            if (avatarData.isEmpty || avatarData["selectedSkin"] == null) {
              return const SizedBox.shrink();
            }
            
            return Row(
              children: [
                const SizedBox(width: 20),
                _buildAvatar(avatarData, username),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAvatar(Map<String, dynamic> avatarMap, String label) {
    // Skip rendering completely if no valid avatar
    if (avatarMap.isEmpty || avatarMap["selectedSkin"] == null) {
      return const SizedBox.shrink();
    }

    // Check if user has enough endorsements for badge
    bool showEndorsementBadge = (avatarMap["EndorsementGet"] is int) && 
                               (avatarMap["EndorsementGet"] >= 200);

    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Show Avatar
              Image.asset(
                'assets/Avatar/Skin/${avatarMap["selectedSkin"]}.png',
                width: 80,
                height: 80,
                fit: BoxFit.contain,
                cacheWidth: 160, // เพิ่มความละเอียดของภาพที่แ
              ),

              // Show Hat/Clothes if they exist
              if (avatarMap["selectedHat"] != null && avatarMap["selectedHat"] != "")
                Image.asset(
                  'assets/Avatar/Decoration/Accessories/${avatarMap["selectedHat"]}.png',
                  width: 80,
                  height: 80,
                  fit: BoxFit.contain,
                  cacheWidth: 160, // เพิ่มความละเอียดของภาพที่แคช
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox(); // ไม่แสดงอะไรถ้าโหลดภาพไม่สำเร็จ
                  },
                ),

              if (avatarMap["selectedClothes"] != null && avatarMap["selectedClothes"] != "")
                Image.asset(
                  'assets/Avatar/Decoration/Clothing/${avatarMap["selectedClothes"]}.png',
                  width: 80,
                  height: 80,
                  fit: BoxFit.contain,
                  cacheWidth: 160, // เพิ่มความละเอียดของภาพที่แคช
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox(); // ไม่แสดงอะไรถ้าโหลดภาพไม่สำเร็จ
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Show endorsement badge if user has 200+ endorsements
                if (showEndorsementBadge)
                  GestureDetector(
                    onTap: () {
                      // Get the badge's position using the GlobalKey
                      final RenderBox? badgeBox = _badgeKey.currentContext?.findRenderObject() as RenderBox?;
                      if (badgeBox == null) return;
                      
                      final badgeSize = badgeBox.size;
                      final badgePosition = badgeBox.localToGlobal(Offset.zero);
                      
                      // Create an OverlayEntry for the tooltip
                      final overlay = Overlay.of(context);
                      OverlayEntry? entry;
                      
                      // Calculate the width of the tooltip for proper centering
                      const tooltipWidth = 200.0;
                      
                      entry = OverlayEntry(
                        builder: (context) => Positioned(
                          // Center the bubble over the badge by finding center of badge and subtracting half of tooltip width
                          left: badgePosition.dx - (tooltipWidth / 2) + (badgeSize.width / 2),
                          // Position above the badge with some spacing
                          top: badgePosition.dy - 75,
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
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Image.asset(
                        'assets/endorsement_badge.PNG',
                        width: 16,
                        height: 16,
                        key: _badgeKey, // Add the key to the badge image
                      ),
                    ),
                  ),
                Text(
                  label,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Text(
              avatarMap["MBTI"] ?? "Not set",
              style: TextStyle(
                color: Theme.of(context).colorScheme.tertiary,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
            Text(
              avatarMap["Enneagram"] ?? "Not set",
              style: TextStyle(
                color: Theme.of(context).colorScheme.tertiary,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
            if (isFriendRoom && avatarMap["UserID"] != null)
              Text(
                avatarMap["UserID"],
                style: TextStyle(
                  color: Theme.of(context).colorScheme.tertiary,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

///Chat Messages List Widget
class ChatMessageList extends StatefulWidget {
  final String roomId;
  final String userId;
  final ChatService chatService;
  final ScrollController scrollController;
  final bool isFriendRoom;
  final String? forcedCollection; // New parameter to explicitly set collection

  const ChatMessageList({
    super.key,
    required this.roomId,
    required this.userId,
    required this.chatService,
    required this.scrollController,
    this.isFriendRoom = false,
    this.forcedCollection,
  });

  @override
  _ChatMessageListState createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<ChatMessageList> {
  final Map<String, String> userIdToName = {};
  final int _messageLimit = 50; // Limit messages to load
  bool _isLoadingMore = false;
  List<Message> _cachedMessages = [];
  StreamSubscription? _messagesSubscription;
  bool _canScroll = true; // เพิ่มตัวแปรควบคุมการเลื่อน

  @override
  void initState() {
    super.initState();
    _setupMessageStream();
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    super.dispose();
  }

  void _setupMessageStream() {
    // Use the forced collection if provided, otherwise let the chatService determine it
    Stream<List<Message>> messagesStream;
    
    if (widget.forcedCollection != null) {
      // Directly use the specified collection with limit
      messagesStream = FirebaseFirestore.instance
          .collection(widget.forcedCollection!)
          .doc(widget.roomId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .limitToLast(_messageLimit)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => Message.fromMap(doc.data(), doc.id))
            .toList();
      });
      print("🔍 Using forced collection with limit: ${widget.forcedCollection}");
    } else {
      // Let the chat service determine the collection based on roomId with limit
      messagesStream = widget.chatService.getMessagesWithLimit(widget.roomId, _messageLimit);
    }
    
    // Cache messages and only rebuild UI when necessary
    _messagesSubscription = messagesStream.listen((messages) {
      if (mounted) {
        final bool shouldScroll = 
            _cachedMessages.isEmpty || // First load
            (_cachedMessages.isNotEmpty && 
             messages.isNotEmpty && 
             _cachedMessages.last.id != messages.last.id); // New message
        
        setState(() {
          _cachedMessages = messages;
          // Load names outside of build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadUserNames(messages);
            // Scroll to bottom if new message arrives
            if (shouldScroll) {
              _scrollToBottom();
            }
          });
        });
      }
    });
  }

  void _loadUserNames(List<Message> messages) async {
    final Set<String> userIds = {};
    
    // Collect unique user IDs that we don't have names for yet
    for (final message in messages) {
      if (message.senderId != widget.userId && 
          !userIdToName.containsKey(message.senderId)) {
        userIds.add(message.senderId);
      }
    }
    
    if (userIds.isEmpty) return;
    
    // Load names for new users
    for (final userId in userIds) {
      try {
        final userName = await widget.chatService.getUserName(userId);
        if (mounted) {
          setState(() {
            userIdToName[userId] = userName;
          });
        }
      } catch (e) {
        print("❌ Error loading username for $userId: $e");
      }
    }
  }

  // ปรับปรุงการเลื่อนข้อความอัตโนมัติ
  void _scrollToBottom() {
    if (_canScroll && widget.scrollController.hasClients) {
      _canScroll = false;
      widget.scrollController.animateTo(
        widget.scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      Future.delayed(const Duration(milliseconds: 500), () => _canScroll = true);
    }
  }

  @override
  Widget build(BuildContext context) {
   

    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: _cachedMessages.length,
      itemBuilder: (context, index) {
        final message = _cachedMessages[index];
        final isMe = message.senderId == widget.userId;
        final senderName =
            isMe ? "You" : userIdToName[message.senderId] ?? "Loading...";

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 4),
                      child: Text(
                        senderName,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    decoration: BoxDecoration(
                      color: isMe
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceDim,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      message.text,
                      style: TextStyle(
                        color: isMe ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.primaryFixed,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// ✅ Chat Message Input Box
class ChatMessageInput extends StatelessWidget {
  final TextEditingController messageController;
  final VoidCallback onSendMessage;

  const ChatMessageInput(
      {super.key,
      required this.messageController,
      required this.onSendMessage});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: TextField(
                  controller: messageController,
                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.translate('type_message_hint'),
                    hintStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                    border: InputBorder.none,
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      onSendMessage();
                    }
                  },
                )),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.white),
            onPressed: onSendMessage,
          )
        ],
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
