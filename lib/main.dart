import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'ui/main_menu.dart';
import 'core/audio_service.dart';
import 'core/settings_controller.dart';
import 'core/notification_service.dart';
import 'ui/admin/admin_dashboard.dart';
import 'ui/admin/admin_login.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  debugPrint('🚀 Starting Dynamo Chess...');

  try {
    await SettingsController().init();
    debugPrint('✅ Settings initialized');
  } catch (e) {
    debugPrint('❌ Settings init failed: $e');
  }
  
  try {
    AudioService().init();
    NotificationService().init();
    debugPrint('✅ Audio service initialized');
  } catch (e) {
    debugPrint('❌ Audio service init failed: $e');
  }
  
  try {
    debugPrint('🔥 Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 10));
    debugPrint('✅ Firebase initialized');
  } catch (e) {
    debugPrint('❌ Firebase init failed: $e');
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
      initialRoute: '/',
      onGenerateRoute: (settings) {
        final name = settings.name ?? '/';
        
        // Handle Admin Sub-routes
        if (name == '/admin/login') {
          return MaterialPageRoute(builder: (context) => const AdminLoginScreen());
        }
        
        if (name.startsWith('/admin')) {
          AdminTab tab = AdminTab.overview;
          if (name == '/admin/users') tab = AdminTab.users;
          if (name == '/admin/games') tab = AdminTab.games;
          if (name == '/admin/analytics') tab = AdminTab.analytics;
          if (name == '/admin/settings') tab = AdminTab.settings;
          
          return MaterialPageRoute(
            builder: (context) => AdminDashboardScreen(initialTab: tab),
            settings: settings,
          );
        }
        
        // Default to Main Menu
        return MaterialPageRoute(builder: (context) => const MainMenuScreen());
      },
    );
  }
}
