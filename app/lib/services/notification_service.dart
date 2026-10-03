import 'package:firebase_messaging/firebase_messaging.dart';

import 'api_client.dart';

/// Background message handler — must stay top-level for FCM.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No Firebase init needed here: the backend sends data-only fallbacks and
  // notification messages are rendered by the system tray automatically.
}

/// Firebase Cloud Messaging: permission, token registration, and
/// foreground / tap handling for job invites, status changes, wage entries.
class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final ApiClient _api;

  NotificationService(this._api);

  Stream<RemoteMessage> get onForegroundMessage => FirebaseMessaging.onMessage;
  Stream<RemoteMessage> get onMessageOpened =>
      FirebaseMessaging.onMessageOpenedApp;

  Future<void> initialize() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await registerToken();
    // Keep the backend token fresh.
    _messaging.onTokenRefresh.listen((token) {
      _registerWithBackend(token);
    });
  }

  /// Sends the current FCM token to the backend (derived user from ID token).
  /// Safe to call when signed out — it becomes a no-op.
  Future<void> registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) await _registerWithBackend(token);
    } catch (_) {
      // Best effort; retried on next app start / login.
    }
  }

  Future<void> _registerWithBackend(String token) async {
    try {
      await _api.post('/api/users/me/device-token', {'token': token});
    } catch (_) {
      // Best effort; retried on next app start / login.
    }
  }

  Future<void> subscribeToJob(String jobId) async {
    try {
      await _messaging.subscribeToTopic('job_$jobId');
    } catch (_) {}
  }

  Future<void> unsubscribeFromJob(String jobId) async {
    try {
      await _messaging.unsubscribeFromTopic('job_$jobId');
    } catch (_) {}
  }
}
