abstract class NotificationServiceBase {
  Future<void> init();
  void showNotification(String title, String body);
}
