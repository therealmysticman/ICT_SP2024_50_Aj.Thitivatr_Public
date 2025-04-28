import 'package:flutter/material.dart';
import 'package:starry_match/models/notification.dart';
import 'package:starry_match/services/notification_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:starry_match/localization/app_localizations.dart';
import 'package:starry_match/theme/AppThemeExtension.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Thai messages implementation for timeago
class ThaiMessages implements timeago.LookupMessages {
  @override String prefixAgo() => '';
  @override String prefixFromNow() => '';
  @override String suffixAgo() => 'ที่แล้ว';
  @override String suffixFromNow() => 'จากนี้';
  @override String lessThanOneMinute(int seconds) => 'ไม่กี่วินาที';
  @override String aboutAMinute(int minutes) => 'ประมาณ 1 นาที';
  @override String minutes(int minutes) => '$minutes นาที';
  @override String aboutAnHour(int minutes) => 'ประมาณ 1 ชั่วโมง';
  @override String hours(int hours) => '$hours ชั่วโมง';
  @override String aDay(int hours) => '1 วัน';
  @override String days(int days) => '$days วัน';
  @override String aboutAMonth(int days) => 'ประมาณ 1 เดือน';
  @override String months(int months) => '$months เดือน';
  @override String aboutAYear(int year) => 'ประมาณ 1 ปี';
  @override String years(int years) => '$years ปี';
  @override String wordSeparator() => ' ';
}

class NotificationPage extends StatefulWidget {
  final String userId;

