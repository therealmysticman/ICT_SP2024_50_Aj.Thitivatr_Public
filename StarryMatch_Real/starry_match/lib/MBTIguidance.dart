import 'package:flutter/material.dart';
import 'package:starry_match/theme/AppThemeExtension.dart';
import 'personalityguidance.dart';

class MBTIGuidancePage extends StatelessWidget {
  final String userId;

  MBTIGuidancePage({super.key, required this.userId});

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

  final Map<String, List<String>> mbtiCategories = {
    'Analysts': ['ENTP', 'ENTJ', 'INTP', 'INTJ'],
    'Sentinels': ['ISFJ', 'ESFJ', 'ESTJ', 'ISTJ'],
    'Explorers': ['ESFP', 'ISFP', 'ESTP', 'ISTP'],
    'Diplomats': ['ENFP', 'ENFJ', 'INFP', 'INFJ'],
  };

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 600;
    final isVerySmallScreen = screenHeight < 550;
    
    // More aggressive size reduction to fix the 15px overflow
    final crossAxisCount = isVerySmallScreen ? 2 : (isSmallScreen ? 2 : 4);
    final spacing = isVerySmallScreen ? 3.0 : (isSmallScreen ? 5.0 : 10.0);
    final padding = isVerySmallScreen ? 2.0 : (isSmallScreen ? 4.0 : 8.0);
    final titleFontSize = isVerySmallScreen ? 14.0 : (isSmallScreen ? 16.0 : 20.0);
    final childAspectRatio = isVerySmallScreen ? 1.0 : (isSmallScreen ? 0.85 : 0.85);
    final mbtiImageSize = isVerySmallScreen ? 32.0 : (isSmallScreen ? 38.0 : 60.0);
    final mbtiTextSize = isVerySmallScreen ? 10.0 : (isSmallScreen ? 12.0 : 16.0);
    final verticalSpacing = isVerySmallScreen ? 1.0 : (isSmallScreen ? 3.0 : 8.0);
    final categorySpacing = isVerySmallScreen ? 4.0 : (isSmallScreen ? 8.0 : 16.0);
    
    final themeExt = Theme.of(context).extension<AppThemeExtension>();
    final bgImage = themeExt?.bgGuidance ?? 'assets/bg_pastel_guidance.jpg';
    
    return Scaffold(
      appBar: AppBar(title: const Text('MBTI Guidance')),
      body: Container(
        width: screenWidth,
        height: screenHeight,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(bgImage),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: ListView.builder(
            itemCount: mbtiCategories.length,
            shrinkWrap: true,
            itemBuilder: (context, sectionIndex) {
              final category = mbtiCategories.entries.elementAt(sectionIndex);
              return Padding(
                padding: EdgeInsets.only(
                  top: sectionIndex == 0 ? padding : 0,
                  bottom: categorySpacing,
                  left: padding,
                  right: padding
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(bottom: padding / 2),
                      child: Text(
                        category.key,
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: const [
                            Shadow(
                              blurRadius: 3.0,
                              color: Colors.black54,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: spacing,
                        mainAxisSpacing: spacing,
                        childAspectRatio: childAspectRatio,
                      ),
                      itemCount: category.value.length,
                      itemBuilder: (context, index) {
                        String mbtiType = category.value[index];
                        return GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PersonalityGuidancePage(personalityType: mbtiType),
                            ),
                          ),
                          child: Card(
                            margin: EdgeInsets.zero,
                            color: Theme.of(context).colorScheme.surface,
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(isVerySmallScreen ? 1.0 : 2.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Image.asset(
                                      mbtiImages[mbtiType]!,
                                      width: mbtiImageSize,
                                      height: mbtiImageSize,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  SizedBox(height: verticalSpacing),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      mbtiType,
                                      style: TextStyle(
                                        fontSize: mbtiTextSize,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
