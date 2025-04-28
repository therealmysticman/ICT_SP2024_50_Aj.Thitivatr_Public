import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:starry_match/home.dart';
import 'package:starry_match/services/userpersonality_services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starry_match/localization/app_localizations.dart';
import 'package:starry_match/theme/AppThemeExtension.dart';

class ResultPage extends StatefulWidget {
  final String userId;
  final String testResult;
  final String testType;

  const ResultPage({super.key, required this.userId, required this.testResult, required this.testType});

  @override
  _ResultPageState createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  String description = "";
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
      _fetchPersonalityDescription();
    });
  }
  
  Future<void> _fetchPersonalityDescription() async {
    try {
      // Determine which collection to use based on language
      String collectionName = languageCode == "th" 
          ? 'starrymatch_th_personality_info' 
          : 'starrymatch_personality_info';
          
      var querySnapshot = await FirebaseFirestore.instance
          .collection(collectionName)
          .where('PersonalityType', isEqualTo: widget.testResult) // Query by PersonalityType
          .limit(1) // Only fetch the first match
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          description = querySnapshot.docs.first.data()['PersonalityDescriptions'] ?? "No description available.";
        });
      } else {
        setState(() {
          description = languageCode == "th" 
              ? "ไม่พบข้อมูลสำหรับประเภทบุคลิกภาพนี้" 
              : "No description found for this personality type.";
        });
      }
    } catch (e) {
      setState(() {
        description = languageCode == "th" 
            ? "ไม่สามารถโหลดข้อมูลบุคลิกภาพได้" 
            : "Failed to load personality description.";
      });
    }
  }

  String _getImageForResult(String result) {
    Map<String, String> images = widget.testType == 'MBTI' ? {
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
    } : {
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
    return images[result] ?? 'assets/default_persona_image.png';
  }

  Future<void> _sendResultToFirestore() async {
    UserPersonalityService userPersonalityService = UserPersonalityService();
    if (widget.testType == 'MBTI') {
      await userPersonalityService.updateTestResult(userId: widget.userId, mbtiType: widget.testResult);
    } else if (widget.testType == 'Enneagram') {
      await userPersonalityService.updateTestResult(userId: widget.userId, enneagramType: widget.testResult);
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    String imagePath = _getImageForResult(widget.testResult);
    
    // Get theme colors
    final themeExt = Theme.of(context).extension<AppThemeExtension>();
    final bgImage = widget.testType == 'MBTI' 
        ? (themeExt?.bgMbti ?? 'assets/bg_pastel_mbti.jpg')
        : (themeExt?.bgEnneagram ?? 'assets/bg_pastel_enneagram.jpg');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageCode == "th"
              ? '${widget.testType} ผลการทดสอบ'
              : '${widget.testType} Test Result',
          style: const TextStyle(
            shadows: [
              Shadow(
                blurRadius: 4.0,
                color: Colors.black38,
                offset: Offset(2, 2),
              ),
            ],
          ),
        ),
      ),
      body: Container(
        width: screenWidth,
        height: screenHeight,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(bgImage),
            fit: BoxFit.cover, // Ensures full background
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // Centers content
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(imagePath, width: 250, height: 250),
                const SizedBox(height: 16),
                Text(
                  languageCode == "th"
                      ? "คุณคือ ${widget.testResult}!"
                      : "You're ${widget.testResult}!",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    shadows: const [
                      Shadow(
                        blurRadius: 4.0,
                        color: Colors.black38,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                description.isEmpty
                    ? CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.onSurface,
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            color: Theme.of(context).colorScheme.onSurface,
                            shadows: const [
                              Shadow(
                                blurRadius: 4.0,
                                color: Colors.black38,
                                offset: Offset(2, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () async {
                    await _sendResultToFirestore();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => HomePage(userId: widget.userId)),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    languageCode == "th" ? 'บันทึกผล' : 'Save Result',
                    style: const TextStyle(
                      fontSize: 16,
                      shadows: [
                        Shadow(
                          blurRadius: 4.0,
                          color: Colors.black38,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
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
