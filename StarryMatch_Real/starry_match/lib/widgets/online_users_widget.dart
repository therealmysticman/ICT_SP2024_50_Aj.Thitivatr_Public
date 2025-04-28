import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:starry_match/localization/app_localizations.dart';

class OnlineUsersWidget extends StatelessWidget {
  const OnlineUsersWidget({super.key});

  Stream<int> _getOnlineUserCount() {
    return FirebaseFirestore.instance
        .collection('starrymatch_user')
        .where("IsOnline", isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _getOnlineUserCount(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Text(
            "Loading online users...",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          );
        }

        // ใช้ format string จากไฟล์ภาษาโดยตรง แทนที่ {0} ด้วยจำนวนผู้ใช้
        String text = AppLocalizations.of(context)!
            .translate("online_users")
            .replaceAll("{0}", snapshot.data.toString());
            
        return Text(
          text,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        );
      },
    );
  }
}
