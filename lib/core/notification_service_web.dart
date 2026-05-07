import 'dart:html' as html;
import 'notification_service_base.dart';

class NotificationService implements NotificationServiceBase {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _isSupported = false;

  @override
  Future<void> init() async {
    _isSupported = html.Notification.supported;
    if (_isSupported && html.Notification.permission == 'default') {
      html.Notification.requestPermission();
    }
  }

  @override
  void showNotification(String title, String body) {
    if (_isSupported && html.Notification.permission == 'granted') {
      html.Notification(title, body: body);
    }
  }
}
