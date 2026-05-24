import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_service_base.dart';
import 'online_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService implements NotificationServiceBase {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  @override
  Future<void> init() async {
    // 1. Request FCM Permissions
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Setup Local Notifications
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(initSettings);

    // Create Android Notification Channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'dynamo_chess_channel',
      'Dynamo Chess Notifications',
      description: 'Notifications for challenges and announcements',
      importance: Importance.max,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 3. Get and Save FCM Token
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await OnlineService().saveFcmToken(user.uid, token);
        }
      }
    } catch (e) {
      print("Error saving FCM token: $e");
    }

    // Listen for FCM token refreshes and update them in database
    _fcm.onTokenRefresh.listen((token) async {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await OnlineService().saveFcmToken(user.uid, token);
        }
      } catch (e) {
        print("Error saving refreshed FCM token: $e");
      }
    });

    // 4. Listen for foreground FCM messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        showNotification(
          message.notification!.title ?? "New Challenge",
          message.notification!.body ?? "Someone challenged you!",
        );
      }
    });
  }

  @override
  void showNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'dynamo_chess_channel',
      'Dynamo Chess Notifications',
      channelDescription: 'Notifications for challenges and announcements',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
    
    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      platformDetails,
    );
  }

  @override
  Future<void> saveTokenForUser(String userId) async {
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        await OnlineService().saveFcmToken(userId, token);
        print("✅ FCM Token saved for user: $userId");
      }
    } catch (e) {
      print("❌ Error saving FCM token for user $userId: $e");
    }
  }
}
