import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:starry_match/localization/app_localizations.dart';
import 'package:starry_match/theme/AppThemeExtension.dart';

class UserIDChangePage extends StatefulWidget {
  final String userId;

  const UserIDChangePage({super.key, required this.userId});

  @override
  _UserIDChangePageState createState() => _UserIDChangePageState();
}

class _UserIDChangePageState extends State<UserIDChangePage> {
  final TextEditingController _userIdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String _currentUserId = "";

  @override
  void initState() {
    super.initState();
    _loadCurrentUserID();
  }

  Future<void> _loadCurrentUserID() async {
    setState(() => _isLoading = true);
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('starrymatch_user')
          .doc(widget.userId)
          .get();
      
      if (userDoc.exists) {
        var data = userDoc.data() as Map<String, dynamic>;
        _currentUserId = data['UserID'] ?? "";
        _userIdController.text = _currentUserId;
      }
    } catch (e) {
      print("Error loading user data: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitUserID() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        String newUserID = _userIdController.text.trim();
        
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
          setState(() {
            _isLoading = false;
          });
          return;
        }

        // Set UserID if it's unique
        await FirebaseFirestore.instance
            .collection('starrymatch_user')
            .doc(widget.userId)
            .update({'UserID': newUserID});

        setState(() {
          _isLoading = false;
        });

        Navigator.pop(context);
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!
                .translate("error_saving_userid")),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    final themeExt = Theme.of(context).extension<AppThemeExtension>();
    final bgImage = themeExt?.bgMain ?? 'assets/bg_pastel_main.jpg';
    
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.translate("change_user_id")),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              bgImage,
              fit: BoxFit.cover,
            ),
          ),

          // Main Content
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: screenHeight - AppBar().preferredSize.height - MediaQuery.of(context).padding.top,
                      ),
                      child: Container(
                        width: screenWidth,
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 20),
                            
                            // Avatar Image
                            Image.asset(
                              'assets/Avatar/default_avatar.PNG',
                              width: screenWidth * 0.35,
                            ),
                            const SizedBox(height: 20),

                            // Title
                            Text(
                              AppLocalizations.of(context)!.translate("change_user_id"),
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
                            const SizedBox(height: 10),
                            
                            // Subtitle
                            Text(
                              AppLocalizations.of(context)!.translate("user_id_subtitle"),
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

                            // Input Field
                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surface,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: TextFormField(
                                      controller: _userIdController,
                                      decoration: InputDecoration(
                                        labelText: "User ID",
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 14),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return "User ID cannot be empty";
                                        } else if (value.length < 5) {
                                          return "User ID must be at least 5 characters";
                                        } else if (value.contains(' ')) {
                                          return "User ID cannot contain spaces";
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // Rules
                                  Text(
                                    AppLocalizations.of(context)!.translate("user_id_rules"),
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

                                  // Submit Button
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _submitUserID,
                                      style: ElevatedButton.styleFrom(
                                        padding: EdgeInsets.symmetric(
                                            vertical: screenWidth * 0.03),
                                        backgroundColor: Theme.of(context).colorScheme.primary,
                                      ),
                                      child: Text(
                                        AppLocalizations.of(context)!.translate("save_changes"),
                                        style: TextStyle(
                                          fontSize: screenWidth * 0.04,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.onPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
} 