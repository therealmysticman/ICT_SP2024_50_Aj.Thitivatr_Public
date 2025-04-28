import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starry_match/Result.dart';
import 'package:starry_match/localization/app_localizations.dart';
import 'package:starry_match/services/question_services.dart';
import 'package:starry_match/theme/AppThemeExtension.dart';
import 'package:starry_match/widgets/star_selection_widget.dart';
import 'package:starry_match/services/userpersonality_services.dart';

class EnneagramTestPage extends StatefulWidget {
  final String userId;

  const EnneagramTestPage({super.key, required this.userId});

  @override
  _EnneagramTestPageState createState() => _EnneagramTestPageState();
}

class _EnneagramTestPageState extends State<EnneagramTestPage> {
  List<Map<String, dynamic>> questions = [];
  final Map<int, int> weightMap = {
    0: 2, // Totally Agree
    1: 1, // Agree
    2: 0, // Neutral
    3: -1, // Disagree
    4: -2 // Totally Disagree
  };
  Map<String, int> userResponses = {}; // Store responses with unique QuestionID
  bool isLoading = true;
  int currentPage = 0; // Current page index
  final int questionsPerPage = 7; // Number of questions per page
  final ScrollController _scrollController = ScrollController();
   String languageCode = "en"; // Default to English

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _loadQuestions();
  }

Future<void> _loadLanguage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      languageCode = prefs.getString('language') ?? "en";
    });
  }

  Future<void> _loadQuestions() async {
    QuestionService questionService = QuestionService();
    List<Map<String, dynamic>> fetchedQuestions =
        await questionService.fetchQuestions("Enneagram");

    setState(() {
      questions = fetchedQuestions;
      isLoading = false;
    });
  }

  void _calculateEnneagram() {
    // Check if all questions have been answered
    if (userResponses.length < questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!.translate("please_answer_all"))),
      );
      return; // Stop further execution
    }

    Map<String, double> scores = {
      'Type1': 0,
      'Type2': 0,
      'Type3': 0,
      'Type4': 0,
      'Type5': 0,
      'Type6': 0,
      'Type7': 0,
      'Type8': 0,
      'Type9': 0,
    };

    // Calculate scores based on user responses
    userResponses.forEach((questionId, selectedIndex) {
      int weight = weightMap[selectedIndex]!;
      var question = questions.firstWhere(
        (q) => q['QuestionID'] == questionId,
      );

      String questionType = question['QuestionType'];

      // Add the weight to the appropriate type score
      scores[questionType] = (scores[questionType] ?? 0) + weight;
    });

    // Check if all scores are too balanced (i.e., equal)
    if (scores.values.every((score) => score == scores.values.first)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!.translate("answers_too_balanced"))),
      );
      return; // Stop if the test is too balanced
    }

    // Print scores for each Enneagram type
    scores.forEach((type, score) {
      print("Score for $type: $score");
    });
    // Check if there are multiple types with the same highest score
    double highestScore = scores.values.reduce((a, b) => a > b ? a : b);
    List<String> highestScoringTypes = scores.entries
        .where((entry) => entry.value == highestScore)
        .map((entry) => entry.key)
        .toList();

    if (highestScoringTypes.length > 1) {
      // If multiple types have the same highest score, show the "too balanced" message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!.translate("answers_too_balanced"))),
      );
      return;
    }

    // If only one type has the highest score, set that as the result
    String enneagramType = highestScoringTypes.first;

    // Save result to Firebase
    UserPersonalityService userpersonaService = UserPersonalityService();
    userpersonaService.updateTestResult(
      userId: widget.userId,
      enneagramType: enneagramType,
    );

    // Show result
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultPage(
          userId: widget.userId,
          testResult: enneagramType, // Pass Enneagram result directly
          testType: "Enneagram",
        ),
      ),
    );
  }

  void _nextPage() {
    if (currentPage < (questions.length / questionsPerPage).ceil() - 1) {
      setState(() {
        currentPage++;
         _scrollController.jumpTo(0.0);
      });
    } else {
      _calculateEnneagram(); // On the last page, calculate the Enneagram result
    }
  }

  void _previousPage() {
    if (currentPage > 0) {
      setState(() {
        currentPage--;
         _scrollController.jumpTo(0.0);
      });
    }
  }

