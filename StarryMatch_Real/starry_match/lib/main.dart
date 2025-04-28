import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart'; // ✅ เพิ่มสำหรับ ThemeNotifier
import 'package:starry_match/localization/app_localizations.dart';
import 'package:starry_match/start.dart';
import 'package:starry_match/home.dart';
import 'package:starry_match/login.dart';
import 'package:starry_match/testselection.dart';
import 'package:starry_match/usernamedetermine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:starry_match/services/online_status_manager.dart';
import 'package:starry_match/theme/theme.dart'; // ✅ import theme
import 'package:starry_match/theme/theme_notifier.dart'; // ✅ import notifier
import 'package:starry_match/services/chat_services.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Custom page transition
class FadePageRoute extends PageRouteBuilder {
  final Widget page;
  
  FadePageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 800),
        );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  String savedLanguage = await loadLanguagePreference() ?? 'en'; // Default to English
  
  // Clean up any lingering chatroom sessions
  await ChatService.cleanupActiveChatrooms();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeNotifier(), // ✅ เริ่มต้น ThemeNotifier
      child: MyApp(savedLanguage),
    ),
  );
}

// ✅ Load saved language globally
Future<String?> loadLanguagePreference() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getString('language');
}

// ✅ Save language globally when changed in Dashboard
Future<void> saveLanguagePreference(String languageCode) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString('language', languageCode);
}

class MyApp extends StatefulWidget {
  final String initialLanguage;
  const MyApp(this.initialLanguage, {super.key});

  static void setLocale(BuildContext context, Locale newLocale) {
    final _MyAppState? state = context.findAncestorStateOfType<_MyAppState>();
    state?.setLocale(newLocale);
  }

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('en'); // Default
  final OnlineStatusManager _onlineStatusManager = OnlineStatusManager();
  bool _checking = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _locale = Locale(widget.initialLanguage);
    _checkCurrentUser();
  }
  
  // Check if user is already logged in
  Future<void> _checkCurrentUser() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser != null && currentUser.emailVerified) {
      // User is logged in and verified
      String userId = currentUser.uid;
      
      // Set user as online
      try {
        await FirebaseFirestore.instance
            .collection('starrymatch_user')
            .doc(userId)
            .update({'IsOnline': true});
      } catch (e) {
        print('Error updating online status: $e');
      }
      
      // Add a delay to show the splash screen for a few seconds even when logged in
      await Future.delayed(const Duration(seconds: 2));
      
      // Store the userId for home screen
      if (mounted) {
        setState(() {
          _userId = userId;
          _checking = false;
        });
      }
    } else {
      // No user logged in or not verified
      // Show splash for a bit longer then navigate to login
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        setState(() {
          _checking = false;
        });
        
        // Schedule navigation to login after build completes with fade animation
        Future.microtask(() {
          Navigator.of(context).pushReplacement(
            FadePageRoute(page: const LoginPage())
          );
        });
      }
    }
  }

  @override
  void dispose() {
    _onlineStatusManager.dispose();
    super.dispose();
  }

  void setLocale(Locale locale) async {
    await saveLanguagePreference(locale.languageCode);
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    // Decide which screen to show
    Widget homeScreen;
    if (_checking) {
      // Still checking user status
      homeScreen = const StartScreen(skipAutoNav: true);
    } else if (_userId != null) {
      // User is logged in, show the appropriate screen
      homeScreen = FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('starrymatch_user')
            .doc(_userId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const StartScreen(skipAutoNav: true);
          }
          
          if (snapshot.hasError) {
            return const StartScreen();
          }
          
          final data = snapshot.data?.data() as Map<String, dynamic>?;
          Widget destinationPage;
          
          if (data == null) {
            destinationPage = DetermineUsernamePage(userId: _userId!);
          } else {
            final userID = data['UserID'] ?? '-';
            if (userID == '-') {
              destinationPage = DetermineUsernamePage(userId: _userId!);
            } else {
              final enneagramType = data['EnneagramTypes'] ?? '-';
              final mbtiType = data['MBTITypes'] ?? '-';
              
              if (enneagramType == '-' && mbtiType == '-') {
                destinationPage = TestSelectionPage(userId: _userId!);
              } else {
                destinationPage = HomePage(userId: _userId!);
              }
            }
          }
          
          // Apply a smooth fade transition by using Navigator push
          Future.microtask(() {
            Navigator.of(context).pushReplacement(
              FadePageRoute(page: destinationPage)
            );
          });
          
          // Return the start screen while the transition is being set up
          return const StartScreen(skipAutoNav: true);
        }
      );
    } else {
      // User is not logged in, create a widget that will push to login page with animation
      homeScreen = Builder(
        builder: (context) {
          // Push login page with animation after first frame
          Future.microtask(() {
            Navigator.of(context).pushReplacement(
              FadePageRoute(page: const LoginPage())
            );
          });
          
          // Show start screen briefly while navigation is scheduled
          return const StartScreen(skipAutoNav: true);
        }
      );
    }
    
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'StarryMatch',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: const [Locale('en'), Locale('th')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeNotifier.themeMode, // ✅ จุดเปลี่ยนธีม!
      routes: {
        '/login': (_) => const LoginPage(),
      },
      home: homeScreen,
    );
  }
}
