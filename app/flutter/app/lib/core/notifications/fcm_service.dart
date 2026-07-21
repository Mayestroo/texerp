import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:texerp/core/network/api_client.dart';

// Top-level background handler (must be outside class)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Background message: ${message.messageId}');
}

/// Service that manages Firebase Cloud Messaging tokens and local notifications.
class FcmService {
  FcmService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _deepLinkController =
      StreamController<String>.broadcast();
  String? _fcmToken;
  String? _pendingDeepLink;
  StreamSubscription<String>? _tokenRefreshSubscription;
  bool _isAuthenticated = false;

  String? get fcmToken => _fcmToken;

  /// The last deep link from a tapped notification. Consumed on read.
  String? get pendingDeepLink {
    final link = _pendingDeepLink;
    _pendingDeepLink = null;
    return link;
  }

  /// Emits deep links from tapped notifications for in-app navigation.
  Stream<String> get deepLinkStream => _deepLinkController.stream;

  Future<void> initialize() async {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Setup local notifications for Android first
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          try {
            final data = jsonDecode(payload) as Map<String, dynamic>;
            final deepLink = data['deep_link'] as String?;
            if (deepLink != null && deepLink.startsWith('/')) {
              _handleDeepLink(deepLink);
            }
          } catch (e) {
            debugPrint('Failed to parse notification payload: $e');
          }
        }
      },
    );

    // Request permissions
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Get initial token but do not register it until AuthBloc confirms auth.
      _fcmToken = await FirebaseMessaging.instance.getToken();

      // Listen for token refresh and register only when authenticated.
      _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) {
          _fcmToken = token;
          if (_isAuthenticated) {
            _registerTokenWithBackend(token);
          }
        },
      );

      // Foreground message handler
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Notification tap handler (app opened from notification)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

      // Check if app was opened from terminated state
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageTap(initialMessage);
      }
    }
  }

  /// Called by AuthBloc after a successful login or refresh. Registers the
  /// current FCM token with the backend.
  Future<void> registerToken() async {
    _isAuthenticated = true;

    // Re-acquire token if null (e.g. after logout/relogin in same session)
    _fcmToken ??= await FirebaseMessaging.instance.getToken();

    // Re-establish token refresh subscription if cancelled
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _fcmToken = token;
      if (_isAuthenticated) {
        _registerTokenWithBackend(token);
      }
    });

    // Register with backend
    if (_fcmToken != null) {
      await _registerTokenWithBackend(_fcmToken!);
    }
  }

  Future<void> _registerTokenWithBackend(String token) async {
    try {
      await _apiClient.dio.put(
        '/users/me/fcm-token',
        data: {'fcm_token': token},
      );
    } catch (e) {
      debugPrint('Failed to register FCM token: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'texerp_default',
            'TexERP Notifications',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  void _handleMessageTap(RemoteMessage message) {
    final data = message.data;
    debugPrint('Notification tapped: $data');
    final deepLink = data['deep_link'] as String?;
    if (deepLink != null && deepLink.startsWith('/')) {
      _handleDeepLink(deepLink);
    }
  }

  void _handleDeepLink(String deepLink) {
    const allowedPaths = [
      '/worker/payroll/',
      '/worker/history/',
      '/notifications',
      '/foreman/pending',
      '/payroll/export/',
    ];
    final isAllowed = allowedPaths.any((p) => deepLink.startsWith(p)) ||
        deepLink == '/notifications' ||
        deepLink == '/foreman/pending';
    if (!isAllowed) {
      debugPrint('Deep link rejected: $deepLink');
      return;
    }
    if (!_isAuthenticated) {
      // Buffer for GoRouter to consume after the user authenticates.
      _pendingDeepLink = deepLink;
      return;
    }
    _pendingDeepLink = deepLink;
    _deepLinkController.add(deepLink);
  }

  /// Called on logout to clear the in-memory token and delete the FCM token.
  Future<void> unsubscribe() async {
    _isAuthenticated = false;
    _pendingDeepLink = null;
    // Don't delete the token or cancel the subscription — keep for re-login
    // The backend will stop sending pushes because we unregister there
  }
}
