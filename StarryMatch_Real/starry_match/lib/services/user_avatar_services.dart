import 'package:cloud_firestore/cloud_firestore.dart';

class UserAvatarService {
  final String userId;
  UserAvatarService({required this.userId});

  Future<Map<String, dynamic>> fetchUserAvatar() async {
    try {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('starrymatch_user')
          .doc(userId)
          .get();

      if (snapshot.exists) {
        var avatarData = snapshot['UserAvatar'];
        if (avatarData is Map<String, dynamic>) {
          return {
            'selectedSkin': avatarData['selectedSkin'] ?? "default_skin",
            'selectedHat': avatarData['selectedHat'] ?? "",
            'selectedClothes': avatarData['selectedClothes'] ?? "",
            'ownedSkins': List<String>.from(avatarData['ownedSkins'] ?? []),
            'ownedHats': List<String>.from(avatarData['ownedHats'] ?? []),
            'ownedClothes': List<String>.from(avatarData['ownedClothes'] ?? []),
          };
        } else {
          print("Error: UserAvatar is stored incorrectly.");
          await resetUserAvatar(avatarData);
        }
      }
    } catch (e) {
      print("Error fetching user avatar: $e");
    }
    return {};
  }

  Future<void> fetchSkinImage(String skinName, Function(String) updateSkinPath) async {
    await _fetchAccessoryImage(skinName, "Skin", updateSkinPath);
  }

  Future<void> fetchHatImage(String hatName, Function(String) updateHatPath) async {
    await _fetchAccessoryImage(hatName, "Hat", updateHatPath);
  }

  Future<void> fetchClothesImage(String clothesName, Function(String) updateClothesPath) async {
    await _fetchAccessoryImage(clothesName, "Clothes", updateClothesPath);
  }

  Future<void> _fetchAccessoryImage(String accessoryName, String accessoryType, Function(String) updatePath) async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('starrymatch_accesories')
          .where('AccessoriesType', isEqualTo: accessoryType)
          .where('AccessoriesName', isEqualTo: accessoryName)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        updatePath(snapshot.docs.first['AccessoriesPic']);
      } else {
        print("Warning: No $accessoryType found with name '$accessoryName'.");
      }
    } catch (e) {
      print("Error fetching $accessoryType image: $e");
    }
  }

  Future<void> resetUserAvatar(Map<String, dynamic> existingAvatarData) async {
    await FirebaseFirestore.instance
        .collection('starrymatch_user')
        .doc(userId)
        .update({
      'UserAvatar': {
        'selectedSkin': existingAvatarData['selectedSkin'] ?? 'default_skin',
        'selectedHat': existingAvatarData['selectedHat'] ?? '',
        'selectedClothes': existingAvatarData['selectedClothes'] ?? '',
        'ownedSkins': existingAvatarData['ownedSkins'] ?? [],
        'ownedHats': existingAvatarData['ownedHats'] ?? [],
        'ownedClothes': existingAvatarData['ownedClothes'] ?? [],
      }
    });
    print("✅ UserAvatar has been reset while keeping existing data.");
  }

  Future<void> updateUserAvatar(String field, String value) async {
    await FirebaseFirestore.instance
        .collection('starrymatch_user')
        .doc(userId)
        .update({
      'UserAvatar.$field': value,
    });
  }

  Future<void> updateUsername(String newUsername) async {
    if (newUsername.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('starrymatch_user')
          .doc(userId)
          .update({
        'AnnonymousUsername': newUsername,
      });
      print("✅ Username updated successfully");
    }
  }
}