import 'package:hiddify/core/utils/preferences_utils.dart';

/// IDs of info blocks that the user has dismissed via the ✕ button.
///
/// Stored as a delimited string in [SharedPreferences] by the shared
/// [PreferencesNotifier] utility. Persists across app restarts.
///
/// Kept in this brand-local file (not in `core/preferences/general_preferences.dart`)
/// so upstream Hiddify merges never touch it.
final dismissedInfoBlockIdsPref =
    PreferencesNotifier.create<List<String>, List<String>>(
  "vpnpro.info_blocks.dismissed_ids",
  const <String>[],
);
