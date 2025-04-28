import 'package:flutter/material.dart';
import 'package:starry_match/localization/app_localizations.dart';
import 'package:starry_match/services/chat_services.dart';
import 'package:starry_match/theme/AppThemeExtension.dart';
import 'package:starry_match/userlist.dart';
import 'widgets/chatroom_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoomPage extends StatefulWidget {
  final String roomId;
  final String userId;
  final String otherUserId;
  final String roomType;
  final String criteria;
  final String selectedCriteria;
  final String userPersonalityType;
  final String selectedPersonality;
  const ChatRoomPage({
    super.key,
    required this.roomId,
    required this.userId,
    required this.otherUserId,
    required this.roomType,
    required this.criteria,
    required this.selectedCriteria,
    required this.userPersonalityType,
    required this.selectedPersonality,
  });

  @override
  _ChatRoomPageState createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final ScrollController _scrollController = ScrollController();
  bool _canScroll = true;
  bool _isTyping = false;
  DateTime? _lastTypingTime;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _saveActiveChatroom();
    _messageController.addListener(_onTypingChanged);
  }

  void _onTypingChanged() {
    final isCurrentlyTyping = _messageController.text.isNotEmpty;
    final now = DateTime.now();
    
    if (isCurrentlyTyping != _isTyping || 
        (_lastTypingTime != null && now.difference(_lastTypingTime!).inSeconds >= 2)) {
      _isTyping = isCurrentlyTyping;
      _lastTypingTime = now;
      
      _chatService.setTypingStatus(
        widget.roomId, 
        widget.userId, 
        _isTyping
      );
      
      _typingTimer?.cancel();
      if (_isTyping) {
        _typingTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) {
            _chatService.setTypingStatus(
              widget.roomId, 
              widget.userId, 
              false
            );
            _isTyping = false;
          }
        });
      }
    }
  }
  
  Future<void> _saveActiveChatroom() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_chatroom_id', widget.roomId);
      await prefs.setString('active_chatroom_user_id', widget.userId);
      debugPrint("✅ Saved active chatroom: ${widget.roomId}");
    } catch (e) {
      debugPrint("❌ Error saving active chatroom: $e");
    }
  }

  Future<void> _removeActiveChatroom() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('active_chatroom_id');
      await prefs.remove('active_chatroom_user_id');
      debugPrint("✅ Removed active chatroom");
    } catch (e) {
      debugPrint("❌ Error removing active chatroom: $e");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.inactive || 
        state == AppLifecycleState.detached) {
      if (_isTyping) {
        _chatService.setTypingStatus(widget.roomId, widget.userId, false);
        _isTyping = false;
      }
      
      if (state == AppLifecycleState.detached) {
        debugPrint("🔴 App detached - leaving chatroom ${widget.roomId}");
        _leaveChatroomSynchronously();
      } else {
        _saveActiveChatroom();
      }
    } else if (state == AppLifecycleState.resumed) {
      _onTypingChanged();
    }
  }

  void _scrollToBottom() {
    if (_canScroll && _scrollController.hasClients) {
      _canScroll = false;
      
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      
      Future.delayed(const Duration(milliseconds: 500), () {
        _canScroll = true;
      });
    }
  }

  void _leaveChatroomSynchronously() {
    try {
      // Skip for friend chatrooms - these should be persistent
      if (widget.roomId.contains('friend_')) {
        debugPrint("📝 Skipping leave for friend chatroom: ${widget.roomId}");
        // Still clear typing status
        FirebaseFirestore.instance
            .collection('starrymatch_friend_chatroom')
            .doc(widget.roomId)
            .collection('typing')
            .doc(widget.userId)
            .delete()
            .then((_) {
              debugPrint("✅ Cleared typing status for friend chatroom");
            });
        // Remove active room preference
        _removeActiveChatroom();
        return;
      }
      
      // Only handle regular chatrooms
      final docRef = FirebaseFirestore.instance
          .collection('starrymatch_chatroom')
          .doc(widget.roomId);
      
      // First get the current document to check participants
      docRef.get().then((docSnapshot) {
        if (!docSnapshot.exists) {
          debugPrint("⚠️ Room doesn't exist: ${widget.roomId}");
          return;
        }
        
        // Get current participants
        List<dynamic> participants = List<dynamic>.from(docSnapshot.data()?['Participants'] ?? []);
        
        // Remove current user
        participants.removeWhere((p) => p == widget.userId);
        
        // Check if room is now empty
        bool isEmpty = participants.isEmpty;
        
        // If empty, use "No one" placeholder
        if (isEmpty) {
          participants = ["No one"];
        }
        
        // Update the room with new participants list
        docRef.update({
          'Participants': participants,
          'IsEmpty': isEmpty
        }).then((_) {
          // Also remove typing status
          FirebaseFirestore.instance
              .collection('starrymatch_chatroom')
              .doc(widget.roomId)
              .collection('typing')
              .doc(widget.userId)
              .delete();
          
          // Update user status
          FirebaseFirestore.instance
              .collection("starrymatch_user")
              .doc(widget.userId)
              .update({"IsInChatroom": false});
          
          // Clean up local preferences
          _removeActiveChatroom();
          
          debugPrint("✅ Successfully left room synchronously: ${widget.roomId}");
        }).catchError((e) {
          debugPrint("❌ Error updating room: $e");
        });
      }).catchError((e) {
        debugPrint("❌ Error getting room data: $e");
      });
    } catch (e) {
      debugPrint("❌ Error in _leaveChatroomSynchronously: $e");
    }
  }

  @override
  void dispose() {
    debugPrint("💫 ChatRoomPage dispose called for room ${widget.roomId}");
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _messageController.removeListener(_onTypingChanged);
    _messageController.dispose();
    
    _typingTimer?.cancel();
    if (_isTyping) {
      _chatService.setTypingStatus(widget.roomId, widget.userId, false);
    }
    
    _cleanupChatroom();
    super.dispose();
  }

  Future<void> _cleanupChatroom() async {
    try {
      if (_isTyping) {
        await _chatService.setTypingStatus(widget.roomId, widget.userId, false);
      }
      await _chatService.leaveChatroom(widget.roomId, widget.userId);
      await _removeActiveChatroom();
    } catch (e, stack) {
      debugPrint("❌ Error during chatroom cleanup: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeExt = Theme.of(context).extension<AppThemeExtension>();
    final bgImage = themeExt?.bgMain ?? 'assets/bg_pastel_main.jpg';
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final headerHeight = isSmallScreen ? 60.0 : 80.0;
    final fontSize = isSmallScreen ? 14.0 : 16.0;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final bottomPaddingAdjusted = bottomPadding > 0 ? bottomPadding + 8 : 16.0;

    return WillPopScope(
      onWillPop: () async {
        try {
          if (_isTyping) {
            await _chatService.setTypingStatus(widget.roomId, widget.userId, false);
            _isTyping = false;
          }
          await _chatService.leaveChatroom(widget.roomId, widget.userId);
        } catch (e, stack) {
          debugPrint("❌ Error leaving chatroom: $e");
        }
        if (!mounted) return true;
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => UserListPage(
              userId: widget.userId,
              otherUserId: widget.otherUserId,
              isHistory: true,
            ),
          ),
        );
        return true;
      },
      child: Scaffold(
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
                Container(
                  height: headerHeight,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(15),
                      bottomRight: Radius.circular(15),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () async {
                          try {
                            if (_isTyping) {
                              await _chatService.setTypingStatus(widget.roomId, widget.userId, false);
                              _isTyping = false;
                            }
                            await _chatService.leaveChatroom(widget.roomId, widget.userId);
                          } catch (e, stack) {
                            debugPrint("❌ Error leaving chatroom: $e");
                          }
                          if (!mounted) return;
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserListPage(
                                userId: widget.userId,
                                otherUserId: widget.otherUserId,
                                isHistory: true,
                              ),
                            ),
                          );
                        },
                      ),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              widget.roomType == "Group"
                                  ? "GROUP CHAT"
                                  : "CHATROOM",
                              style: TextStyle(
                                fontSize: fontSize + 4,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              widget.selectedCriteria,
                              style: TextStyle(
                                fontSize: fontSize - 2,
                                fontWeight: FontWeight.w400,
                                color: Colors.white70,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.door_front_door,
                            color: Colors.white),
                        onPressed: () async {
                          String otherUserId;
                          try {
                            if (_isTyping) {
                              await _chatService.setTypingStatus(widget.roomId, widget.userId, false);
                              _isTyping = false;
                            }
                            otherUserId = await _chatService.leaveChatroom(
                                widget.roomId, widget.userId);
                            await _removeActiveChatroom();
                          } catch (e, stack) {
                            debugPrint("❌ Error leaving chatroom: $e");
                            otherUserId = widget.otherUserId;
                          }
                          if (!mounted) return;
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserListPage(
                                userId: widget.userId,
                                otherUserId: otherUserId,
                                isHistory: true,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                ChatAvatars(userId: widget.userId, roomId: widget.roomId),

                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (ScrollNotification notification) {
                      if (notification is ScrollEndNotification) {
                        _scrollToBottom();
                      }
                      return true;
                    },
                    child: ChatMessageList(
                      roomId: widget.roomId,
                      userId: widget.userId,
                      chatService: _chatService,
                      scrollController: _scrollController,
                    ),
                  ),
                ),

                StreamBuilder<List<String>>(
                  stream: _chatService.getTypingUsersStream(widget.roomId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    
                    final typingUsers = snapshot.data!
                        .where((userId) => userId != widget.userId)
                        .toList();
                    
                    if (typingUsers.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return FutureBuilder<String>(
                      future: _chatService.getUserName(typingUsers.first),
                      builder: (context, usernameSnapshot) {
                        String displayName = usernameSnapshot.data ?? "Someone";
                        
                        return Padding(
                          padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
                          child: Text(
                            typingUsers.length > 1
                              ? AppLocalizations.of(context)!.translate("multiple_typing")
                              : "$displayName ${AppLocalizations.of(context)!.translate("is_typing")}",
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 14,
                            ),
                          ),
                        );
                      }
                    );
                  },
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ChatMessageInput(
                        messageController: _messageController,
                        onSendMessage: () {
                          if (_messageController.text.trim().isNotEmpty) {
                            _chatService.sendMessage(
                              widget.roomId,
                              widget.userId,
                              _messageController.text.trim(),
                            );
                            _messageController.clear();
                            _scrollToBottom();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
