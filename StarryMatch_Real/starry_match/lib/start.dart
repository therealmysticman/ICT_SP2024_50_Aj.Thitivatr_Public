import 'package:flutter/material.dart';
import 'package:starry_match/theme/AppThemeExtension.dart';
import 'package:starry_match/login.dart'; // Import login page directly

class StartScreen extends StatefulWidget {
  final bool skipAutoNav;
  const StartScreen({super.key, this.skipAutoNav = false});

  @override
  _StartScreenState createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  @override
  void initState() {
    super.initState();
    print("StartScreen initialized, skipAutoNav: ${widget.skipAutoNav}");
    
    // Navigate to LoginPage after 3 seconds only if we're showing the start screen
    // and skipAutoNav is false
    if (!widget.skipAutoNav) {
      print("Will navigate to login after 3 seconds");
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          print("Navigating to login now");
          // Use direct navigation instead of named route
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeExt = Theme.of(context).extension<AppThemeExtension>();
    final bgImage = themeExt?.bgStart ?? 'assets/bg_pastel.jpg';
    final logoImage = themeExt?.logo1 ?? 'assets/logo.png';
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(bgImage), // Path to your image
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Centered logo
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  logoImage, 
                  width: 300, 
                  height:300, 
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
