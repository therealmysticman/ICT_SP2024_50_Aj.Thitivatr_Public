import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starry_match/Result.dart';
import 'package:starry_match/localization/app_localizations.dart';
import 'package:starry_match/services/question_services.dart';
import 'package:starry_match/theme/AppThemeExtension.dart';
import 'package:starry_match/widgets/star_selection_widget.dart';
import 'package:starry_match/services/userpersonality_services.dart';

class MBTITestPage extends StatefulWidget {
  final String userId;

  const MBTITestPage({super.key, required this.userId});

  @override
  _MBTITestPageState createState() => _MBTITestPageState();
}

class _MBTITestPageState extends State<MBTITestPage> {
  List<Map<String, dynamic>> questions = [];
  final Map<int, int> weightMap = {0: 2, 1: 1, 2: 0, 3: -1, 4: -2};
  Map<String, int> userResponses = {};
  bool isLoading = true;
  int currentPage = 0;
  final int questionsPerPage = 7;
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
        await questionService.fetchQuestions("MBTI");
    setState(() {
      questions = fetchedQuestions;
      isLoading = false;
    });
  }

  void _nextPage() {
    if (currentPage < (questions.length / questionsPerPage).ceil() - 1) {
      setState(() {
        currentPage++;
        _scrollController.jumpTo(0.0);
      });
    } else {
      _calculateMBTI();
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

  void _calculateMBTI() {
    if (userResponses.length < questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.translate("please_answer_all"))),
      );
      return;
    }

    double scoreE = 0, scoreI = 0, scoreS = 0, scoreN = 0, scoreT = 0, scoreF = 0, scoreJ = 0, scoreP = 0;

    userResponses.forEach((questionId, selectedIndex) {
      int weight = weightMap[selectedIndex]!;
      var question = questions.firstWhere((q) => q['QuestionID'] == questionId);
      String questionType = question['QuestionType'];
      String priority = question['Priority'];

      switch (questionType) {
        case 'Introvert vs Extrovert':
          priority == 'Extrovert' ? scoreE += weight : scoreI += weight;
          break;
        case 'Sensing vs Intuition':
          priority == 'Sensing' ? scoreS += weight : scoreN += weight;
          break;
        case 'Feeling vs Thinking':
          priority == 'Thinking' ? scoreT += weight : scoreF += weight;
          break;
        case 'Perceiving vs Judging':
          priority == 'Judging' ? scoreJ += weight : scoreP += weight;
          break;
      }
    });

    if (scoreE == scoreI && scoreS == scoreN && scoreT == scoreF && scoreJ == scoreP) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.translate("answers_too_balanced"))),
      );
      return;
    }

    String mbti = '';
    mbti += (scoreE > scoreI) ? 'E' : 'I';
    mbti += (scoreS > scoreN) ? 'S' : 'N';
    mbti += (scoreT > scoreF) ? 'T' : 'F';
    mbti += (scoreJ > scoreP) ? 'J' : 'P';

    UserPersonalityService userpersonaService = UserPersonalityService();
    userpersonaService.updateTestResult(userId: widget.userId, mbtiType: mbti);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultPage(
          userId: widget.userId,
          testResult: mbti,
          testType: "MBTI",
        ),
      ),
    );
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
    final bgImage = themeExt?.bgMbti?? 'assets/bg_pastel_mbti.jpg';
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.translate("mbti_test"))),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(bgImage),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            // Title Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
              child: Column(
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Arial',
                        color: Colors.black,
                      ),
                       children: languageCode == "th"
                          ? [
                              TextSpan(text: "เรื่องราวของ ", style: TextStyle(color: Theme.of(context).colorScheme.onTertiary, fontFamily: "MainFonts")),
                              TextSpan(text: "Myer ", style: TextStyle(color: Theme.of(context).colorScheme.onSecondary, fontFamily: "MainFonts")),
                              const TextSpan(text: "Briggs", style: TextStyle(color: Color.fromARGB(255, 255, 223, 150), fontFamily: "MainFonts")),
                            ]
                          : [
                              TextSpan(text: "Myer ", style: TextStyle(color: Theme.of(context).colorScheme.onTertiary, fontFamily: "MainFonts")),
                              TextSpan(text: "Briggs", style: TextStyle(color: Theme.of(context).colorScheme.onSecondary, fontFamily: "MainFonts")),
                              const TextSpan(text: " Story", style: TextStyle(color: Color.fromARGB(255, 255, 223, 150), fontFamily: "MainFonts")),
                            ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      AppLocalizations.of(context)!.translate("mbti_desc"),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        color:  Theme.of(context).colorScheme.onTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!isLoading && questions.isNotEmpty)
                    LinearProgressIndicator(
                      value: (currentPage + 1) / (questions.length / questionsPerPage).ceil(),
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(Color.fromARGB(255, 255, 207, 47)),
                      minHeight: 8,
                    ),
                  if (!isLoading && questions.isNotEmpty)
                    Text(
                      '${currentPage + 1}/${(questions.length / questionsPerPage).ceil()}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onTertiary,
                      ),
                    ),
                  if (isLoading)
                    const CircularProgressIndicator(),
                ],
              ),
            ),

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
                      backgroundColor: const Color.fromARGB(255, 153, 126, 227),
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
