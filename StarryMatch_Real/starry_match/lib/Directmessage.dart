import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:starry_match/FriendChatroom.dart';
import 'package:starry_match/localization/app_localizations.dart';
import 'package:starry_match/widgets/bottomnav_widget.dart';
import 'package:starry_match/theme/AppThemeExtension.dart';

class DirectMessagePage extends StatefulWidget {
  final String userId;

  const DirectMessagePage({super.key, required this.userId});

  @override
  _DirectMessagePageState createState() => _DirectMessagePageState();
}

class _DirectMessagePageState extends State<DirectMessagePage> {
  int _selectedIndex = 1; // ✅ Default to Direct Messages tab
  // Add a key to force refresh the FutureBuilder
  final GlobalKey<State> _futureBuilderKey = GlobalKey<State>();
  // Cache for chatrooms to update without refetching
  List<Map<String, dynamic>> _cachedChatrooms = [];

  Future<List<Map<String, dynamic>>> fetchFriendChatrooms() async {
    // ✅ ดึง document ของ user ก่อน
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('starrymatch_user')
        .doc(widget.userId)
        .get();

    // ✅ เช็คว่า friends มีจริงไหม
    if (!userDoc.exists ||
        userDoc['friends'] == null ||
        (userDoc['friends'] as List).isEmpty) {
      return [];
    }

    // ✅ ดึง chatroom ที่มี user อยู่ใน members
    QuerySnapshot chatroomSnapshot = await FirebaseFirestore.instance
        .collection('starrymatch_friend_chatroom')
        .where('members', arrayContains: widget.userId)
        .get();

    // ✅ แปลง DocumentSnapshot เป็น Map<String, dynamic>
    _cachedChatrooms = chatroomSnapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id; // ✅ ใส่ docId เข้าไปใน map ด้วย
      return data;
    }).toList();
    
    return _cachedChatrooms;
  }

  // Method to update a chatroom in the cached list
  void updateCachedChatroom(String chatroomId, Map<String, dynamic> updates) {
    setState(() {
      for (int i = 0; i < _cachedChatrooms.length; i++) {
        if (_cachedChatrooms[i]['id'] == chatroomId) {
          // Apply all updates to the cached chatroom
          updates.forEach((key, value) {
            if (value != null) {
              _cachedChatrooms[i][key] = value;
            }
          });
          
          // If we're updating a username, we need to update the memberNames
          if (updates['otherUserId'] != null && updates['anonymousUsername'] != null) {
            Map<String, dynamic> memberNames = Map<String, dynamic>.from(_cachedChatrooms[i]['memberNames'] ?? {});
            memberNames[updates['otherUserId']] = updates['anonymousUsername'];
            _cachedChatrooms[i]['memberNames'] = memberNames;
          }
          
          break;
        }
      }
    });
  }

  // Add a method to sync memberNames with latest user data
  Future<void> syncMemberNames() async {
    if (_cachedChatrooms.isEmpty) return;
    
    print("🔄 Syncing member names with user collection...");
    bool anyUpdates = false;
    
    // For each chatroom, get the members and update their names
    for (int i = 0; i < _cachedChatrooms.length; i++) {
      final chatroom = _cachedChatrooms[i];
      final members = chatroom['members'] as List<dynamic>?;
      if (members == null || members.isEmpty) continue;
      
      Map<String, dynamic> currentMemberNames = Map<String, dynamic>.from(chatroom['memberNames'] ?? {});
      Map<String, dynamic> updatedMemberNames = Map<String, dynamic>.from(currentMemberNames);
      bool chatroomUpdated = false;
      
      // Check each member
      for (final memberId in members) {
        if (memberId == widget.userId) continue; // Skip current user
        
        try {
          // Get the latest user data
          final userDoc = await FirebaseFirestore.instance
              .collection("starrymatch_user")
              .doc(memberId.toString())
              .get();
              
          if (userDoc.exists) {
            final latestUsername = userDoc.data()?['AnnonymousUsername'];
            if (latestUsername != null && latestUsername != currentMemberNames[memberId]) {
              // Name has changed, update it
              updatedMemberNames[memberId] = latestUsername;
              chatroomUpdated = true;
              print("👤 Updated name for user $memberId: $latestUsername");
            }
          }
        } catch (e) {
          print("❌ Error fetching user $memberId: $e");
        }
      }
      
      // If any names were updated, update the chatroom document
      if (chatroomUpdated) {
        try {
          // Update Firestore
          await FirebaseFirestore.instance
              .collection("starrymatch_friend_chatroom")
              .doc(chatroom['id'])
              .update({'memberNames': updatedMemberNames});
              
          // Update local cache
          _cachedChatrooms[i]['memberNames'] = updatedMemberNames;
          anyUpdates = true;
          print("✅ Updated memberNames in chatroom ${chatroom['id']}");
        } catch (e) {
          print("❌ Error updating chatroom ${chatroom['id']}: $e");
        }
      }
    }
    
    // If any updates were made, refresh the UI
    if (anyUpdates && mounted) {
      setState(() {});
    }
  }

  // Add a method to build avatar widget
  Widget _buildAvatar(Map<String, dynamic> avatarMap, {double size = 40}) {
    bool isUserMissing = avatarMap.isEmpty || avatarMap["selectedSkin"] == null;
    
    return Stack(
      alignment: Alignment.center,
      children: [
        CircleAvatar(
          radius: size / 2,
          backgroundColor: Colors.grey.withOpacity(0.3),
          child: Image.asset(
            isUserMissing
                ? 'assets/Avatar/placeholder.png'
                : 'assets/Avatar/Skin/${avatarMap["selectedSkin"]}.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
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
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    // Initialize data and sync usernames
    fetchFriendChatrooms().then((_) {
      syncMemberNames();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeExt = Theme.of(context).extension<AppThemeExtension>();
    final bgImage = themeExt?.bgMain ?? 'assets/bg/bg_pastel_main.jpg';

    return Stack(
      children: [
        // ✅ Background image
        Positioned.fill(
          child: Image.asset(
            bgImage,
            fit: BoxFit.cover,
          ),
        ),

        // ✅ Main Content on top
        Scaffold(
          backgroundColor: Colors.transparent, // ✅ ให้เห็น bg ด้านหลัง
          appBar: AppBar(
            title: Text(AppLocalizations.of(context)!.translate("direct_messages")),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: FutureBuilder<List<Map<String, dynamic>>>(
            key: _futureBuilderKey,
            future: fetchFriendChatrooms(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(child: Text(AppLocalizations.of(context)!.translate("no_friends")));
              }

              final chatrooms = snapshot.data!;

              return ListView.builder(
                itemCount: chatrooms.length,
                itemBuilder: (context, index) {
                  final chatroom = chatrooms[index];
                  final lastMessage = chatroom['lastMessage'] ?? '';
                  final memberNames =
                      Map<String, dynamic>.from(chatroom['memberNames'] ?? {});
                  memberNames.remove(widget.userId);
                  final friendId = memberNames.keys.isNotEmpty ? memberNames.keys.first : '';
                  
                  // Use FutureBuilder to fetch the current AnnonymousUsername directly
                  return FutureBuilder<DocumentSnapshot>(
                    future: friendId.isNotEmpty 
                        ? FirebaseFirestore.instance.collection('starrymatch_user').doc(friendId).get()
                        : null,
                    builder: (context, userSnapshot) {
                      // Get the username either from Firebase or fallback to cached value
                      String friendName = "Loading...";
                      
                      if (userSnapshot.connectionState == ConnectionState.waiting) {
                        // While waiting, use the cached name if available
                        friendName = memberNames.values.isNotEmpty ? memberNames.values.first : 'Loading...';
                      } else if (userSnapshot.hasData && userSnapshot.data != null && userSnapshot.data!.exists) {
                        // Use the latest username from the user document
                        final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                        friendName = userData?['AnnonymousUsername'] ?? 'Unknown';
                        
                        // Update the cached memberNames if it differs
                        if (friendName != memberNames[friendId]) {
                          // Update cache
                          memberNames[friendId] = friendName;
                          chatroom['memberNames'] = memberNames;
                          
                          // Update Firestore (do this in background)
                          FirebaseFirestore.instance
                              .collection('starrymatch_friend_chatroom')
                              .doc(chatroom['id'])
                              .update({'memberNames': memberNames})
                              .then((_) => print("✅ Updated memberNames for ${chatroom['id']}"))
                              .catchError((e) => print("❌ Error updating memberNames: $e"));
                        }
                      } else {
                        // Fallback to cached value if Firebase fetch failed
                        friendName = memberNames.values.isNotEmpty ? memberNames.values.first : 'Unknown';
                      }
                      
                      final colorScheme = Theme.of(context).colorScheme;
                      
                      return Card(
                        color: colorScheme.surface,
                        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        elevation: 4, // Added elevation for shadow
                        shadowColor: Colors.black.withOpacity(0.3), // Customized shadow color
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12), // Optional: rounded corners
                        ),
                        child: ListTile(
                          leading: FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('starrymatch_user')
                                .doc(friendId)
                                .get(),
                            builder: (context, avatarSnapshot) {
                              if (avatarSnapshot.hasData && avatarSnapshot.data!.exists) {
                                Map<String, dynamic> userData = avatarSnapshot.data!.data() as Map<String, dynamic>;
                                Map<String, dynamic> userAvatar = userData['UserAvatar'] ?? {};
                                return _buildAvatar(userAvatar);
                              }
                              return const CircleAvatar(
                                backgroundColor: Colors.deepPurpleAccent,
                                child: Icon(Icons.person, color: Colors.white),
                              );
                            },
                          ),
                          title: Text(friendName),
                          subtitle: Text(lastMessage),
                          onTap: () async {
                            // Navigate to FriendChatroomPage and await result
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FriendChatroomPage(
                                  chatroomId: chatroom['id'],
                                  friendName: friendName,
                                  userId: widget.userId,
                                ),
                              ),
                            );
                            
                            // Process the result when coming back
                            if (result != null && result is Map<String, dynamic> && result['updated'] == true) {
                              print("📱 Received update from FriendChatroom: $result");
                              
                              // Create an updates map with the valid fields
                              Map<String, dynamic> updates = {};
                              
                              if (result['lastMessage'] != null) {
                                updates['lastMessage'] = result['lastMessage'];
                              }
                              
                              if (result['lastMessageTime'] != null) {
                                updates['lastMessageTime'] = result['lastMessageTime'];
                              }
                              
                              if (result['otherUserId'] != null && result['anonymousUsername'] != null) {
                                updates['otherUserId'] = result['otherUserId'];
                                updates['anonymousUsername'] = result['anonymousUsername'];
                              }
                              
                              // Update the cached chatroom
                              if (updates.isNotEmpty) {
                                updateCachedChatroom(chatroom['id'], updates);
                              }
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
          bottomNavigationBar: BottomNavWidget(
            selectedIndex: _selectedIndex,
            onItemTapped: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            userId: widget.userId,
          ),
        ),
      ],
    );
  }
}
