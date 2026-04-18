import 'package:hiddify/branding/branding.dart';
import 'package:hiddify/branding/info_block.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/vpnpro_info_blocks/data/dismissed_blocks_preference.dart';
import 'package:hiddify/features/vpnpro_info_blocks/data/info_blocks_cache.dart';
import 'package:hiddify/features/vpnpro_info_blocks/data/info_blocks_repository.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'info_blocks_providers.g.dart';

/// Remote-driven source of info blocks with on-disk cache and a
/// `hardcoded` last-resort fallback.
///
/// Lifecycle:
///   1. `build()` reads the SharedPreferences cache synchronously via
///      `ref.read(sharedPreferencesProvider).requireValue` (we know it's
///      ready because bootstrap awaits it).
///   2. If the cache is fresh (< [Branding.infoBlocksCacheTtl] old), we
///      return it immediately and skip the network entirely.
///   3. If the cache is stale but present, we return it right away **and**
///      schedule a background refresh so consumers see updated content
///      without a visible loading flicker.
///   4. If there's no cache at all (first launch), we try a blocking
///      fetch; on failure we fall back to [Branding.infoBlocksHardcoded]
///      so the app never sits with an empty home screen on cold start.
///
/// When [Branding.infoBlocksEndpoint] is null, remote is disabled and we
/// always serve the hardcoded list — a kill switch for offline builds.
@Riverpod(keepAlive: true)
class InfoBlocksSource extends _$InfoBlocksSource with InfraLogger {
  InfoBlocksCache? _cache;

  @override
  Future<List<InfoBlock>> build() async {
    final prefs = ref.watch(sharedPreferencesProvider).requireValue;
    final cache = _cache = InfoBlocksCache(prefs);

    // No endpoint → permanent hardcoded mode. Still honour enableInfoBlocks
    // at the consumer level (visibleInfoBlocksProvider).
    if (Branding.infoBlocksEndpoint == null) {
      return Branding.infoBlocksHardcoded;
    }

    final cached = cache.read();
    final fresh = cached != null && !cache.isStale(Branding.infoBlocksCacheTtl);

    if (fresh) {
      loggy.debug("info_blocks cache hit (${cached.length} blocks)");
      return cached;
    }

    // Stale but present: return old data instantly, refresh in background.
    if (cached != null) {
      loggy.debug("info_blocks cache stale, scheduling background refresh");
      Future.microtask(refresh);
      return cached;
    }

    // Cold path: no cache. Attempt a real fetch, fall back to hardcoded.
    try {
      final remote = await ref.read(infoBlocksRepositoryProvider).fetch();
      await cache.write(remote);
      loggy.debug("info_blocks initial fetch ok (${remote.length} blocks)");
      return remote;
    } catch (e, st) {
      loggy.warning("info_blocks initial fetch failed → hardcoded fallback", e, st);
      return Branding.infoBlocksHardcoded;
    }
  }

  /// Forces a refetch. Called on app resume and any time we want to push
  /// out a manual reload. Errors are swallowed: we keep the current state
  /// rather than flipping to [AsyncError] and hiding the UI.
  Future<void> refresh() async {
    if (Branding.infoBlocksEndpoint == null) return;
    final cache = _cache;
    if (cache == null) return;

    try {
      final remote = await ref.read(infoBlocksRepositoryProvider).fetch();
      await cache.write(remote);
      state = AsyncData(remote);
      loggy.debug("info_blocks refreshed (${remote.length} blocks)");
    } catch (e, st) {
      loggy.warning("info_blocks refresh failed (keeping current state)", e, st);
    }
  }
}

/// Currently-visible info blocks for the home screen.
///
/// Filter pipeline (runs every rebuild — cheap):
///   1. [Branding.enableInfoBlocks] master switch
///   2. Drop blocks whose [InfoBlock.expiresAt] has passed (defence-in-
///      depth — the server already filters by `expires_at > now()`, but
///      a cached row could have expired between fetches)
///   3. Drop blocks the user has dismissed ([dismissedInfoBlockIdsPref])
///   4. Sort by priority (desc)
///   5. Truncate to [Branding.maxInfoBlocksShown]
///
/// The [infoBlocksSourceProvider] is async, but we unwrap it with a
/// [Branding.infoBlocksHardcoded] fallback so the widget stays simple
/// (plain synchronous `List<InfoBlock>`).
final visibleInfoBlocksProvider = Provider<List<InfoBlock>>((ref) {
  if (!Branding.enableInfoBlocks) return const [];

  final source = ref.watch(infoBlocksSourceProvider);
  final blocks = source.valueOrNull ?? Branding.infoBlocksHardcoded;

  final dismissed = ref.watch(dismissedInfoBlockIdsPref).toSet();

  final filtered = blocks
      .where((b) => !b.isExpired)
      .where((b) => !dismissed.contains(b.id))
      .toList()
    ..sort((a, b) => b.priority.compareTo(a.priority));

  const max = Branding.maxInfoBlocksShown;
  if (max > 0 && filtered.length > max) {
    return filtered.sublist(0, max);
  }
  return filtered;
});
