import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:starry_match/models/endorsement.dart';
import 'package:starry_match/services/notification_service.dart';

class EndorsementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // Add endorsement to a user
  Future<void> addEndorsement({
    required String fromUserId,
    required String toUserId,
    required int plasmaAmount,
  }) async {
    try {
      // Get the current endorsement count
      DocumentSnapshot userDoc = await _firestore
          .collection('starrymatch_user')
          .doc(toUserId)
          .get();

      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      // Get current endorsement count
      int currentEndorsements = userDoc['EndorsementGet'] ?? 0;
      int newCount = currentEndorsements + plasmaAmount; // Add plasma amount to endorsement count

      // Update the endorsement count
      await _firestore.collection('starrymatch_user').doc(toUserId).update({
        'EndorsementGet': newCount,
      });

      // Record the endorsement in a separate collection
      await _firestore.collection('starrymatch_endorsements').add({
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'plasmaAmount': plasmaAmount,
        'timestamp': FieldValue.serverTimestamp(),
      });

    } catch (e) {
      print('Error adding endorsement: $e');
      throw Exception('Failed to add endorsement');
    }
  }

  // Check if user has already endorsed another user
  Future<bool> hasEndorsed({
    required String fromUserId,
    required String toUserId,
  }) async {
    try {
      QuerySnapshot endorsementDocs = await _firestore
          .collection('starrymatch_endorsements')
          .where('fromUserId', isEqualTo: fromUserId)
          .where('toUserId', isEqualTo: toUserId)
          .get();

      return endorsementDocs.docs.isNotEmpty;
    } catch (e) {
      print('Error checking endorsement: $e');
      return false;
    }
  }

  // Get total endorsements for a user
  Future<int> getTotalEndorsements(String userId) async {
    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('starrymatch_user')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        return 0;
      }

      return userDoc['EndorsementGet'] ?? 0;
    } catch (e) {
      print('Error getting total endorsements: $e');
      return 0;
    }
  }

  Future<void> createEndorsement(Endorsement endorsement) async {
    try {
      // Create endorsement
      await _firestore.collection('endorsements').add(endorsement.toMap());

      // Create notification for the endorsed user
      await _notificationService.createEndorsementNotification(
        userId: endorsement.endorsedUserId,
        endorserName: endorsement.endorserName,
        skill: endorsement.skill,
      );
    } catch (e) {
      print('Error creating endorsement: $e');
      rethrow;
    }
  }

  Stream<List<Endorsement>> getEndorsements(String userId) {
    return _firestore
        .collection('endorsements')
        .where('endorsedUserId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Endorsement.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  Future<void> deleteEndorsement(String endorsementId) async {
    await _firestore.collection('endorsements').doc(endorsementId).delete();
  }
} 