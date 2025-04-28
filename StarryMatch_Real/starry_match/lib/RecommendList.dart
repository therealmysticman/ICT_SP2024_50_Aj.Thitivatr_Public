import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:starry_match/CriteriaSelection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starry_match/localization/app_localizations.dart';

class RecommendationListPage extends StatefulWidget {
  final String userPersonalityType;
  final String userId;
  final String chatType;
  final String personalityCategory;

  const RecommendationListPage({
    super.key,
    required this.userPersonalityType,
    required this.userId,
    required this.chatType,
    required this.personalityCategory,
  });

  @override
  State<RecommendationListPage> createState() => _RecommendationListPageState();
}

class _RecommendationListPageState extends State<RecommendationListPage> {
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

  final Map<String, String> mbtiImages = {
    'ENTP': 'assets/MBTI_Art/Analysts/ENTP.png',
    'ENTJ': 'assets/MBTI_Art/Analysts/ENTJ.png',
    'INTP': 'assets/MBTI_Art/Analysts/INTP.png',
    'INTJ': 'assets/MBTI_Art/Analysts/INTJ.png',
    'ISFJ': 'assets/MBTI_Art/Sentinels/ISFJ.png',
    'ESFJ': 'assets/MBTI_Art/Sentinels/ESFJ.png',
    'ESTJ': 'assets/MBTI_Art/Sentinels/ESTJ.png',
    'ISTJ': 'assets/MBTI_Art/Sentinels/ISTJ.png',
    'ESFP': 'assets/MBTI_Art/Explorers/ESFP.png',
    'ISFP': 'assets/MBTI_Art/Explorers/ISFP.png',
    'ESTP': 'assets/MBTI_Art/Explorers/ESTP.png',
    'ISTP': 'assets/MBTI_Art/Explorers/ISTP.png',
    'ENFP': 'assets/MBTI_Art/Diplomats/ENFP.png',
    'ENFJ': 'assets/MBTI_Art/Diplomats/ENFJ.png',
    'INFP': 'assets/MBTI_Art/Diplomats/INFP.png',
    'INFJ': 'assets/MBTI_Art/Diplomats/INFJ.png',
  };

  final Map<String, String> enneagramImages = {
    'Type1': 'assets/Enneagram_Art/Type1.png',
    'Type2': 'assets/Enneagram_Art/Type2.png',
    'Type3': 'assets/Enneagram_Art/Type3.png',
    'Type4': 'assets/Enneagram_Art/Type4.png',
    'Type5': 'assets/Enneagram_Art/Type5.png',
    'Type6': 'assets/Enneagram_Art/Type6.png',
    'Type7': 'assets/Enneagram_Art/Type7.png',
    'Type8': 'assets/Enneagram_Art/Type8.png',
    'Type9': 'assets/Enneagram_Art/Type9.png',
  };

  Future<List<Map<String, dynamic>>> fetchRecommendations() async {
    // Determine which collection to use based on language
    String collectionName = languageCode == "th" 
        ? 'starrymatch_th_recommend_personality' 
        : 'starrymatch_recommend_personality';
    
    final QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection(collectionName)
        .where('PersonalityType', isEqualTo: widget.userPersonalityType)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data() as Map<String, dynamic>;
      List<Map<String, dynamic>> recommendations = [];

      for (var category in ['Best', 'Good', 'Neutral', 'Bad', 'Worst']) {
        if (data[category] != null) {
          List<String> matches =
              List<String>.from(data[category]['Matches'] ?? []);
          for (String match in matches) {
            recommendations.add({
              'personalityType': match,
              'matchType': category,
              'image': mbtiImages[match] ?? enneagramImages[match] ?? 'assets/MBTI_Art/default.png',
              'description': data[category]['Descriptions'] ?? ''
            });
          }
        }
      }
      return recommendations;
    }
    return [];
  }

  Color _getCompatibilityColor(String matchType) {
    switch (matchType) {
      case 'Best':
        return Colors.green;
      case 'Good':
        return Colors.lightGreen;
      case 'Neutral':
        return Colors.grey;
      case 'Bad':
        return Colors.orange;
      case 'Worst':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _getCompatibilityIcon(String matchType) {
    switch (matchType) {
      case 'Best':
        return Icons.thumb_up;
      case 'Good':
        return Icons.thumb_up_alt_outlined;
      case 'Neutral':
        return Icons.remove;
      case 'Bad':
        return Icons.thumb_down_alt_outlined;
      case 'Worst':
        return Icons.thumb_down;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.translate("recommended_personalities")),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Theme.of(context).colorScheme.secondary.withOpacity(0.1),
            ],
          ),
        ),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: fetchRecommendations(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data!.isEmpty) {
              return Center(child: Text(AppLocalizations.of(context)!.translate("no_recommendations")));
            }

            final recommendations = snapshot.data!;

            return ListView.builder(
              itemCount: recommendations.length,
              itemBuilder: (context, index) {
                final rec = recommendations[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: Image.asset(rec['image'],
                        width: 50, height: 50, fit: BoxFit.cover),
                    title: Text(rec['personalityType'],
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(_getCompatibilityIcon(rec['matchType']),
                                color: _getCompatibilityColor(rec['matchType'])),
                            const SizedBox(width: 8),
                            Text(
                              AppLocalizations.of(context)!.translate(rec['matchType'].toLowerCase()),
                              style: TextStyle(
                                  color: _getCompatibilityColor(rec['matchType']),
                                  fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rec['description'] ?? '',
                          style: const TextStyle(fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CriteriaSelectionPage(
                              userId: widget.userId,
                              userPersonalityType: widget.userPersonalityType,
                              selectedPersonality: rec['personalityType'],
                              matchType: rec['matchType'],
                              chatType: "Private",
                              personalityCategory: widget.personalityCategory,
                            ),
                          ));
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
