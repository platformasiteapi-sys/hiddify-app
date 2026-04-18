import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:hiddify/branding/branding.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/vpnpro_push/data/push_preferences.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Thin wrapper around `firebase_messaging` for the VPN Pro brand.
///
/// Responsibilities:
///   * Initialise the Firebase default app (idempotent).
///   * Request OS notification permission once per install.
///   * Subscribe to the topics listed in [Branding.defaultPushTopics].
///   * Persist the current FCM token so a future backend integration can
///     just start reading it (see [Branding.deviceTokenEndpoint]).
///   * Listen for token refresh + (when configured) POST to the backend.
///
/// Does **not** display foreground notifications. When the app is open
/// and a message arrives, it is silently delivered to
/// [FirebaseMessaging.onMessage] and the system does not show a banner.
/// Background / terminated delivery works normally and shows the OS
/// notification from the `notification` payload sent via Firebase Console.
///
/// Call [PushService.init] from `bootstrap.dart` wrapped in `_safeInit`
/// so initialisation failures (missing config, unsupported platform,
/// Google Play Services absent on some Android devices) do not crash
/// the whole app.
class PushService with InfraLogger {
  PushService._(this._ref);

  final Ref _ref;

  static PushService? _instance;

  /// Initialise the service. Safe to call multiple times — subsequent
  /// calls short-circuit. Must be called after shared_preferences is
  /// ready (the service reads/writes preferences).
  static Future<void> init(Ref ref) async {
    if (!Branding.enablePushNotifications) return;
    if (!_isSupportedPlatform()) return;
    if (_instance != null) return;

    final service = PushService._(ref);
    await service._bootstrap();
    _instance = service;
  }

  static bool _isSupportedPlatform() {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  Future<void> _bootstrap() async {
    // Step 1: initialise Firebase itself. Fails if google-services.json /
    // GoogleService-Info.plist is missing — that's OK, _safeInit in
    // bootstrap.dart will swallow the error and the rest of the app runs.
    await Firebase.initializeApp();
    loggy.info("firebase core initialised");

    // Step 2: request notification permission (no-op on Android <13, shown
    // as modal on Android 13+ and iOS).
    await _ensurePermission();

    // Step 3: subscribe to broadcast topics. We remember which topics we've
    // already subscribed to so restarts don't hammer the FCM API.
    await _subscribeToDefaultTopics();

    // Step 4: capture the current token and wire up refresh listener.
    await _syncToken();

    // Step 5: set up message handlers. Delivered only when app is in
    // foreground; system handles background automatically.
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTapped);
  }

  Future<void> _ensurePermission() async {
    final prefs = _ref.read(pushPermissionGrantedPref);
    if (prefs) {
      // Already granted on a previous launch — trust it (the user can
      // still revoke in OS settings; messaging will just stop arriving).
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;
      // Defaults: alert+badge+sound, non-provisional. See
      // https://pub.dev/documentation/firebase_messaging/latest/firebase_messaging/FirebaseMessaging/requestPermission.html
      final settings = await messaging.requestPermission();
      final granted = settings.authorizationStatus ==
              AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      loggy.info("notification permission: ${settings.authorizationStatus}");
      await _ref.read(pushPermissionGrantedPref.notifier).update(granted);
    } catch (e, st) {
      loggy.warning("permission request failed", e, st);
    }
  }

  Future<void> _subscribeToDefaultTopics() async {
    final already = _ref.read(pushSubscribedTopicsPref).toSet();
    final want = Branding.defaultPushTopics.toSet();
    final toAdd = want.difference(already);

    if (toAdd.isEmpty) return;

    final messaging = FirebaseMessaging.instance;
    final confirmed = <String>[...already];
    for (final topic in toAdd) {
      try {
        await messaging.subscribeToTopic(topic);
        confirmed.add(topic);
        loggy.info("subscribed to topic: $topic");
      } catch (e, st) {
        loggy.warning("subscribe to topic [$topic] failed", e, st);
      }
    }

    if (confirmed.length != already.length) {
      await _ref.read(pushSubscribedTopicsPref.notifier).update(confirmed);
    }
  }

  Future<void> _syncToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token != null) {
        await _persistToken(token);
      }
      messaging.onTokenRefresh.listen(_persistToken);
    } catch (e, st) {
      loggy.warning("fetching fcm token failed", e, st);
    }
  }

  Future<void> _persistToken(String token) async {
    final stored = _ref.read(pushFcmTokenPref);
    if (stored == token) return;
    await _ref.read(pushFcmTokenPref.notifier).update(token);
    loggy.info("fcm token updated (${token.substring(0, 12)}…)");

    // Hook for future backend integration. Intentionally a no-op while
    // [Branding.deviceTokenEndpoint] is null — see the field's doc comment.
    if (Branding.deviceTokenEndpoint != null) {
      await _reportTokenToBackend(token);
    }
  }

  Future<void> _reportTokenToBackend(String token) async {
    // Placeholder — wire Dio POST here when the backend exists.
    loggy.debug("would POST token to ${Branding.deviceTokenEndpoint}");
  }

  void _onForegroundMessage(RemoteMessage message) {
    loggy.info(
      "foreground message: ${message.messageId} "
      "notification=${message.notification?.title}",
    );
    // v1: no UI for foreground messages. A future change can surface them
    // via flutter_local_notifications or an in-app snackbar.
  }

  void _onNotificationTapped(RemoteMessage message) {
    loggy.info("notification tapped: ${message.data}");
    // v1: opening the app is enough. When deep-link payloads are
    // introduced (roadmap Phase 8), parse `message.data` here and
    // route accordingly.
  }
}

/// Provider wrapper so the Riverpod-centric bootstrap can kick off the
/// service. The bootstrap currently uses `container.read(provider.future)`
/// patterns — exposing a `FutureProvider` matches that.
final pushServiceProvider = FutureProvider<void>((ref) async {
  // Ensure shared_preferences is ready — all the `pushXxxPref` providers
  // read it synchronously.
  await ref.read(sharedPreferencesProvider.future);
  await PushService.init(ref);
});
