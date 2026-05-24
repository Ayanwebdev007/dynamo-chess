import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart';

/// Client-side FCM sender using the HTTP v1 API.
/// Reads the service-account key bundled in assets, obtains an OAuth2 token,
/// and POSTs directly to the FCM v1 endpoint.
class FcmSenderService {
  static const String _projectId = 'dynamo-chess-6ad12';
  static const String _fcmUrl =
      'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send';

  static final List<String> _scopes = [
    'https://www.googleapis.com/auth/firebase.messaging',
  ];

  static AccessCredentials? _cachedCredentials;

  /// Obtain (or reuse) an OAuth2 access-token from the bundled service-account.
  static Future<String> _getAccessToken() async {
    // Reuse token if it hasn't expired yet
    if (_cachedCredentials != null &&
        _cachedCredentials!.accessToken.expiry
            .isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      return _cachedCredentials!.accessToken.data;
    }

    final jsonString =
        await rootBundle.loadString('assets/service_account.json');
    final accountCredentials =
        ServiceAccountCredentials.fromJson(json.decode(jsonString));

    final client = http.Client();
    try {
      _cachedCredentials =
          await obtainAccessCredentialsViaServiceAccount(
        accountCredentials,
        _scopes,
        client,
      );
      return _cachedCredentials!.accessToken.data;
    } finally {
      client.close();
    }
  }

  /// Send a push notification to a single device token.
  static Future<void> sendToToken({
    required String token,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      final accessToken = await _getAccessToken();

      final payload = {
        'message': {
          'token': token,
          'notification': {
            'title': title,
            'body': body,
          },
          'data': data ?? {},
          'android': {
            'priority': 'high',
            'notification': {
              'channel_id': 'dynamo_chess_channel',
              'sound': 'default',
            },
          },
        },
      };

      final response = await http.post(
        Uri.parse(_fcmUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        print('✅ Push notification sent successfully');
      } else {
        print('❌ FCM error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Error sending push notification: $e');
    }
  }

  /// Send a push notification to multiple device tokens (for broadcasts).
  static Future<void> sendToMultiple({
    required List<String> tokens,
    required String title,
    required String body,
  }) async {
    for (final token in tokens) {
      await sendToToken(token: token, title: title, body: body);
    }
  }

  /// Helper: fetch a user's FCM token from the database.
  static Future<String?> getUserFcmToken(String userId) async {
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(userId)
          .child('fcmToken')
          .get();
      if (snapshot.exists) {
        return snapshot.value as String?;
      }
    } catch (e) {
      print('Error fetching FCM token for $userId: $e');
    }
    return null;
  }

  /// Helper: fetch ALL user FCM tokens (for broadcast notifications).
  static Future<List<String>> getAllFcmTokens() async {
    final tokens = <String>[];
    try {
      final snapshot =
          await FirebaseDatabase.instance.ref().child('users').get();
      if (snapshot.exists) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
        data.forEach((key, value) {
          if (value is Map && value['fcmToken'] != null) {
            tokens.add(value['fcmToken'].toString());
          }
        });
      }
    } catch (e) {
      print('Error fetching all FCM tokens: $e');
    }
    return tokens;
  }
}
