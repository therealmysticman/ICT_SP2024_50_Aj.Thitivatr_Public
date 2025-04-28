import 'package:flutter/material.dart';
import 'package:starry_match/MBTITest.dart';
import 'package:starry_match/EnneagramTest.dart';
import 'package:starry_match/localization/app_localizations.dart';
import 'package:starry_match/theme/AppThemeExtension.dart';

class TestSelectionPage extends StatelessWidget {
  final String userId;

  const TestSelectionPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    final themeExt = Theme.of(context).extension<AppThemeExtension>();
    final bgImage = themeExt?.bgTestSelection ?? 'assets/bg_pastel_test_selection.jpg';
    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          // ✅ Background Image (Full-Screen)
          Positioned.fill(
            child: Image.asset(
              bgImage,
              fit: BoxFit.cover,
            ),
          ),

          // ✅ Full-Screen Scrollable Content
          SingleChildScrollView(
            child: SizedBox(
              height: screenHeight, // ✅ Ensures full screen height is used
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ✅ Bigger Character Image
                  Image.asset(
                    'assets/MBTI_Art/Analysts/ENTJ.png',
                    width: screenWidth * 0.7, // ✅ Make it bigger
                  ),
                  const SizedBox(height: 30),

                  // ✅ Title (Splits into 2 lines if too long)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
                    child: Text(
                      AppLocalizations.of(context)!.translate("test_selections"),
                      style: TextStyle(
                        fontSize: screenWidth * 0.06,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            blurRadius: 2.0,
                            color: Colors.black.withOpacity(0.3),
                            offset: const Offset(1, 1),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2, // ✅ Ensures text wraps if too long
                      overflow: TextOverflow.visible,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // ✅ MBTI Test Button (Rounded Corners, Light Yellow)
                  SizedBox(
                    width: screenWidth * 0.8,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MBTITestPage(userId: userId),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary, // Light Yellow
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04 , horizontal: screenHeight*0.02),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30), // ✅ Fully rounded corners
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.translate("mbti_test"),
                        style: TextStyle(fontSize: screenWidth * 0.045, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // ✅ Enneagram Test Button (Rounded Corners, Golden Yellow)
                  SizedBox(
                    width: screenWidth * 0.8,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EnneagramTestPage(userId: userId),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary, // Golden Yellow
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04, horizontal: screenHeight*0.02),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30), // ✅ Fully rounded corners
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.translate("enne_test"),
                        style: TextStyle(fontSize: screenWidth * 0.045, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
