import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:starry_match/EnneagramTest.dart';
import 'package:starry_match/MBTITest.dart';
import 'package:starry_match/ProfileEdit.dart';
import 'package:starry_match/Settings.dart';
import 'package:starry_match/theme/AppThemeExtension.dart';
import 'package:starry_match/widgets/bottomnav_widget.dart';
import 'package:starry_match/widgets/inforow_widget.dart';
import 'package:starry_match/localization/app_localizations.dart';
import 'package:starry_match/widgets/simple_inforow_widget.dart';

class DashboardPage extends StatefulWidget {
  final String userId;

  const DashboardPage({super.key, required this.userId});

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<DocumentSnapshot> _userDataFuture;
  int _selectedIndex = 4; // Default selection on Dashboard

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  void _fetchUserData() {
    setState(() {
      _userDataFuture = FirebaseFirestore.instance
          .collection('starrymatch_user')
          .doc(widget.userId)
          .get();
    });
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => SettingsPage(userId: widget.userId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeExt = Theme.of(context).extension<AppThemeExtension>();
    final bgImage = themeExt?.bgDashboard ?? 'assets/bg_pastel_main.jpg';
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.translate("dashboard")),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: Theme.of(context).colorScheme.onSurface),
            onPressed: _openSettings,
          ),
        ],
      ),
      
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(bgImage),
            fit: BoxFit.cover,
          ),
        ),
        child: FutureBuilder<DocumentSnapshot>(
          future: _userDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Text(AppLocalizations.of(context)!.translate("loading")),
              );
            }

            if (snapshot.hasError ||
                !snapshot.hasData ||
                !snapshot.data!.exists) {
              return Center(
                child: Text(AppLocalizations.of(context)!
                    .translate("user_data_not_found")),
              );
            }

            var userData = snapshot.data!.data() as Map<String, dynamic>;

            String username = userData['AnnonymousUsername'] ?? 'Unknown User';
            String realUserId = userData['UserID'] ?? 'N/A';
            String mbtiType = userData['MBTITypes'] ?? '-';
            String enneagramType = userData['EnneagramTypes'] ?? '-';
            int endorsementGet = userData['EndorsementGet'] ?? 0;
            bool showEndorsementBadge = endorsementGet >= 200;

            // ✅ Fetch Selected Avatar Accessories
            String selectedSkin =
                userData['UserAvatar']?['selectedSkin'] ?? 'default_skin';
            String selectedHat = userData['UserAvatar']?['selectedHat'] ?? '';
            String selectedClothes =
                userData['UserAvatar']?['selectedClothes'] ?? '';

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ✅ Tap to Edit Avatar
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditAvatarPage(
                              userId: widget.userId),
                        ),
                      );
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: AssetImage(
                              'assets/Avatar/Skin/$selectedSkin.png'),
                        ),
                        if (selectedHat.isNotEmpty)
                          Positioned(
                            child: Image.asset(
                              'assets/Avatar/Decoration/Accessories/$selectedHat.png',
                              width: 100,
                            ),
                          ),
                        if (selectedClothes.isNotEmpty)
                          Positioned(
                            bottom: 0,
                            child: Image.asset(
                              'assets/Avatar/Decoration/Clothing/$selectedClothes.png',
                              width: 100,
                            ),
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: Theme.of(context).colorScheme.onPrimary,
                            child: Icon(
                              Icons.edit,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ✅ Display Username with Endorsement Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (showEndorsementBadge) ...[
                        GestureDetector(
                          onTap: () {
                            // Show bubble message when badge is tapped
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  AppLocalizations.of(context)!.translate("valuable_user_message"),
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                ),
                                backgroundColor: Theme.of(context).colorScheme.surface,
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          },
                          child: Image.asset(
                            "assets/endorsement_badge.PNG",
                            width: 24,
                            height: 24,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        username,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Text(
                    "${AppLocalizations.of(context)!.translate("user_id")}: $realUserId",
                    style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
                  ),
                  const SizedBox(height: 20),

                  // ✅ MBTI Type
                  InfoRowWidget(
                    title: AppLocalizations.of(context)!.translate("mbti_type"),
                    value: mbtiType,
                    onTestAgain: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                MBTITestPage(userId: widget.userId))),
                  ),

                  // ✅ Enneagram Type
                  InfoRowWidget(
                    title: AppLocalizations.of(context)!
                        .translate("enneagram_type"),
                    value: enneagramType,
                    onTestAgain: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                EnneagramTestPage(userId: widget.userId))),
                  ),

                  // ✅ Endorsement Get
                  SimpleInfoRowWidget(
                    title: AppLocalizations.of(context)!
                        .translate("endorsement_get"),
                    value: endorsementGet.toString(),
                    imagePath: "assets/endorsement_badge.PNG",
                  ),
                ],
              ),
            );
          },
        ),
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
    );
  }
}
