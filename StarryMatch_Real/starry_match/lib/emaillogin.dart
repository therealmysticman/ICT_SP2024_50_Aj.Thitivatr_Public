import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starry_match/home.dart';
import 'package:starry_match/main.dart';
import 'package:starry_match/localization/app_localizations.dart';
import 'package:starry_match/testselection.dart';
import 'package:starry_match/theme/AppThemeExtension.dart';
import 'package:starry_match/usernamedetermine.dart';
import 'package:starry_match/services/online_status_manager.dart'; // ✅ Import OnlineStatusManager

class EmailLoginPage extends StatefulWidget {
  const EmailLoginPage({super.key});

  @override
  _EmailLoginPageState createState() => _EmailLoginPageState();
}

class _EmailLoginPageState extends State<EmailLoginPage> {
  final _auth = FirebaseAuth.instance;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final OnlineStatusManager _onlineStatusManager =
      OnlineStatusManager(); // ✅ Initialize OnlineStatusManager
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

  void _showMessageDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                AppLocalizations.of(context)!.translate('confirm') ?? 'OK',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _loginOrRegister() async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (userCredential.user!.emailVerified) {
        // Update online status directly for better persistence
        try {
          await FirebaseFirestore.instance
              .collection('starrymatch_user')
              .doc(userCredential.user!.uid)
              .update({'IsOnline': true});
        } catch (e) {
          print('Error updating online status: $e');
        }
        
        // Also use the status manager for compatibility
        _onlineStatusManager.setUserOnlineAfterLogin(
            userCredential.user!);
            
        _showMessageDialog(
          context, 
          AppLocalizations.of(context)!.translate("login_success_title"),
          AppLocalizations.of(context)!.translate("login_success_message")
        );
        await _checkTestCompletion(userCredential.user!.uid);
      } else {
        _showMessageDialog(
          context,
          AppLocalizations.of(context)!.translate("email_verification_title"),
          AppLocalizations.of(context)!.translate("email_verification_message"),
        );
        await userCredential.user!.sendEmailVerification();
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'invalid-email':
          errorMessage = AppLocalizations.of(context)!.translate('invalid_email');
          break;
        case 'user-not-found':
          // Try to create a new account
          try {
            UserCredential userCredential =
                await _auth.createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            );

            await userCredential.user!.sendEmailVerification();
            _showMessageDialog(
              context,
              AppLocalizations.of(context)!.translate("account_created_title"),
              AppLocalizations.of(context)!.translate("account_created_message"),
            );
            return; // Exit the method after creating account
          } catch (registerError) {
            if (registerError is FirebaseAuthException) {
              switch (registerError.code) {
                case 'email-already-in-use':
                  errorMessage = AppLocalizations.of(context)!.translate('email_already_in_use');
                  break;
                case 'weak-password':
                  errorMessage = AppLocalizations.of(context)!.translate('weak_password');
                  break;
                case 'invalid-email':
                  errorMessage = AppLocalizations.of(context)!.translate('invalid_email');
                  break;
                default:
                  errorMessage = registerError.message ?? AppLocalizations.of(context)!.translate('login_failed_message');
              }
            } else {
              errorMessage = registerError.toString();
            }
          }
          break;
        case 'wrong-password':
        case 'invalid-credential':
          errorMessage = AppLocalizations.of(context)!.translate('invalid_password');
          break;
        default:
          errorMessage = e.message ?? AppLocalizations.of(context)!.translate('login_failed_message');
      }
      
      _showMessageDialog(
        context,
        AppLocalizations.of(context)!.translate("error_title"),
        errorMessage
      );
    } catch (e) {
      _showMessageDialog(
        context,
        AppLocalizations.of(context)!.translate("error_title"),
        AppLocalizations.of(context)!.translate("unexpected_error_message").replaceAll("{0}", e.toString())
      );
    }
  }

  Future<void> _checkTestCompletion(String userId) async {
    final userDocRef =
        FirebaseFirestore.instance.collection('starrymatch_user').doc(userId);
    final userDoc = await userDocRef.get();

    if (!userDoc.exists) {
      await userDocRef.set({
        'AnnonymousUsername': '-',
        'EndorsementGet': 0,
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

  @override
  Widget build(BuildContext context) {
    final themeExt = Theme.of(context).extension<AppThemeExtension>();
    final bgImage = themeExt?.bgEmail ?? 'assets/bg_pastel.jpg';
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.translate('login_email_appbar')),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(bgImage),
                fit: BoxFit.cover,
              ),
            ),
          ),
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  Image.asset(
                    themeExt?.logo2 ??
                        'assets/logo_sub.png', // Ensure this exists in assets
                    height: 300,
                    width: 400,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.translate('email'),
                      labelStyle: const TextStyle(color: Colors.white),
                      prefixIcon: const Icon(Icons.email, color: Colors.white),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.translate('password'),
                      labelStyle: const TextStyle(color: Colors.white),
                      prefixIcon: const Icon(Icons.lock, color: Colors.white),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    onPressed: _loginOrRegister,
                    child: Text(AppLocalizations.of(context)!.translate('login_email_appbar_button')),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Language Selector (below login button)
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
                              child: Text(
                                AppLocalizations.of(context)!.translate('english'),
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'th',
                              child: Text(
                                AppLocalizations.of(context)!.translate('thai'),
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                              ),
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
    );
  }
}
