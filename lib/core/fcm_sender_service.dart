import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    String jsonString;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedKey = prefs.getString('fcm_service_account_json');
      if (savedKey != null && savedKey.isNotEmpty && savedKey != '{}') {
        jsonString = savedKey;
      } else {
        jsonString = await rootBundle.loadString('assets/service_account.json');
      }
    } catch (e) {
      jsonString = await rootBundle.loadString('assets/service_account.json');
    }

    final accountCredentials =
        ServiceAccountCredentials.fromJson(json.decode(jsonString));

    final client = CorsProxyClient(http.Client());
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
    String? imageUrl,
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
            if (imageUrl != null && imageUrl.isNotEmpty) 'image': imageUrl,
          },
          'data': data ?? {},
          'android': {
            'priority': 'high',
            'notification': {
              'channel_id': 'dynamo_chess_channel',
              'sound': 'default',
              if (imageUrl != null && imageUrl.isNotEmpty) 'image': imageUrl,
            },
          },
          'apns': {
            'payload': {
              'aps': {
                'mutable-content': 1,
              },
            },
            'fcm_options': {
              if (imageUrl != null && imageUrl.isNotEmpty) 'image': imageUrl,
            },
          },
        },
      };

      final client = CorsProxyClient(http.Client());
      try {
        final response = await client.post(
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
          throw 'FCM error ${response.statusCode}: ${response.body}';
        }
      } finally {
        client.close();
      }
    } catch (e) {
      print('❌ Error sending push notification: $e');
      rethrow;
    }
  }

  /// Send a push notification to multiple device tokens (for broadcasts).
  static Future<void> sendToMultiple({
    required List<String> tokens,
    required String title,
    required String body,
    String? imageUrl,
  }) async {
    for (final token in tokens) {
      await sendToToken(token: token, title: title, body: body, imageUrl: imageUrl);
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

/// A custom HTTP client that proxies requests on the Web to bypass CORS restrictions.
class CorsProxyClient extends http.BaseClient {
  final http.Client _inner;
  CorsProxyClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (kIsWeb) {
      final originalUrl = request.url.toString();
      // Consume request stream and fold into a list of bytes
      final List<int> bytes = await request.finalize().fold<List<int>>(<int>[], (a, b) => a..addAll(b));

      final List<String> proxyTemplates = [
        '', // Direct connection (succeeds instantly if CORS bypass extension is enabled)
        'https://api.cors.lol/?url=',
        'https://proxy.corsfix.com/?url=',
        'https://corsproxy.io/?',
      ];

      Object? lastError;
      http.StreamedResponse? lastResponse;

      for (final template in proxyTemplates) {
        try {
          final proxiedUrl = template.isEmpty ? originalUrl : '$template${Uri.encodeComponent(originalUrl)}';
          final newRequest = http.StreamedRequest(request.method, Uri.parse(proxiedUrl));
          newRequest.headers.addAll(request.headers);
          newRequest.sink.add(bytes);
          newRequest.sink.close();

          final response = await _inner.send(newRequest);
          if (response.statusCode < 400) {
            return response;
          }
          lastResponse = response;
        } catch (e) {
          lastError = e;
        }
      }

      if (lastResponse != null) {
        return lastResponse;
      }
      if (lastError != null) {
        throw lastError;
      }
      throw http.ClientException('Failed to send request via any CORS proxy', request.url);
    }
    return _inner.send(request);
  }
}
