import 'package:flutter/material.dart';
import 'package:starry_match/theme/AppThemeExtension.dart';
import 'personalityguidance.dart';

class EnneagramGuidancePage extends StatelessWidget {
  final String userId;

  EnneagramGuidancePage({super.key, required this.userId});

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

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 600;
    final crossAxisCount = isSmallScreen ? 2 : 3; // Use 2 columns on small screens
    final padding = isSmallScreen ? 8.0 : 16.0;
    final spacing = isSmallScreen ? 8.0 : 16.0;
    final childAspectRatio = isSmallScreen ? 0.9 : 1.0;
    
    final themeExt = Theme.of(context).extension<AppThemeExtension>();
    final bgImage = themeExt?.bgGuidance ?? 'assets/bg_pastel_guidance.jpg';
    
    return Scaffold(
      appBar: AppBar(title: const Text('Enneagram Guidance')),
      body: Container(
        width: screenWidth,
        height: screenHeight,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(bgImage), // ✅ Background Image
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount, // Adaptive grid
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                childAspectRatio: childAspectRatio,
              ),
              itemCount: enneagramImages.length,
              itemBuilder: (context, index) {
                String enneagramType = enneagramImages.keys.elementAt(index);
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            PersonalityGuidancePage(personalityType: enneagramType),
                      ),
                    );
                  },
                  child: Card(
                    color: Theme.of(context).colorScheme.surface,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8.0), // Prevents cropping
                            child: Image.asset(
                              enneagramImages[enneagramType]!,
                              fit: BoxFit.contain, // ✅ Ensures full image visibility
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(isSmallScreen ? 4.0 : 8.0),
                          child: Text(
                            enneagramType,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 14.0 : 18.0,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
