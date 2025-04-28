import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starry_match/localization/app_localizations.dart';
import 'package:starry_match/theme/AppThemeExtension.dart';
import 'recommendlist.dart';
import 'CriteriaSelection.dart';

class ChatTypeSelectionPage extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> userData;
  final String userPersonalityResult;
  final String chatType;
  final String personalityCategory;
  const ChatTypeSelectionPage({
    super.key,
    required this.userId,
    required this.userData,
    required this.userPersonalityResult,
    required this.chatType,
    required this.personalityCategory,
  });

  @override
  State<ChatTypeSelectionPage> createState() => _ChatTypeSelectionPageState();
}

class _ChatTypeSelectionPageState extends State<ChatTypeSelectionPage> {
  String languageCode = "en"; // Default to English
  
  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      languageCode = prefs.getString('language') ?? "en";
    });
  }

  Future<List<String>> fetchRecommendedPersonalities() async {
    try {
      // Determine which collection to use based on language
      String collectionName = languageCode == "th" 
          ? 'starrymatch_th_recommend_personality' 
          : 'starrymatch_recommend_personality';
          
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection(collectionName)
          .where('PersonalityType', isEqualTo: widget.userPersonalityResult)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data() as Map<String, dynamic>;
        List<String> recommended = [];

        // Determine if it's MBTI or Enneagram based on the personality type
        bool isMBTI = widget.userPersonalityResult.length == 4; // MBTI types are 4 characters

        // Set the target number of recommendations
        int targetCount = isMBTI ? 8 : 5;

        for (var category in ['Best', 'Good', 'Neutral']) {
          if (data.containsKey(category) && data[category] != null && data[category]['Matches'] != null) {
            List<String> matches = List<String>.from(data[category]['Matches']);
            recommended.addAll(matches);
          }
          if (recommended.length >= targetCount) break;
        }
        return recommended.take(targetCount).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeExt = Theme.of(context).extension<AppThemeExtension>();
    final bgImage = themeExt?.bgMain ?? 'assets/bg_pastel_main.jpg';
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.translate("select_chat_type_title"))),
      body:Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(bgImage), // Ensure the image is in assets folder
                fit: BoxFit.cover,
              ),
            ),
          ), 
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             Text(AppLocalizations.of(context)!.translate("start_chat_chattype"),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            buildChatButton(
              context,
              title: AppLocalizations.of(context)!.translate("start_chat_private"),
              color: const Color.fromARGB(220, 240, 166, 38),
              textColor: const Color.fromARGB(255, 126, 95, 2),
              icon: Icons.group,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RecommendationListPage(
                      userId: widget.userId,
                      userPersonalityType: widget.userPersonalityResult,
                      chatType: "Private",
                      personalityCategory: widget.personalityCategory,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            buildChatButton(
              context,
              title: AppLocalizations.of(context)!.translate("start_chat_group"),
              color: const Color.fromARGB(220, 147, 76, 166),
              textColor: const Color.fromARGB(255, 246, 220, 255),
              icon: Icons.groups_2,
              onPressed: () async {
                List<String> selectedPersonalities = await fetchRecommendedPersonalities();
                if (selectedPersonalities.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context)!.translate("no_recommendations_group"))),
                  );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CriteriaSelectionPage(
                      userId: widget.userId,
                      userPersonalityType: widget.userPersonalityResult,
                      selectedPersonality: selectedPersonalities.join(", "),
                      matchType: "Group",
                      chatType: "Group",
                      personalityCategory: widget.personalityCategory,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
        ]
      ),
    );
  }

  Widget buildChatButton(
    BuildContext context, {
    required String title,
    required Color color,
    required Color textColor,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(2, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: textColor),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
