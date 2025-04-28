import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:starry_match/CoinsPurchase.dart';
import 'package:starry_match/PlasmaPurchase.dart';
import 'package:starry_match/theme/AppThemeExtension.dart';
import 'package:starry_match/widgets/bottomnav_widget.dart';
import 'package:starry_match/localization/app_localizations.dart';
import 'package:starry_match/Notifications.dart';
import 'chatselection.dart';
import 'package:starry_match/widgets/online_users_widget.dart';

class HomePage extends StatefulWidget {
  final String userId;

  const HomePage({super.key, required this.userId});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  Map<String, dynamic> userData = {};
  bool isDataLoaded = false;
  final TextEditingController _usernameController = TextEditingController();
  late FocusNode _pageFocusNode;

  @override
  void initState() {
    super.initState();
    // Initialize a focus node for the page
    _pageFocusNode = FocusNode();
    // Register for app lifecycle events
    WidgetsBinding.instance.addObserver(this);
    _fetchUserData();
  }

  @override
  void dispose() {
    // Clean up the focus node and observer
    _pageFocusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh data when app resumes
    if (state == AppLifecycleState.resumed) {
      _fetchUserData();
    }
  }

  // Override didChangeDependencies to set up a post-frame callback
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // This ensures we refresh when returning to this route
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchUserData();
      }
    });
  }

  Future<void> _fetchUserData() async {
    try {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('starrymatch_user')
          .doc(widget.userId)
          .get();

      if (snapshot.exists && mounted) {
        setState(() {
          userData = snapshot.data() as Map<String, dynamic>;
          isDataLoaded = true;
        });
      }
    } catch (e) {
      print("Error fetching user data: $e");
    }
  }

  // ✅ Function to update username in Firestore
  void _updateUsername() async {
    if (_usernameController.text.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('starrymatch_user')
          .doc(widget.userId)
          .update({
        'AnnonymousUsername': _usernameController.text,
      });
      _fetchUserData(); // Refresh UI
      Navigator.pop(context);
    }
  }

  // ✅ Function to show a dialog for username update
  void _showUsernameDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.translate("set_username")),
        content: TextField(
          controller: _usernameController,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.translate("enter_username"),
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.translate("cancel")),
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: _updateUsername,
            child: Text(AppLocalizations.of(context)!.translate("save")),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeExt = Theme.of(context).extension<AppThemeExtension>();
    final bgImage = themeExt?.bgHome ?? 'assets/bg_pastel_home.jpg';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.translate("home_page"),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.notifications, color: Theme.of(context).colorScheme.onSurface),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NotificationPage(userId: widget.userId),
                    ),
                  );
                },
              ),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('starrymatch_notifications')
                    .where('userId', isEqualTo: widget.userId)
                    .where('isRead', isEqualTo: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  
                  final unreadCount = snapshot.data!.docs.length;
                  
                  return Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
      
      body: Stack(
        children: [
          // ✅ Background Image (Covers the entire screen)
          Positioned.fill(
            
            child: Image.asset(
              bgImage,
              fit: BoxFit.cover,
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                Expanded( // ✅ Makes sure content fills the screen properly
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 1), // ✅ Push content down

                          // ✅ Coin and Plasma section (moved above the logo)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Coin section
                              GestureDetector(
                                onTap: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => CoinsPurchasePage(userId: widget.userId)),
                                  );
                                  
                                  if (result == true || result == null) {
                                    _fetchUserData();
                                  }
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset("assets/Coin/Starry Coin.png", width: 30, height: 30),
                                    const SizedBox(width: 8),
                                    Text("${userData['StarryCoin'] ?? 0}", 
                                      style: TextStyle(
                                        fontSize: 18, 
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(width: 15),
                              
                              // Plasma section
                              GestureDetector(
                                onTap: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => PlasmaPurchasePage(userId: widget.userId)),
                                  );
                                  
                                  if (result == true || result == null) {
                                    _fetchUserData();
                                  }
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset("assets/Coin/Starry Plasma.png", width: 30, height: 30),
                                    const SizedBox(width: 8),
                                    Text("${userData['StarryPlasma'] ?? 0}", 
                                      style: TextStyle(
                                        fontSize: 18, 
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 1),

                          // Logo at the top (moved from below)
                          Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 20,),
                            child: Image.asset(
                              themeExt?.logo2 ?? 'assets/logo_sub.png',
                              width: double.infinity,
                              height: 150,
                              fit: BoxFit.contain,
                            ),
                          ),
                          
                          // ✅ Online Users Widget
                          const Center(child: OnlineUsersWidget()),
                          const SizedBox(height: 10),
                          
                          // ✅ Avatar + Username with Coin & Plasma on right side
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              // Avatar and username in center
                              Column(
                                children: [
                                  GestureDetector(
                                    onTap: _showUsernameDialog,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: Theme.of(context).colorScheme.primary,
                                          radius: 50,
                                          backgroundImage: AssetImage(
                                            'assets/Avatar/Skin/${userData['UserAvatar']?['selectedSkin'] ?? 'Travel light'}.png',
                                          ),
                                        ),
                                        if (userData['UserAvatar']?['selectedHat'] != "")
                                          Positioned(
                                            child: Image.asset(
                                              'assets/Avatar/Decoration/Accessories/${userData['UserAvatar']?['selectedHat'] ?? 'default_hat'}.png',
                                              width: 100,
                                            ),
                                          ),
                                        if (userData['UserAvatar']?['selectedClothes'] != "")
                                          Positioned(
                                            child: Image.asset(
                                              'assets/Avatar/Decoration/Clothing/${userData['UserAvatar']?['selectedClothes'] ?? 'default_clothes'}.png',
                                              width: 100,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.secondary,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      "${AppLocalizations.of(context)!.translate("hello")}, ${userData['AnnonymousUsername'] ?? 'User'}!",
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.tertiary),
                                    ),
                                  ),
                                ],
                              ),
                              
                              // Coin & Plasma positioned on the right side
                              Positioned(
                                right: 10,
                                top: 15,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    // Coin section - EMPTY, content moved to above
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 30),

                          // ✅ Start Chat Button
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatSelectionPage(
                                    userData: userData,
                                    userId: widget.userId,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                               backgroundColor: Theme.of(context).colorScheme.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            icon: Icon(Icons.chat,  color: Theme.of(context)
                      .colorScheme
                      .onPrimary,),
                            label: Text(
                              AppLocalizations.of(context)!.translate("start_chat"),
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      bottomNavigationBar: BottomNavWidget(
        selectedIndex: 0,
        onItemTapped: (index) {
          setState(() {});
        },
        userId: widget.userId,
      ),
    );
  }
}
