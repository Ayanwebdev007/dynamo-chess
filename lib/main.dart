import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
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
  
  // Custom global error builder to eliminate blank white screens in release mode
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFF0A0E0A),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFD4AF37), size: 48),
              const SizedBox(height: 16),
              Text(
                "TACTICAL DATA RENDER FAULT",
                style: GoogleFonts.cinzel(
                  color: const Color(0xFFD4AF37),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                details.exceptionAsString(),
                textAlign: TextAlign.center,
                style: GoogleFonts.robotoMono(
                  color: Colors.white54,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  };

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  debugPrint('🚀 Starting Dynamo Chess...');

  try {
    await SettingsController().init();
    debugPrint('✅ Settings initialized');
  } catch (e) {
    debugPrint('❌ Settings init failed: $e');
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

  try {
    AudioService().init();
    await NotificationService().init();
    debugPrint('✅ Audio & Notification services initialized');
  } catch (e) {
    debugPrint('❌ Audio/Notification service init failed: $e');
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
        scaffoldBackgroundColor: const Color(0xFF0A0E0A),
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFD4AF37),
          surface: Color(0xFF0A0E0A),
          onSurface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A0E0A),
          surfaceTintColor: Colors.transparent,
        ),
        tabBarTheme: const TabBarThemeData(
          dividerColor: Colors.transparent,
        ),
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
