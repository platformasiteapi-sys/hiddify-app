import 'package:hiddify/branding/branding.dart';
import 'package:hiddify/branding/info_block.dart';
import 'package:hiddify/features/vpnpro_info_blocks/data/dismissed_blocks_preference.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Currently-visible info blocks for the home screen.
///
/// Filter pipeline:
///   1. [Branding.enableInfoBlocks] master switch
///   2. Drop blocks whose [InfoBlock.expiresAt] has passed
///   3. Drop blocks the user has dismissed ([dismissedInfoBlockIdsPref])
///   4. Sort by priority (desc)
///   5. Truncate to [Branding.maxInfoBlocksShown]
///
/// When a server-driven data source is added (Phase 3.1), only this
/// provider changes — consumers (widgets) stay the same.
final visibleInfoBlocksProvider = Provider<List<InfoBlock>>((ref) {
  if (!Branding.enableInfoBlocks) return const [];

  final dismissed = ref.watch(dismissedInfoBlockIdsPref).toSet();

  final filtered = Branding.infoBlocksHardcoded
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
