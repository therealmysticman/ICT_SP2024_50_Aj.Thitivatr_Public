import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OnlineStatusManager with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;

  OnlineStatusManager() {
    WidgetsBinding.instance.addObserver(this);
    
    // ✅ Set isOnline = false by default when the app starts
    _setUserOnline(false);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  void setUserOnlineAfterLogin(User user) {
    _user = user;
    _setUserOnline(true); // ✅ Now only updates on successful login
  }

  void setUserOfflineAfterLogout() {
    _setUserOnline(false);
    _user = null;
  }

  void _setUserOnline(bool isOnline) async {
    if (_user != null) {
      try {
        await _firestore.collection("starrymatch_user").doc(_user!.uid).update({
          "IsOnline": isOnline,
        });
        print("🔥 User ${_user!.uid} is now ${isOnline ? "ONLINE" : "OFFLINE"}");
      } catch (e) {
        print("⚠️ Failed to update IsOnline: $e");
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print("📌 App state changed: $state");

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _setUserOnline(false); // ✅ Ensure user goes offline when app closes
    } else if (state == AppLifecycleState.resumed && _user != null) {
      _setUserOnline(true); // ✅ Only set online if user is logged in
    }
  }
}
