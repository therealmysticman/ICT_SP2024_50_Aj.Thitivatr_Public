import 'package:flutter/material.dart';
import 'package:starry_match/MBTIguidance.dart';
import 'package:starry_match/enneagramguidance.dart';
import 'package:starry_match/localization/app_localizations.dart';
import 'package:starry_match/theme/AppThemeExtension.dart';
import 'package:starry_match/widgets/bottomnav_widget.dart'; // ✅ Import modularized BottomNavWidget

class GuidanceSelectionPage extends StatefulWidget {
  final String userId;

  const GuidanceSelectionPage({super.key, required this.userId});

  @override
  _GuidanceSelectionPageState createState() => _GuidanceSelectionPageState();
}

class _GuidanceSelectionPageState extends State<GuidanceSelectionPage> {
  int _selectedIndex = 2; // Default selection on Guidance


  @override
  Widget build(BuildContext context) {
      final themeExt = Theme.of(context).extension<AppThemeExtension>();
      final bgImage = themeExt?.bgGuidance ?? 'assets/bg_pastel_guidance.jpg';
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.translate("guide_select_title"))),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(bgImage), // ✅ Apply background image
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 250,
                height: 250,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/MBTI_Art/Analysts/INTP.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[800],
                        child: const Center(
                          child: Text(
                            "Image not found",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.of(context)!.translate("chooseYourGuidance"),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.black26, blurRadius: 3)],
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MBTIGuidancePage(userId: widget.userId)),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context)!.translate("mbti_guide"),
                  style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => EnneagramGuidancePage(userId: widget.userId)),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context)!.translate("enne_guide"),
                  style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
       bottomNavigationBar: BottomNavWidget(
        selectedIndex: _selectedIndex,
        onItemTapped: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        userId: widget.userId, // ✅ Pass userId to BottomNavWidget
      ),
    );
  }
}
