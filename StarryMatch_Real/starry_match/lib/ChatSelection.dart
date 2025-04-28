import 'package:flutter/material.dart';
import 'package:starry_match/ChatTypeSelection.dart';
import 'package:starry_match/localization/app_localizations.dart';
import 'package:starry_match/theme/AppThemeExtension.dart';
import 'package:starry_match/widgets/selection_card_widget.dart'; // ✅ Import SelectionCard

class ChatSelectionPage extends StatelessWidget {
  final String userId;
  final Map<String, dynamic> userData;

  const ChatSelectionPage(
      {super.key, required this.userData, required this.userId});

  /// **Show Warning if User Hasn't Taken the Test**
  void _showWarningDialog(BuildContext context, String testType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Access Denied"),
        content: Text(
          AppLocalizations.of(context)!
              .translate("start_chat_not_allowed", args: [testType]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: Text(AppLocalizations.of(context)!.translate('ok')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeExt = Theme.of(context).extension<AppThemeExtension>();
    final bgImage = themeExt?.bgMain ?? 'assets/bg_pastel_main.jpg';
    return Scaffold(
      extendBodyBehindAppBar: true, // ✅ Extend background under AppBar
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.translate("start_chat_header"),
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent, // ✅ Transparent AppBar
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // ✅ Background Image
          Positioned.fill(
            child: Image.asset(
              bgImage, // ✅ Use your background image
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ✅ **Title with Shadow Effect**
                Text(
                  AppLocalizations.of(context)!.translate("start_chat_title"),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        blurRadius: 3.0,
                        color: Colors.black54,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // ✅ **Myer-Briggs Selection**
                SelectionCard(
                  title: AppLocalizations.of(context)!
                      .translate("start_chat_mbti"),
                  imagePath: "assets/MBTI_Art/Explorers/ESTP.png",
                  onTap: () {
                    String mbtiType = userData['MBTITypes'] ?? '-';
                    if (mbtiType == "-") {
                      _showWarningDialog(context, "MBTI");
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatTypeSelectionPage(
                          userId: userId,
                          userData: userData,
                          userPersonalityResult: mbtiType,
                          personalityCategory: "MBTI",
                          chatType: "",
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // ✅ **Enneagram Selection**
                SelectionCard(
                  title: AppLocalizations.of(context)!
                      .translate("start_chat_enne"),
                  imagePath: "assets/Enneagram_Art/Type5.png",
                  onTap: () {
                    String enneagramType = userData['EnneagramTypes'] ?? '-';
                    if (enneagramType == "-") {
                      _showWarningDialog(context, "Enneagram");
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatTypeSelectionPage(
                          userId: userId,
                          userData: userData,
                          userPersonalityResult: enneagramType,
                          personalityCategory: "Enneagram",
                          chatType: "",
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
