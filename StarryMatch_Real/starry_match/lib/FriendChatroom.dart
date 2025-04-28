import 'package:flutter/material.dart';
import 'package:starry_match/theme/AppThemeExtension.dart';
import 'package:starry_match/widgets/chatroom_widget.dart';
import 'package:starry_match/services/chat_services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FriendChatroomPage extends StatefulWidget {
  final String chatroomId;
  final String friendName;
  final String userId;

  const FriendChatroomPage({
    super.key,
    required this.chatroomId,
    required this.friendName,
    required this.userId,
  });

  @override
  State<FriendChatroomPage> createState() => _FriendChatroomPageState();
}

class _FriendChatroomPageState extends State<FriendChatroomPage> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final ScrollController _scrollController = ScrollController();
  // Track which collection to use for this chatroom
  String? _correctCollection;
  bool _isCheckingCollection = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkChatroomCollection().then((_) {
      if (_correctCollection != null) {
        _ensureMemberNamesUpdated();
      }
    });
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only do cleanup when app is actually closing (detached),
    // not when user switches to another app (paused) or views app list (inactive)
    if (state == AppLifecycleState.detached) {
      // No need to leave the chatroom as these are persistent friend chats
      // Just do any cleanup if needed
    }
  }
  
  // Method to check which collection contains this chatroom ID
  Future<void> _checkChatroomCollection() async {
    if (_isCheckingCollection) return;
    
    _isCheckingCollection = true;
    
    try {
      print("🔍 Checking collections for roomId: ${widget.chatroomId}");
      
      // Check friend collection first
      final friendSnapshot = await FirebaseFirestore.instance
          .collection("starrymatch_friend_chatroom")
          .doc(widget.chatroomId)
          .get();
          
      if (friendSnapshot.exists) {
        setState(() {
          _correctCollection = "starrymatch_friend_chatroom";
        });
        print("✅ Found chatroom in starrymatch_friend_chatroom");
        return;
      }
      
      // Check regular collection second
      final regularSnapshot = await FirebaseFirestore.instance
          .collection("starrymatch_chatroom")
          .doc(widget.chatroomId)
          .get();
          
      if (regularSnapshot.exists) {
        setState(() {
          _correctCollection = "starrymatch_chatroom";
        });
        print("✅ Found chatroom in starrymatch_chatroom");
        return;
      }
      
      print("❌ Chatroom not found in either collection");
    } catch (e) {
      print("❌ Error checking chatroom collection: $e");
    } finally {
      _isCheckingCollection = false;
    }
  }

  // Method to ensure member names are up to date
  Future<void> _ensureMemberNamesUpdated() async {
    if (_correctCollection != "starrymatch_friend_chatroom") return;
    
    try {
      // Get the chatroom document
      final chatroomDoc = await FirebaseFirestore.instance
          .collection(_correctCollection!)
          .doc(widget.chatroomId)
          .get();
      
      if (!chatroomDoc.exists) return;
      
      // Get the current members and memberNames
      final members = chatroomDoc.data()?['members'] as List<dynamic>?;
      if (members == null || members.isEmpty) return;
      
      Map<String, dynamic> currentMemberNames = Map<String, dynamic>.from(chatroomDoc.data()?['memberNames'] ?? {});
      Map<String, dynamic> updatedMemberNames = Map<String, dynamic>.from(currentMemberNames);
      bool needsUpdate = false;
      
      // Check each member's name against the user document
      for (final memberId in members) {
        final userDoc = await FirebaseFirestore.instance
            .collection("starrymatch_user")
            .doc(memberId.toString())
            .get();
            
        if (userDoc.exists) {
          final latestUsername = userDoc.data()?['AnnonymousUsername'];
          if (latestUsername != null && latestUsername != currentMemberNames[memberId]) {
            // Update the name
            updatedMemberNames[memberId] = latestUsername;
            needsUpdate = true;
            print("👤 Updated name for user $memberId: $latestUsername");
          }
        }
      }
      
      // If any names changed, update the chatroom document
      if (needsUpdate) {
        await FirebaseFirestore.instance
            .collection(_correctCollection!)
            .doc(widget.chatroomId)
            .update({'memberNames': updatedMemberNames});
        print("✅ Updated memberNames in chatroom ${widget.chatroomId}");
      }
    } catch (e) {
      print("❌ Error ensuring member names: $e");
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeExt = Theme.of(context).extension<AppThemeExtension>();
    final bgImage = themeExt?.bgMain ?? 'assets/bg/bg_pastel_main.jpg';
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final bottomPaddingAdjusted = bottomPadding > 0 ? bottomPadding + 8 : 16.0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(bgImage),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              ChatHeader(
                onBackPressed: () async {
                  // Get the latest message and user info before popping
                  Map<String, dynamic> result = {'updated': true};
                  
                  try {
                    // 1. Get the latest message if collection is known
                    if (_correctCollection != null) {
                      // Get the chatroom document to check lastMessage
                      final chatroomDoc = await FirebaseFirestore.instance
                          .collection(_correctCollection!)
                          .doc(widget.chatroomId)
                          .get();
                          
                      if (chatroomDoc.exists) {
                        // Get the last message using the appropriate case based on collection type
                        final isFriendCollection = _correctCollection == "starrymatch_friend_chatroom";
                        final lastMessageKey = isFriendCollection ? 'lastMessage' : 'LastMessage';
                        final lastTimeKey = isFriendCollection ? 'lastMessageTime' : 'LastMessageTime';
                        
                        result['lastMessage'] = chatroomDoc.data()?[lastMessageKey];
                        result['lastMessageTime'] = chatroomDoc.data()?[lastTimeKey];
                      }
                      
                      // 2. Get the other user's AnnonymousUsername
                      // First get other user ID from chatroom members
                      final members = chatroomDoc.data()?[
                        _correctCollection == "starrymatch_friend_chatroom" ? 'members' : 'Participants'
                      ] as List<dynamic>?;
                      
                      if (members != null) {
                        String? otherUserId;
                        for (final member in members) {
                          if (member.toString() != widget.userId) {
                            otherUserId = member.toString();
                            break;
                          }
                        }
                        
                        if (otherUserId != null) {
                          // Get username from user collection
                          final userDoc = await FirebaseFirestore.instance
                              .collection("starrymatch_user")
                              .doc(otherUserId)
                              .get();
                              
                          if (userDoc.exists) {
                            result['otherUserId'] = otherUserId;
                            result['anonymousUsername'] = userDoc.data()?['AnnonymousUsername'];
                          }
                        }
                      }
                    }
                  } catch (e) {
                    print("❌ Error fetching info for navigator pop: $e");
                  }
                  
                  // Pop with result data
                  Navigator.pop(context, result);
                },
              ),

// 👇 เพิ่ม Avatar ตรงนี้
              ChatAvatars(
                userId: widget.userId,
                roomId: widget.chatroomId,
                isFriendRoom: true,
                forcedCollection: _correctCollection,
              ),

              const SizedBox(height: 8),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollEndNotification) {
                      _scrollToBottom();
                    }
                    return true;
                  },
                  child: _correctCollection == null
                    ? const Center(child: CircularProgressIndicator())
                    : ChatMessageList(
                        roomId: widget.chatroomId,
                        userId: widget.userId,
                        chatService: _chatService,
                        scrollController: _scrollController,
                        isFriendRoom: _correctCollection == "starrymatch_friend_chatroom",
                        forcedCollection: _correctCollection,
                      ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(15),
                    topRight: Radius.circular(15),
                  ),
                ),
                child: ChatMessageInput(
                  messageController: _messageController,
                  onSendMessage: () async {
                    if (_messageController.text.trim().isNotEmpty) {
                      final messageText = _messageController.text.trim();
                      _messageController.clear();
                      
                      // Force collection check if not done already
                      if (_correctCollection == null) {
                        await _checkChatroomCollection();
                      }
                      
                      // Ensure member names are up to date before sending
                      await _ensureMemberNamesUpdated();
                      
                      // Determine if it's a friend room based on collection
                      final isFriendCollection = _correctCollection == "starrymatch_friend_chatroom";
                      
                      print("📤 Sending message to collection: ${_correctCollection ?? 'unknown'}");
                      print("📤 Is friend chatroom: $isFriendCollection");
                      
                      try {
                        final timestamp = Timestamp.now();
                        
                        // 1. Add message to collection first
                        await FirebaseFirestore.instance
                            .collection(_correctCollection ?? "starrymatch_friend_chatroom")
                            .doc(widget.chatroomId)
                            .collection('messages')
                            .add({
                              'text': messageText,
                              'senderId': widget.userId,
                              'timestamp': timestamp,
                            });
                        
                        // 2. Update lastMessage field with the correct case
                        if (isFriendCollection) {
                          // For friend chatroom - use camelCase keys
                          await FirebaseFirestore.instance
                              .collection(_correctCollection!)
                              .doc(widget.chatroomId)
                              .update({
                                'lastMessage': messageText,
                                'lastMessageTime': timestamp,
                              });
                        } else {
                          // For regular chatroom - use PascalCase keys
                          await FirebaseFirestore.instance
                              .collection(_correctCollection!)
                              .doc(widget.chatroomId)
                              .update({
                                'LastMessage': messageText,
                                'LastMessageTime': timestamp,
                              });
                        }
                        
                        // Ensure member names are up to date
                        await _ensureMemberNamesUpdated();
                        
                        print("✅ Message sent successfully");
                      } catch (error) {
                        print("❌ Error sending message: $error");
                      }
                      
                      _scrollToBottom();
                    }
                  },
                ),
              ),
            ],
          ),
        )
      ),
    );
  }
}
