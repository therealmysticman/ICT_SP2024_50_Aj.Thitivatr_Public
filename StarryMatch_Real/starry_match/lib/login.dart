import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starry_match/home.dart';
import 'package:starry_match/main.dart';
import 'package:starry_match/localization/app_localizations.dart';
import 'package:starry_match/testselection.dart';
import 'package:starry_match/theme/AppThemeExtension.dart';
import 'package:starry_match/usernamedetermine.dart';
import 'emaillogin.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _selectedLanguage = 'en';

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = prefs.getString('language') ?? 'en';
    });
  }

  Future<void> _changeLanguage(String languageCode) async {
    // Set the locale at app level
    MyApp.setLocale(context, Locale(languageCode));
    
    setState(() {
      _selectedLanguage = languageCode;
    });
  }

  // ✅ Google Sign-In Function
  Future<void> _loginWithGoogle() async {
    try {
      print("🔹 Signing in with Google...");

      // Step 1: Trigger Google Sign-In
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return; // User canceled login

      // Step 2: Obtain auth details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Step 3: Sign in to Firebase
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;
      if (user == null) throw Exception("Failed to sign in with Google.");

      print("✅ Logged in as: ${user.displayName} (ID: ${user.uid})");
      
      // Save auth state for persistence - this is handled automatically by Firebase Auth
      // but we'll ensure user is properly marked as online in Firestore
      try {
        await FirebaseFirestore.instance
            .collection('starrymatch_user')
            .doc(user.uid)
            .update({'IsOnline': true});
      } catch (e) {
        print('Error updating online status: $e');
      }

      // Step 4: Check or register user in Firestore
      await _checkTestCompletion(user.uid);
    } catch (e) {
      print("❌ Google Sign-In Error: $e");
      _showErrorDialog('Login failed: $e');
    }
  }

  Future<void> _checkTestCompletion(String userId) async {
    final userDocRef =
        FirebaseFirestore.instance.collection('starrymatch_user').doc(userId);
    final userDoc = await userDocRef.get();

    if (!userDoc.exists) {
      await userDocRef.set({
        'AnnonymousUsername': '-',
        'EndorsementGet': 0 ,
        'EnneagramTypes': '-',
        'friends': [],
        'MBTITypes': '-',
        'StarryCoin': 100,
        'StarryPlasma': 100,
        'UserAvatar': {
          'ownedSkins': ["Travel light", "Blazing light"],
          'ownedHats': ["default_hat"],
          'ownedClothes': ["default_clothes"],
          'selectedSkin': 'Travel light',
          'selectedHat': 'default_hat',
          'selectedClothes': 'default_clothes',
        },
        'IsOnline': true,
        'UserID': '-',
      });

      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => DetermineUsernamePage(userId: userId)),
      );
      return;
    }

    await userDocRef.update({"IsOnline": true});
    final data = userDoc.data();

    if (data != null) {
      final userID = data['UserID'] ?? '-';
      if (userID == '-') {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => DetermineUsernamePage(userId: userId)),
        );
        return;
      }

      final enneagramType = data['EnneagramTypes'] ?? '-';
      final mbtiType = data['MBTITypes'] ?? '-';

      if (enneagramType == '-' && mbtiType == '-') {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => TestSelectionPage(userId: userId)),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => HomePage(userId: userId)),
        );
      }
    }
  }

  // ✅ Show error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.translate('error_title')),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.translate('cancel')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeExt = Theme.of(context).extension<AppThemeExtension>();
    final bgImage = themeExt?.bgLogin ?? 'assets/bg_pastel_login.jpg';
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
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
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ✅ Row with Characters (Closer Together)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/Enneagram_Art/Type4.png',
                            width: screenWidth * 0.46, // Reduced width slightly
                            height: screenWidth * 0.46,
                          ),
                          SizedBox(width: screenWidth * 0.01), // 🔥 Reduced spacing
                          Image.asset(
                            'assets/MBTI_Art/Explorers/ESFP.png',
                            width: screenWidth * 0.46, // Same width as other image
                            height: screenWidth * 0.46,
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Text(
                        AppLocalizations.of(context)!.translate('login_title'),
                        style: TextStyle(
                          fontSize: screenWidth * 0.07,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              blurRadius: 5.0,
                              color: Colors.black.withOpacity(0.5),
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
            
                      // ✅ Email Login Button
                      ElevatedButton.icon(
                        icon: Icon(
                          Icons.email,
                          size: 28,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimary, // ✅ ดึงสีจาก theme
                        ),
                        label: Text(
                            AppLocalizations.of(context)!.translate('login_email'),
                            style: TextStyle(fontSize: screenWidth * 0.045)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          padding: EdgeInsets.symmetric(
                              vertical: screenWidth * 0.03,
                              horizontal: screenWidth * 0.1),
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const EmailLoginPage()),
                        ),
                      ),
                      const SizedBox(height: 20),
            
                      // ✅ Google Sign-In Button
                      ElevatedButton.icon(
                        icon: Icon(Icons.g_mobiledata,
                            size: 28,  color: Theme.of(context)
                              .colorScheme
                              .onPrimary, ), // ✅ Built-in Google-style "G"
                        label: Text(
                            AppLocalizations.of(context)!.translate('login_google'),
                            style: TextStyle(fontSize: screenWidth * 0.045)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          padding: EdgeInsets.symmetric(
                              vertical: screenWidth * 0.03,
                              horizontal: screenWidth * 0.1),
                        ),
                        onPressed: _loginWithGoogle,
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Language Selector (Moved to below the buttons)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${AppLocalizations.of(context)!.translate('change_language')}: ',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary, 
                              fontWeight: FontWeight.w500,
                              shadows: [
                                Shadow(blurRadius: 2.0, color: Colors.black45, offset: Offset(1, 1)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: DropdownButton<String>(
                              value: _selectedLanguage,
                              icon: Icon(Icons.language, color: Theme.of(context).colorScheme.onSurface),
                              underline: Container(),
                              dropdownColor: Theme.of(context).colorScheme.surface,
                              items: [
                                DropdownMenuItem(
                                  value: 'en',
                                  child: Text(AppLocalizations.of(context)!.translate('english'), style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),

                                ),
                                DropdownMenuItem(
                                  value: 'th',
                                  child: Text(AppLocalizations.of(context)!.translate('thai'), style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                                ),
                              ],
                              onChanged: (String? value) {
                                if (value != null) {
                                  _changeLanguage(value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
