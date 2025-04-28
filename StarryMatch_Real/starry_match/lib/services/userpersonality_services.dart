import 'package:cloud_firestore/cloud_firestore.dart';

class UserPersonalityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Update MBTI or Enneagram results in Firestore and ensure UserID consistency
  Future<void> updateTestResult({
    required String userId,  // This is the Document ID
    String? mbtiType, // Optional MBTI result
    String? enneagramType, // Optional Enneagram result
  }) async {
    try {
      // Reference the user's document in the "starrymatch_user" collection
      DocumentReference userDoc = _firestore.collection("starrymatch_user").doc(userId);

      // Fetch the user document to get the UserID field (if it exists)
      DocumentSnapshot userSnapshot = await userDoc.get();

      if (userSnapshot.exists) {
        // Retrieve the UserID field from the user's document
        String userID = userSnapshot['UserID'] ?? 'defaultUserID';  // Use 'defaultUserID' if not present

        // Prepare the update map
        Map<String, dynamic> updates = {};

        // Add MBTI type to the updates if provided
        if (mbtiType != null) {
          updates['MBTITypes'] = mbtiType;
        }

        // Add Enneagram type to the updates if provided
        if (enneagramType != null) {
          updates['EnneagramTypes'] = enneagramType;
        }

        // Update the Firestore document in "starrymatch_users" collection
        await userDoc.update(updates);

        // Now, check if there is an existing result in "starrymatch_result" for this UserID
        QuerySnapshot resultSnapshot = await _firestore
            .collection("starrymatch_result")
            .where("UserID", isEqualTo: userID)
            .where("TestType", isEqualTo: mbtiType != null ? 'MBTI' : 'Enneagram')
            .get();

        if (resultSnapshot.docs.isNotEmpty) {
          // If a result already exists, update it
          DocumentReference resultDoc = resultSnapshot.docs.first.reference;
          await resultDoc.update({
            'UserPersonality': mbtiType ?? enneagramType ?? '',  // Update the result
          });
          print("Test result updated in starrymatch_result.");
        } else {
          // If no result exists, add a new result
          await _firestore.collection("starrymatch_result").add({
            'TestType': mbtiType != null ? 'MBTI' : 'Enneagram',
            'UserID': userID,
            'UserPersonality': mbtiType ?? enneagramType ?? '',
          });
          print("Test result added to starrymatch_result.");
        }

        print("Test results updated successfully!");
      } else {
        print("User document not found");
      }
    } catch (e) {
      print("Error updating test results: $e");
    }
  }
}
