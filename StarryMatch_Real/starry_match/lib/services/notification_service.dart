import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get notifications for a user
  Stream<List<NotificationModel>> getNotifications(String userId) {
    return _firestore
        .collection('starrymatch_notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  // Utility function to fix inconsistent friend relationships
  Future<Map<String, dynamic>> fixFriendshipConsistency(String userId1, String userId2) async {
    try {
      // Get both users' data
      DocumentSnapshot user1Doc = await _firestore
          .collection('starrymatch_user')
          .doc(userId1)
          .get();
      
      DocumentSnapshot user2Doc = await _firestore
          .collection('starrymatch_user')
          .doc(userId2)
          .get();
      
      if (!user1Doc.exists || !user2Doc.exists) {
        return {'status': 'error', 'message': 'user_not_available'};
      }
      
      Map<String, dynamic> user1Data = user1Doc.data() as Map<String, dynamic>;
      Map<String, dynamic> user2Data = user2Doc.data() as Map<String, dynamic>;
      
      List<dynamic> user1Friends = user1Data['friends'] ?? [];
      List<dynamic> user2Friends = user2Data['friends'] ?? [];
      
      bool user1HasUser2 = user1Friends.contains(userId2);
      bool user2HasUser1 = user2Friends.contains(userId1);
      
      // Both are already consistent, nothing to do
      if (user1HasUser2 && user2HasUser1) {
        return {'status': 'ok', 'message': 'Friendship already consistent'};
      }
      
      // Fix inconsistency
      final batch = _firestore.batch();
      
      if (user1HasUser2 && !user2HasUser1) {
        // User 1 has User 2 as friend, but User 2 doesn't have User 1
        batch.update(_firestore.collection('starrymatch_user').doc(userId2), {
          'friends': FieldValue.arrayUnion([userId1])
        });
      } else if (!user1HasUser2 && user2HasUser1) {
        // User 2 has User 1 as friend, but User 1 doesn't have User 2
        batch.update(_firestore.collection('starrymatch_user').doc(userId1), {
          'friends': FieldValue.arrayUnion([userId2])
        });
      }
      
      await batch.commit();
      return {'status': 'fixed', 'message': 'Friendship consistency fixed'};
    } catch (e) {
      return {'status': 'error', 'message': 'Error fixing friendship: $e'};
    }
  }

  // Check if a friend request already exists or if users are already friends
  Future<Map<String, dynamic>> checkFriendRequestStatus({
    required String fromUserId, 
    required String toUserId
  }) async {
    try {
      // Get both users' data
      DocumentSnapshot fromUserDoc = await _firestore
          .collection('starrymatch_user')
          .doc(fromUserId)
          .get();
      
      DocumentSnapshot toUserDoc = await _firestore
          .collection('starrymatch_user')
          .doc(toUserId)
          .get();
      
      if (!fromUserDoc.exists || !toUserDoc.exists) {
        return {'status': 'error', 'message': 'user_not_available'};
      }
      
      Map<String, dynamic> fromUserData = fromUserDoc.data() as Map<String, dynamic>;
      Map<String, dynamic> toUserData = toUserDoc.data() as Map<String, dynamic>;
      
      // Check if already friends in either user's friend list
      List<dynamic> fromUserFriends = fromUserData['friends'] ?? [];
      List<dynamic> toUserFriends = toUserData['friends'] ?? [];
      
      if (fromUserFriends.contains(toUserId) || toUserFriends.contains(fromUserId)) {
        return {'status': 'already_friends'};
      }
      
      // Check if toUser has a pending request from fromUser
      List<dynamic> pendingFriends = toUserData['pendingFriends'] ?? [];
      if (pendingFriends.contains(fromUserId)) {
        return {'status': 'request_exists'};
      }
      
      // Check if fromUser has a pending request from toUser
      List<dynamic> fromUserPendingFriends = fromUserData['pendingFriends'] ?? [];
      if (fromUserPendingFriends.contains(toUserId)) {
        return {'status': 'reverse_request_exists'};
      }
      
      // Check for active notification in Firestore
      QuerySnapshot existingRequests = await _firestore
          .collection('starrymatch_notifications')
          .where('userId', isEqualTo: toUserId)
          .where('type', isEqualTo: 'friend_request')
          .get();
      
      for (var doc in existingRequests.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        if (data['data'] != null && 
            data['data']['fromUserId'] == fromUserId && 
            data['status'] != 'rejected') {
          return {'status': 'request_exists'};
        }
      }
      
      // No existing request found
      return {'status': 'ok'};
    } catch (e) {
      return {'status': 'error', 'message': 'Error checking request status: $e'};
    }
  }

  // Create a new notification with localization support
  Future<void> createNotification({
    required String userId,
    required String type,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    // Get user's language preference
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String languageCode = prefs.getString('language') ?? "en";
    
    // Localize notification title and message based on type
    String localizedTitle = title;
    String localizedMessage = message;
    
    if (languageCode == 'th') {
      // Thai translations
      switch (type) {
        case 'endorsement':
          localizedTitle = 'มีการชื่นชมใหม่';
          if (data != null && data['endorserName'] != null && data['skill'] != null) {
            localizedMessage = '${data['endorserName']} ชื่นชมและให้ความน่าเชื่อถือกับ ${data['skill']} ของคุณ!';
          }
          break;
        case 'friend_request':
          localizedTitle = 'คำขอเป็นเพื่อนใหม่';
          if (data != null && data['senderName'] != null) {
            localizedMessage = '${data['senderName']} ต้องการเป็นเพื่อนกับคุณ!';
          }
          break;
        case 'friend_accepted':
          localizedTitle = 'คำขอเป็นเพื่อนได้รับการยอมรับ';
          if (data != null && data['username'] != null) {
            localizedMessage = '${data['username']} ยอมรับคำขอเป็นเพื่อนของคุณแล้ว!';
          }
          break;
        case 'message':
          localizedTitle = 'ข้อความใหม่';
          break;
      }
    } else {
      // English translations - default, but explicitly setting for clarity
      switch (type) {
        case 'endorsement':
          localizedTitle = 'New Endorsement';
          if (data != null && data['endorserName'] != null && data['skill'] != null) {
            localizedMessage = '${data['endorserName']} endorsed your ${data['skill']}!';
          }
          break;
        case 'friend_request':
          localizedTitle = 'New Friend Request';
          if (data != null && data['senderName'] != null) {
            localizedMessage = '${data['senderName']} wants to be your friend!';
          }
          break;
        case 'friend_accepted':
          localizedTitle = 'Friend Request Accepted';
          if (data != null && data['username'] != null) {
            localizedMessage = '${data['username']} accepted your friend request!';
          }
          break;
        case 'message':
          localizedTitle = 'New Message';
          break;
      }
    }

    final notification = NotificationModel(
      id: '', // Firestore will generate this
      userId: userId,
      type: type,
      title: localizedTitle,
      message: localizedMessage,
      isRead: false,
      timestamp: Timestamp.now(),
      data: data,
    );

    await _firestore
        .collection('starrymatch_notifications')
        .add(notification.toMap());
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    await _firestore
        .collection('starrymatch_notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  // Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    final batch = _firestore.batch();
    final notifications = await _firestore
        .collection('starrymatch_notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in notifications.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  // Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    await _firestore
        .collection('starrymatch_notifications')
        .doc(notificationId)
        .delete();
  }

  // Create endorsement notification
  Future<void> createEndorsementNotification({
    required String userId,
    required String endorserName,
    required String skill,
  }) async {
    await createNotification(
      userId: userId,
      type: 'endorsement',
      title: 'New Endorsement',
      message: '$endorserName endorsed your $skill skill!',
      data: {
        'endorserName': endorserName,
        'skill': skill,
      },
    );
  }

  Future<void> sendFriendRequest({
    required String fromUserId,
    required String toUserId,
    required String senderName,
  }) async {
    await createNotification(
      userId: toUserId,
      type: 'friend_request',
      title: 'New Friend Request',
      message: '$senderName wants to be your friend!',
      data: {
        'fromUserId': fromUserId,
        'senderName': senderName,
      },
    );
  }

  // Accept a friend request
  Future<void> acceptFriendRequest({
    required String notificationId,
    required String currentUserId,
    required String requesterId,
  }) async {
    // Get both users' data
    DocumentSnapshot currentUserDoc = await _firestore
        .collection('starrymatch_user')
        .doc(currentUserId)
        .get();

    DocumentSnapshot requesterDoc = await _firestore
        .collection('starrymatch_user')
        .doc(requesterId)
        .get();

    if (!currentUserDoc.exists || !requesterDoc.exists) {
      throw Exception('user_not_available');
    }

    Map<String, dynamic> currentUserData = currentUserDoc.data() as Map<String, dynamic>;
    Map<String, dynamic> requesterData = requesterDoc.data() as Map<String, dynamic>;

    String currentUsername = currentUserData['AnnonymousUsername'] ?? 'A user';
    String requesterUsername = requesterData['AnnonymousUsername'] ?? 'A user';

    // Update both users' friends list
    final batch = _firestore.batch();
    
    // Add requester to current user's friends
    final currentUserRef = _firestore.collection('starrymatch_user').doc(currentUserId);
    batch.update(currentUserRef, {
      'friends': FieldValue.arrayUnion([requesterId]),
      'pendingFriends': FieldValue.arrayRemove([requesterId])
    });
    
    // Add current user to requester's friends
    final requesterRef = _firestore.collection('starrymatch_user').doc(requesterId);
    batch.update(requesterRef, {
      'friends': FieldValue.arrayUnion([currentUserId])
    });
    
    // Mark notification as accepted and read
    final notificationRef = _firestore.collection('starrymatch_notifications').doc(notificationId);
    batch.update(notificationRef, {
      'isRead': true,
      'status': 'accepted'
    });
    
    // Create friend chatroom
    final chatroomRef = _firestore.collection('starrymatch_friend_chatroom').doc();
    final timestamp = Timestamp.now();
    
    batch.set(chatroomRef, {
      'members': [currentUserId, requesterId],
      'memberNames': {
        currentUserId: currentUsername,
        requesterId: requesterUsername
      },
      'lastMessage': 'You are now friends!',
      'lastMessageTime': timestamp,
      'createdAt': timestamp,
      'updatedAt': timestamp,
      'isActive': true
    });
    
    // Send acceptance notification to requester
    await batch.commit();
    
    // Create notification for the requester that the request was accepted
    await createNotification(
      userId: requesterId,
      type: 'friend_accepted',
      title: 'Friend Request Accepted',
      message: '$currentUsername accepted your friend request!',
      data: {
        'userId': currentUserId,
        'username': currentUsername,
        'chatroomId': chatroomRef.id
      },
    );

    // Add initial message to chatroom
    await _firestore.collection('starrymatch_friend_chatroom')
        .doc(chatroomRef.id)
        .collection('messages')
        .add({
      'sender': 'system',
      'text': 'You are now friends!',
      'timestamp': timestamp,
      'isRead': false,
      'type': 'text'
    });
  }
  
  // Reject a friend request
  Future<void> rejectFriendRequest({
    required String notificationId,
    required String currentUserId,
    required String requesterId,
  }) async {
    // Mark notification as rejected and read
    await _firestore
        .collection('starrymatch_notifications')
        .doc(notificationId)
        .update({
      'isRead': true,
      'status': 'rejected'
    });
    
    // Remove from pendingFriends if present
    await _firestore
        .collection('starrymatch_user')
        .doc(currentUserId)
        .update({
      'pendingFriends': FieldValue.arrayRemove([requesterId])
    });
  }

  // ส่งคำขอเป็นเพื่อนโดยตรง ข้ามการตรวจสอบการมีอยู่ของผู้ใช้ (เนื่องจากตรวจสอบไปแล้ว)
  Future<void> sendDirectFriendRequest({
    required String fromUserId,
    required String toUserId,
    required String senderName,
  }) async {
    // Create a notification for the other user
    await createNotification(
      userId: toUserId,
      type: 'friend_request',
      title: 'New Friend Request',
      message: '$senderName wants to be your friend!',
      data: {
        'fromUserId': fromUserId,
        'senderName': senderName,
      },
    );
  }
} 