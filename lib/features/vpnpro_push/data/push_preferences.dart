import 'package:hiddify/core/utils/preferences_utils.dart';

/// Latest FCM registration token we received from the device.
///
/// Stored locally so a future backend integration can transparently pick
/// it up (see [Branding.deviceTokenEndpoint]) without any changes to the
/// token-refresh flow. While no backend is configured this value is
/// informational only.
final pushFcmTokenPref = PreferencesNotifier.create<String?, String?>(
  "vpnpro.push.fcm_token",
  null,
);

/// Topics the current install has confirmed to FCM. Used to avoid
/// re-subscribing on every app launch — we only call
/// `subscribeToTopic` for topics not in this set.
///
/// Stored as a delimited string list by the shared [PreferencesNotifier]
/// utility (see `core/utils/preferences_utils.dart`).
final pushSubscribedTopicsPref =
    PreferencesNotifier.create<List<String>, List<String>>(
  "vpnpro.push.subscribed_topics",
  const <String>[],
);

/// Whether the user has granted OS-level notification permission.
/// We only request once per install — subsequent refusals persist here
/// and we don't pester the user. Settings screen can later expose a
/// re-request action.
final pushPermissionGrantedPref = PreferencesNotifier.create<bool, bool>(
  "vpnpro.push.permission_granted",
  false,
);
