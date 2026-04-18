import 'package:flutter/material.dart';
import 'package:hiddify/features/vpnpro_info_blocks/notifier/info_blocks_providers.dart';
import 'package:hiddify/features/vpnpro_info_blocks/widget/info_block_card.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Home-screen section that renders any currently-visible info blocks.
///
/// This is the **single integration point** for the info-blocks feature.
/// Insert one `const InfoBlocksSection()` on the home screen where blocks
/// should appear.
///
/// When there are no visible blocks (list empty or feature disabled in
/// [Branding]), this widget collapses to zero size — no layout impact.
class InfoBlocksSection extends ConsumerWidget {
  const InfoBlocksSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocks = ref.watch(visibleInfoBlocksProvider);
    if (blocks.isEmpty) return const SizedBox.shrink();

    // v1: render all visible blocks as a stack of cards. Typically one
    // block is shown at a time (controlled by Branding.maxInfoBlocksShown).
    // Future (ROADMAP Phase 3.1): optional carousel with swipe.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final block in blocks) InfoBlockCard(block: block),
      ],
    );
  }
}
