import 'package:flutter/foundation.dart';

/// Brand-managed notice shown in a card on the home screen.
///
/// Currently sourced from [Branding.infoBlocksHardcoded]; a future phase
/// (3.1) will add a server endpoint and transparently swap the data source.
///
/// Kept under `lib/branding/` because the content is brand-specific and
/// conceptually part of the product configuration, not core feature code.
@immutable
class InfoBlock {
  const InfoBlock({
    required this.id,
    required this.title,
    required this.text,
    this.ctaLabel,
    this.ctaUrl,
    this.dismissible = true,
    this.priority = 0,
    this.expiresAt,
    this.critical = false,
  });

  /// Stable identifier. Persisted when the user dismisses the block —
  /// changing the id re-shows the block (useful when content changes).
  final String id;

  final String title;
  final String text;

  /// Optional call-to-action. If both [ctaLabel] and [ctaUrl] are set,
  /// a text button appears under the body.
  final String? ctaLabel;
  final String? ctaUrl;

  /// Whether the user can tap ✕ to hide the block permanently.
  /// Set `false` for announcements that must be seen (maintenance).
  final bool dismissible;

  /// Higher priority blocks are shown first when multiple match.
  final int priority;

  /// After this moment the block stops being shown. `null` = no expiry.
  final DateTime? expiresAt;

  /// If true, renders with error/warning styling to draw attention.
  /// Use for outages, maintenance, security advisories.
  final bool critical;

  /// True when [expiresAt] has passed.
  bool get isExpired {
    final expiry = expiresAt;
    return expiry != null && !DateTime.now().isBefore(expiry);
  }
}
