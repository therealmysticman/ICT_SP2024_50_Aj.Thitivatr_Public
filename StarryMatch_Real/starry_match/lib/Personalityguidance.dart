import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starry_match/localization/app_localizations.dart';
import 'package:starry_match/theme/AppThemeExtension.dart';

class PersonalityGuidancePage extends StatelessWidget {
  final String personalityType;

  const PersonalityGuidancePage({super.key, required this.personalityType});

  Future<Map<String, dynamic>?> fetchPersonalityData() async {
    try {
      // Get user's language preference
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String languageCode =
          prefs.getString('language') ?? 'en'; // Default to English

      // Choose the correct collection based on the language
      String collectionName = (languageCode == 'th')
          ? 'starrymatch_th_personality_info'
          : 'starrymatch_personality_info';

      final querySnapshot = await FirebaseFirestore.instance
          .collection(collectionName)
          .where('PersonalityType', isEqualTo: personalityType)
          .where('DescriptionType', whereIn: ['Enneagram', 'MBTI']).get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      } else {
        debugPrint('No documents found for $personalityType');
      }
    } catch (e) {
      debugPrint('❌ Error fetching personality data: $e');
    }
    return null;
  }

  String getImagePath(Map<String, dynamic> data) {
    String descriptionType = data['DescriptionType'];

    if (descriptionType == 'Enneagram') {
      return 'assets/Enneagram_Art/$personalityType.png';
    } else {
      return 'assets/MBTI_Art/${getMBTICategory(personalityType)}/$personalityType.png';
    }
  }

  String getMBTICategory(String type) {
    const Map<String, String> categories = {
      'ENTP': 'Analysts',
      'ENTJ': 'Analysts',
      'INTP': 'Analysts',
      'INTJ': 'Analysts',
      'ISFJ': 'Sentinels',
      'ESFJ': 'Sentinels',
      'ESTJ': 'Sentinels',
      'ISTJ': 'Sentinels',
      'ESFP': 'Explorers',
      'ISFP': 'Explorers',
      'ESTP': 'Explorers',
      'ISTP': 'Explorers',
      'ENFP': 'Diplomats',
      'ENFJ': 'Diplomats',
      'INFP': 'Diplomats',
      'INFJ': 'Diplomats',
    };
    return categories[type] ?? 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    final themeExt = Theme.of(context).extension<AppThemeExtension>();
    final bgImage = themeExt?.bgGuidance ?? 'assets/bg_pastel_guidance.jpg';
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!
            .translate("guidance_title", args: [personalityType])),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // ✅ Full-Screen Background
          Container(
            constraints: const BoxConstraints.expand(),
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(bgImage),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // ✅ Content
          FutureBuilder<Map<String, dynamic>?>(
            future: fetchPersonalityData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child:
                      Text(AppLocalizations.of(context)!.translate("loading")),
                );
              }
              if (snapshot.hasError || snapshot.data == null) {
                return Center(
                  child: Text(
                    AppLocalizations.of(context)!
                        .translate("no_data_found", args: [personalityType]),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                );
              }

              var data = snapshot.data!;
              String imagePath = getImagePath(data);

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 100),

                    // ✅ Centered Personality Name
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        data['PersonalityName'] ??
                            AppLocalizations.of(context)!.translate("unknown"),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onTertiary,
                          decoration: TextDecoration.underline,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    // ✅ Personality Image (Larger & Centered)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Image.asset(
                        imagePath,
                        width: 220,
                        height: 220,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint(
                              '⚠️ Image load error: $error for path: $imagePath');
                          return const Icon(Icons.image_not_supported,
                              size: 100, color: Colors.grey);
                        },
                      ),
                    ),

                    // ✅ Personality Description (Localized)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:
                              Colors.white.withOpacity(0.6), // ✅ ปรับโปร่งใสได้
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          data['PersonalityDescriptions'] ??
                              AppLocalizations.of(context)!
                                  .translate("no_description"),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
