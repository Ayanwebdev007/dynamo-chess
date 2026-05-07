import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'ui/main_menu.dart';
import 'core/audio_service.dart';
import 'core/settings_controller.dart';
import 'core/notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  debugPrint('🚀 Starting Dynamo Chess...');

  // 1. Initialize settings with error handling
  try {
    await SettingsController().init();
    debugPrint('✅ Settings initialized');
  } catch (e) {
    debugPrint('❌ Settings init failed: $e');
  }
  
  // 2. Initialize audio
  try {
    AudioService().init();
    NotificationService().init();
    debugPrint('✅ Audio service initialized');
  } catch (e) {
    debugPrint('❌ Audio service init failed: $e');
  }
  
  // 3. Initialize Firebase
  try {
    debugPrint('🔥 Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 10));
    debugPrint('✅ Firebase initialized');
  } catch (e) {
    debugPrint('❌ Firebase init failed: $e');
    // Continue anyway - app has offline mode
  }
  
  runApp(const DynamoChessApp());
  debugPrint('🎮 App running');
}

class DynamoChessApp extends StatelessWidget {
  const DynamoChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dynamo Chess 2020',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFD4AF37),
        useMaterial3: true,
      ),
      home: const MainMenuScreen(),
    );
  }
}
