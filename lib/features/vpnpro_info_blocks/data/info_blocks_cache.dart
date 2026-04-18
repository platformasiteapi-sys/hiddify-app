import 'dart:convert';

import 'package:hiddify/branding/info_block.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// On-disk cache for the last successful `GET info_blocks` response.
///
/// Stored as a single JSON blob in [SharedPreferences]. Intentionally
/// a small brand-local utility — not worth a dedicated Drift table.
///
/// Keys are namespaced under `vpnpro.info_blocks.*` so upstream Hiddify
/// merges never see them.
class InfoBlocksCache with InfraLogger {
  InfoBlocksCache(this._prefs);

  static const _payloadKey = "vpnpro.info_blocks.cache_payload";
  static const _fetchedAtKey = "vpnpro.info_blocks.cache_fetched_at";

  final SharedPreferences _prefs;

  /// Returns the cached list, or `null` if no cache exists or the stored
  /// blob fails to parse (corrupted / schema drift).
  List<InfoBlock>? read() {
    final raw = _prefs.getString(_payloadKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      final blocks = <InfoBlock>[];
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        blocks.add(_fromJson(item));
      }
      return blocks;
    } catch (e, st) {
      loggy.warning("info_blocks cache corrupt — discarding", e, st);
      // Best-effort cleanup; failures here are harmless.
      _prefs.remove(_payloadKey);
      _prefs.remove(_fetchedAtKey);
      return null;
    }
  }

  /// Persists the list and stamps the fetch time. Silent on I/O failure.
  Future<void> write(List<InfoBlock> blocks) async {
    try {
      final payload = jsonEncode(blocks.map(_toJson).toList());
      await _prefs.setString(_payloadKey, payload);
      await _prefs.setInt(_fetchedAtKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e, st) {
      loggy.warning("info_blocks cache write failed", e, st);
    }
  }

  /// When was the cache last refreshed, or `null` if never.
  DateTime? fetchedAt() {
    final ms = _prefs.getInt(_fetchedAtKey);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// True when the cache is older than [ttl] or has never been populated.
  bool isStale(Duration ttl) {
    final at = fetchedAt();
    if (at == null) return true;
    return DateTime.now().difference(at) >= ttl;
  }

  static Map<String, dynamic> _toJson(InfoBlock b) => {
    "id": b.id,
    "title": b.title,
    "text": b.text,
    "cta_label": b.ctaLabel,
    "cta_url": b.ctaUrl,
    "dismissible": b.dismissible,
    "priority": b.priority,
    "expires_at": b.expiresAt?.toIso8601String(),
    "critical": b.critical,
  };

  static InfoBlock _fromJson(Map<String, dynamic> j) {
    final rawExpires = j["expires_at"];
    return InfoBlock(
      id: j["id"] as String,
      title: j["title"] as String,
      text: j["text"] as String,
      ctaLabel: j["cta_label"] as String?,
      ctaUrl: j["cta_url"] as String?,
      dismissible: j["dismissible"] as bool? ?? true,
      priority: (j["priority"] as num?)?.toInt() ?? 0,
      expiresAt: rawExpires is String ? DateTime.tryParse(rawExpires) : null,
      critical: j["critical"] as bool? ?? false,
    );
  }
}