  const NotificationPage({super.key, required this.userId});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final NotificationService _notificationService = NotificationService();
  String languageCode = "en"; // Default to English

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    
    // Add Thai locale messages for timeago
    timeago.setLocaleMessages('th', ThaiMessages());
  }

  Future<void> _loadLanguage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      languageCode = prefs.getString('language') ?? "en";
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeExt = Theme.of(context).extension<AppThemeExtension>();
    final bgImage = themeExt?.bgMain ?? 'assets/bg_pastel_main.jpg';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.translate("notifications")),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: () => _notificationService.markAllAsRead(widget.userId),
            tooltip: AppLocalizations.of(context)!.translate("mark_all_as_read"),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(bgImage),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<List<NotificationModel>>(
            stream: _notificationService.getNotifications(widget.userId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    '${AppLocalizations.of(context)!.translate("error")}: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.translate("loading"),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                );
              }

              final notifications = snapshot.data ?? [];

              if (notifications.isEmpty) {
                return Center(
                  child: Text(
                    AppLocalizations.of(context)!.translate("no_notifications"),
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }

              return ListView.builder(
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return Dismissible(
                    key: Key(notification.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (direction) {
                      // Handle dismiss for delete
                      _notificationService.deleteNotification(notification.id);
                    },
                    child: Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            leading: _buildNotificationIcon(notification),
                            title: Text(_getLocalizedTitle(context, notification)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_getLocalizedMessage(context, notification)),
                                Text(
                                  languageCode == 'th'
                                      ? timeago.format(notification.timestamp.toDate(), locale: 'th')
                                      : timeago.format(notification.timestamp.toDate()),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            trailing: notification.isRead
                                ? null
                                : Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                            onTap: () {
                              if (!notification.isRead) {
                                _notificationService.markAsRead(notification.id);
                              }
                              // Handle notification tap based on type
                              if (notification.type == 'friend_accepted' && 
                                  notification.data != null && 
                                  notification.data!.containsKey('chatroomId')) {
                                // Navigate to friend chatroom
                                _navigateToFriendChatroom(context, notification);
                              }
                            },
                          ),
                          // Friend request actions
                          if (notification.type == 'friend_request' && 
                              notification.data != null && 
                              notification.data!.containsKey('fromUserId') &&
                              notification.status != 'accepted' && 
                              notification.status != 'rejected')
                            Padding(
                              padding: const EdgeInsets.only(left: 72, right: 16, bottom: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  ElevatedButton(
                                    onPressed: () => _handleAcceptFriendRequest(notification),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                    child: Text(AppLocalizations.of(context)!.translate("accept")),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    onPressed: () => _handleRejectFriendRequest(notification),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                    child: Text(AppLocalizations.of(context)!.translate("reject")),
                                  ),
                                ],
                              ),
                            ),
                          // Status for already handled friend requests
                          if (notification.type == 'friend_request' && notification.status != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 72, right: 16, bottom: 12),
                              child: Text(
                                notification.status == 'accepted' 
                                    ? AppLocalizations.of(context)!.translate("request_accepted")
                                    : notification.status == 'rejected'
                                        ? AppLocalizations.of(context)!.translate("request_rejected")
                                        : '',
                                style: TextStyle(
                                  color: notification.status == 'accepted' ? Colors.green : Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // Handle accepting a friend request
  Future<void> _handleAcceptFriendRequest(NotificationModel notification) async {
    try {
      final requesterId = notification.data?['fromUserId'];
      if (requesterId != null) {
        await _notificationService.acceptFriendRequest(
          notificationId: notification.id,
          currentUserId: widget.userId,
          requesterId: requesterId,
        );
      }
    } catch (e) {
      print('Error accepting friend request: $e');
    }
  }

  // Handle rejecting a friend request
  Future<void> _handleRejectFriendRequest(NotificationModel notification) async {
    try {
      final requesterId = notification.data?['fromUserId'];
      if (requesterId != null) {
        await _notificationService.rejectFriendRequest(
          notificationId: notification.id,
          currentUserId: widget.userId,
          requesterId: requesterId,
        );
      }
    } catch (e) {
      print('Error rejecting friend request: $e');
    }
  }

  Widget _buildNotificationIcon(NotificationModel notification) {
    IconData iconData;
    Color iconColor;

    switch (notification.type) {
      case 'endorsement':
        iconData = Icons.star;
        iconColor = Colors.amber;
        break;
      case 'message':
        iconData = Icons.message;
        iconColor = Colors.blue;
        break;
      case 'friend_request':
        iconData = Icons.person_add;
        iconColor = Colors.green;
        break;
      case 'friend_accepted':
        iconData = Icons.check_circle;
        iconColor = Colors.green;
        break;
      default:
        iconData = Icons.notifications;
        iconColor = Colors.grey;
    }

    return CircleAvatar(
      backgroundColor: iconColor.withOpacity(0.1),
      child: Icon(iconData, color: iconColor),
    );
  }

  void _navigateToFriendChatroom(BuildContext context, NotificationModel notification) {
    // Here you would navigate to the friend chatroom
    // This will depend on how you've implemented your chat screens
    final chatroomId = notification.data?['chatroomId'];
    final friendId = notification.data?['userId'];
    final friendName = notification.data?['username'];
    
    if (chatroomId != null && friendId != null) {
      // You would replace this with your actual navigation code
      // For example:
      // Navigator.push(
      //   context,
      //   MaterialPageRoute(
      //     builder: (context) => FriendChatPage(
      //       chatroomId: chatroomId,
      //       friendId: friendId,
      //       friendName: friendName ?? 'Friend',
      //       currentUserId: widget.userId,
      //     ),
      //   ),
      // );
    }
  }

  String _getLocalizedTitle(BuildContext context, NotificationModel notification) {
    // Return a localized version of the notification title based on the type
    switch (notification.type) {
      case 'endorsement':
        return AppLocalizations.of(context)!.translate('endorsement_notification_title') ?? 'New Endorsement';
      case 'friend_request':
        return AppLocalizations.of(context)!.translate('friend_request_notification_title') ?? 'New Friend Request';
      case 'friend_accepted':
        return AppLocalizations.of(context)!.translate('friend_accepted_notification_title') ?? 'Friend Request Accepted';
      case 'message':
        return AppLocalizations.of(context)!.translate('message_notification_title') ?? 'New Message';
      default:
        return notification.title;
    }
  }

  String _getLocalizedMessage(BuildContext context, NotificationModel notification) {
    // Return a localized version of the notification message based on the type and data
    switch (notification.type) {
      case 'endorsement':
        if (notification.data != null && notification.data!['endorserName'] != null && notification.data!['skill'] != null) {
          final endorserName = notification.data!['endorserName'];
          final skill = notification.data!['skill'];
          // Use a format string with placeholders that can be translated
          final template = AppLocalizations.of(context)!.translate('endorsement_notification_message') ?? 
              '{0} endorsed your {1}!';
          return template.replaceAll('{0}', endorserName).replaceAll('{1}', skill);
        }
        break;
      case 'friend_request':
        if (notification.data != null && notification.data!['senderName'] != null) {
          final senderName = notification.data!['senderName'];
          final template = AppLocalizations.of(context)!.translate('friend_request_notification_message') ?? 
              '{0} wants to be your friend!';
          return template.replaceAll('{0}', senderName);
        }
        break;
      case 'friend_accepted':
        if (notification.data != null && notification.data!['username'] != null) {
          final username = notification.data!['username'];
          final template = AppLocalizations.of(context)!.translate('friend_accepted_notification_message') ?? 
              '{0} accepted your friend request!';
          return template.replaceAll('{0}', username);
        }
        break;
      case 'message':
        // For message notifications, we might need more context to create a good template
        return AppLocalizations.of(context)!.translate('message_notification_message') ?? 'You have received a new message';
    }
    
    // If we don't have a specific translation or the data is missing, fall back to the original message
    return notification.message;
  }
} 