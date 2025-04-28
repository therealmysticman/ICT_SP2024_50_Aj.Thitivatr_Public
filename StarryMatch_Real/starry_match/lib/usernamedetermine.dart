import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:starry_match/testselection.dart';
import 'package:starry_match/localization/app_localizations.dart';
import 'package:starry_match/theme/AppThemeExtension.dart';

class DetermineUsernamePage extends StatefulWidget {
  final String userId;

  const DetermineUsernamePage({super.key, required this.userId});

  @override
  _DetermineUsernamePageState createState() => _DetermineUsernamePageState();
}

class _DetermineUsernamePageState extends State<DetermineUsernamePage> {
  final TextEditingController _usernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Future<void> _submitUsername() async {
    if (_formKey.currentState!.validate()) {
      try {
        String newUserID = _usernameController.text.trim();
        
        // Check if the specific UserID already exists in the collection
        QuerySnapshot existingUsers = await FirebaseFirestore.instance
            .collection('starrymatch_user')
            .where('UserID', isEqualTo: newUserID)
            .get();
            
        if (existingUsers.docs.isNotEmpty) {
          // UserID already exists, show error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!
                  .translate("username_already_taken")),
            ),
          );
          return;
        }

        // Set UserID if it's unique
        await FirebaseFirestore.instance
            .collection('starrymatch_user')
            .doc(widget.userId)
            .update({'UserID': newUserID});

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TestSelectionPage(userId: widget.userId),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!
                  .translate("error_saving_username"))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
final themeExt = Theme.of(context).extension<AppThemeExtension>();
final bgImage = themeExt?.bgLogin ?? 'assets/bg_pastel.jpg';
    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          // ✅ Background Image
          Positioned.fill(
            child: Image.asset(
              bgImage,
              fit: BoxFit.cover,
            ),
          ),

          // ✅ Full-Screen Layout
          SingleChildScrollView(
            child: Container(
              width: screenWidth,
              height: screenHeight, // ✅ Fills entire screen
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ✅ Big Star Character
                  Image.asset(
                    'assets/Avatar/default_avatar.PNG',
                    width: screenWidth * 0.45, // Adjust to fit well
                  ),
                  const SizedBox(height: 20),

                  // ✅ Title
                  Text(
                    AppLocalizations.of(context)!.translate("user_determine"),
                    style: TextStyle(
                      fontSize: screenWidth * 0.05,
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
                  ),
                  const SizedBox(height: 20),

                  // ✅ Input Field (Full Width)
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity, // ✅ Make input full width
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface, // Better readability
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextFormField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context)!
                                  .translate("username_label"),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return AppLocalizations.of(context)!
                                    .translate("username_empty");
                              } else if (value.length < 5) {
                                return AppLocalizations.of(context)!
                                    .translate("username_too_short");
                              } else if (value.contains(' ')) {
                                return AppLocalizations.of(context)!
                                    .translate("username_no_spaces");
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 10),

                        // ✅ Username Rules (Better Readability)
                        Text(
                          AppLocalizations.of(context)!
                              .translate("username_rules"),
                          style: TextStyle(
                            fontSize: screenWidth * 0.035,
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
                        ),
                        const SizedBox(height: 20),

                        // ✅ Submit Button (Full Width)
                        SizedBox(
                          child: // ✅ Submit Button
                              ElevatedButton(
                            onPressed: _submitUsername,
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                  vertical: screenWidth * 0.03,
                                  horizontal: screenWidth * 0.1),
                            ),
                            child: Text(AppLocalizations.of(context)!
                                .translate("submit"),
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                            ),
                          ),
                        ),
                      ],
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