@override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;
    final fontSize = isSmallScreen ? 14.0 : 16.0;
    final headerFontSize = isSmallScreen ? 24.0 : 28.0;
    final cardPadding = isSmallScreen ? 12.0 : 16.0;
    
    final startIndex = currentPage * questionsPerPage;
    final endIndex = (startIndex + questionsPerPage).clamp(0, questions.length);
    final currentQuestions = questions.sublist(startIndex, endIndex);
    final themeExt = Theme.of(context).extension<AppThemeExtension>();
    final bgImage = themeExt?.bgEnneagram ?? 'assets/bg_pastel_enneagram.jpg';

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.translate("enne_test"))),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(bgImage),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Column(
              children: [
                 RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: headerFontSize,
                      fontWeight: FontWeight.bold,
                      shadows: const [
                        Shadow(blurRadius: 4.0, color: Colors.black38, offset: Offset(2, 2)),
                      ],
                    ),
                    children: languageCode == "th"
                        ? [
                            const TextSpan(text: "เรื่องราวของ ", style: TextStyle(color: Color.fromARGB(255, 255, 161, 19), fontFamily: "MainFonts")),
                            const TextSpan(text: "Enne", style: TextStyle(color: Color.fromARGB(255, 255, 208, 77), fontFamily: "MainFonts")),
                            const TextSpan(text: "a", style: TextStyle(color: Color.fromARGB(255, 255, 229, 169), fontFamily: "MainFonts")),
                            const TextSpan(text: "gram", style: TextStyle(color: Colors.white, fontFamily: "MainFonts")),
                          ]
                        : [
                            const TextSpan(text: "Enne", style: TextStyle(color: Color.fromARGB(255, 255, 161, 19), fontFamily: "MainFonts")),
                            const TextSpan(text: "a", style: TextStyle(color: Color.fromARGB(255, 255, 208, 77), fontFamily: "MainFonts")),
                            const TextSpan(text: "gram", style: TextStyle(color: Color.fromARGB(255, 255, 229, 169),  fontFamily: "MainFonts")),
                            const TextSpan(text: " Story", style: TextStyle(color: Colors.white, fontFamily: "MainFonts")),
                          ],
                  ),
                ),
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    AppLocalizations.of(context)!.translate("enne_desc"),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      shadows: const [
                        Shadow(blurRadius: 4.0, color: Colors.black54, offset: Offset(2, 2)),
                      ]
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (!isLoading && questions.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        LinearProgressIndicator(
                          value: (currentPage + 1) / (questions.length / questionsPerPage).ceil(),
                          backgroundColor: Colors.white.withOpacity(0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color.fromARGB(255, 130, 58, 163)),
                          minHeight: 8,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${currentPage + 1}/${(questions.length / questionsPerPage).ceil()}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            shadows: [
                              Shadow(blurRadius: 2.0, color: Colors.black54, offset: Offset(1, 1)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (isLoading)
                  const CircularProgressIndicator(),
              ],
            ),

          const SizedBox(height: 10),

          Expanded(
           child: Scrollbar(
                controller: _scrollController,
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: currentQuestions.length,
                  itemBuilder: (context, index) {
                    var question = currentQuestions[index];
                    return Card(
                      color: Theme.of(context).colorScheme.surface,
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: EdgeInsets.all(cardPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              question['QuestionDescriptions'],
                              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            StarSelectionWidget(
                              questionId: question['QuestionID'],
                              selectedIndex: userResponses[question['QuestionID']] ?? -1,
                              choice1: question['Choice1'] ?? '',
                              choice3: question['Choice3'] ?? '',
                              choice5: question['Choice5'] ?? '',
                              onStarSelected: (selectedIndex) {
                                setState(() {
                                  userResponses[question['QuestionID']] = selectedIndex;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: currentPage > 0 ? _previousPage : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.translate("previous"),
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                  ),
                ),
                ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    currentPage == (questions.length / questionsPerPage).ceil() - 1
                        ? AppLocalizations.of(context)!.translate("finish")
                        : AppLocalizations.of(context)!.translate("next"),
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}



}
