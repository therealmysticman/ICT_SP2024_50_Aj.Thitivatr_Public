import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starry_match/UserIDChange.dart';
import 'package:starry_match/localization/app_localizations.dart';
import 'package:starry_match/login.dart';
import 'package:starry_match/main.dart';
import 'package:provider/provider.dart';
import 'package:starry_match/theme/theme_notifier.dart';

class SettingsPage extends StatefulWidget {
  final String userId;

  const SettingsPage({super.key, required this.userId});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _selectedLanguage = "en"; // Default to English
  String _currentUserID = "";

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
    _loadUserData();
  }

  void _loadLanguagePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = prefs.getString('language') ?? "en";
    });
  }

  void _loadUserData() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('starrymatch_user')
          .doc(widget.userId)
          .get();
      
      if (userDoc.exists) {
        var data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _currentUserID = data['UserID'] ?? "";
        });
      }
    } catch (e) {
      print("Error loading user data: $e");
    }
  }

  void _changeLanguage(String newLang) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', newLang);

    setState(() {
      _selectedLanguage = newLang;
    });

    // Notify the app to reload localization
    MyApp.setLocale(context, Locale(newLang));
  }

  void _navigateToUserIDChange() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserIDChangePage(userId: widget.userId),
      ),
    ).then((_) {
      // Refresh user data when returning from the ID change page
      _loadUserData();
    });
  }

  // ✅ Logout Function
  void _logout(BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection('starrymatch_user')
          .doc(widget.userId)
          .update({"IsOnline": false});

      await FirebaseAuth.instance.signOut();

      // ✅ Navigate back to login using MaterialPageRoute
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    } catch (e) {
      print("Logout Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.translate("settings")),
        backgroundColor: Colors.deepPurpleAccent,
      ),
      body: Container(
        color: colorScheme.surface, // ✅ เพิ่มพื้นหลังที่รองรับ Theme
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Language Settings
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.translate("change_language"),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                DropdownButton<String>(
                  value: _selectedLanguage,
                  items: const [
                    DropdownMenuItem(value: "en", child: Text("English")),
                    DropdownMenuItem(value: "th", child: Text("ไทย")),
                  ],
                  onChanged: (String? newLang) {
                    if (newLang != null) {
                      _changeLanguage(newLang);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Theme Settings
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.brightness_6, 
                      size: 24,
                      color: colorScheme.onSurface,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.translate(
                        Provider.of<ThemeNotifier>(context).themeMode == ThemeMode.dark 
                          ? "dark_mode" 
                          : "light_mode"
                      ),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Switch(
                  value: Provider.of<ThemeNotifier>(context).themeMode == ThemeMode.dark,
                  onChanged: (bool isDark) {
                    Provider.of<ThemeNotifier>(context, listen: false).toggleTheme(isDark);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // User ID settings
            InkWell(
              onTap: _navigateToUserIDChange,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.badge, 
                          size: 24,
                          color: colorScheme.onSurface,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context)!.translate("change_user_id"),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          _currentUserID.isEmpty ? "Not set" : _currentUserID,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(), // ✅ Pushes logout button to bottom

            // ✅ Logout Button
            ElevatedButton.icon(
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout),
              label: Text(AppLocalizations.of(context)!.translate("logout")),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
