import 'package:flutter/material.dart';
import 'package:hiddify/branding/info_block.dart';
import 'package:hiddify/features/vpnpro_info_blocks/data/dismissed_blocks_preference.dart';
import 'package:hiddify/utils/uri_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Renders a single [InfoBlock] as a compact card.
///
/// Layout:
/// ```text
/// ┌───────────────────────────────────────┐
/// │ [icon]  Title                       ✕ │
/// │         Body text (2-3 lines max)     │
/// │         [CTA button →]                │
/// └───────────────────────────────────────┘
/// ```
///
/// Styling follows Material 3, using the same corner radius / margin as
/// other home-screen cards (profile_tile, active_proxy_card).
class InfoBlockCard extends ConsumerWidget {
  const InfoBlockCard({required this.block, super.key});

  final InfoBlock block;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final bg =
        block.critical ? colors.errorContainer : colors.surfaceContainerHighest;
    final fg = block.critical ? colors.onErrorContainer : colors.onSurface;
    final accent = block.critical ? colors.error : colors.primary;

    final hasCta = block.ctaLabel != null && block.ctaUrl != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: bg,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          block.dismissible ? 4 : 16,
          hasCta ? 4 : 12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                block.critical
                    ? Icons.warning_amber_rounded
                    : Icons.campaign_outlined,
                color: accent,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    block.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (block.text.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      block.text,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: fg.withValues(alpha: 0.85),
                        height: 1.3,
                      ),
                    ),
                  ],
                  if (hasCta) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: () =>
                            UriUtils.tryLaunch(Uri.parse(block.ctaUrl!)),
                        style: TextButton.styleFrom(
                          foregroundColor: accent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(block.ctaLabel!),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_rounded, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (block.dismissible)
              IconButton(
                tooltip: "Закрыть",
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: fg.withValues(alpha: 0.6),
                ),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                onPressed: () async {
                  final notifier =
                      ref.read(dismissedInfoBlockIdsPref.notifier);
                  final current = ref.read(dismissedInfoBlockIdsPref);
                  if (!current.contains(block.id)) {
                    await notifier.update([...current, block.id]);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
