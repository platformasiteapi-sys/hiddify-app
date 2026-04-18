import 'package:hiddify/branding/info_block.dart';

/// Central place for all brand-specific values.
///
/// IMPORTANT: Keep **all** customization here. Never inline brand strings
/// elsewhere — that makes upstream merges painful. Other code (including
/// [Constants]) should reference these fields.
///
/// When syncing with upstream Hiddify:
///   - This file lives only on the brand branch. It should never conflict
///     with upstream (upstream does not know it exists).
///   - Conflicts will appear in files that *reference* this (e.g. Constants).
///     Keep those references minimal.
abstract class Branding {
  // ---- Identity ----
  static const appName = "VPN Pro";

  // ---- URLs (TODO: replace with real values before release) ----
  // Until real values are set, fall back to Hiddify's so auto-update /
  // "About" links don't break the build. Change these before shipping.
  static const siteUrl = "https://hiddify.com";
  static const supportUrl = "https://hiddify.com";
  static const privacyPolicyUrl = "https://hiddify.com/privacy-policy/";
  static const termsAndConditionsUrl = "https://hiddify.com/terms/";
  static const telegramChannelUrl = "https://t.me/hiddify";

  // ---- Release channel (auto-update). ----
  // MUST be changed before public release or users will update to Hiddify.
  static const githubUrl = "https://github.com/hiddify/hiddify-next";
  static const githubReleasesApiUrl =
      "https://api.github.com/repos/hiddify/hiddify-next/releases";
  static const githubLatestReleaseUrl =
      "https://github.com/hiddify/hiddify-app/releases/latest";
  static const appCastUrl =
      "https://raw.githubusercontent.com/hiddify/hiddify-next/main/appcast.xml";

  // ---- License (for About screen) ----
  static const licenseUrl =
      "https://github.com/hiddify/hiddify-next?tab=License-1-ov-file#readme";

  // ---- Info blocks (home screen) ----
  // Feature module: lib/features/vpnpro_info_blocks/ (Phase 3 of ROADMAP).
  //
  // Edit [infoBlocksHardcoded] to push announcements — rebuild + redistribute
  // the app. A future phase will fetch this list from a server endpoint;
  // consumers won't need to change.

  /// Master switch. When `false`, the info-blocks section never renders.
  static const bool enableInfoBlocks = true;

  /// How many blocks to show simultaneously (highest priority first).
  /// `1` = single banner. Increase for stacked cards.
  static const int maxInfoBlocksShown = 1;

  /// Active info blocks. Add/remove entries here to change what users see.
  ///
  /// Tips:
  ///   • Use unique `id`s. Changing an id re-shows a previously-dismissed
  ///     block — handy when wording changes and you want users to see it.
  ///   • Set `expiresAt` on promos so they vanish automatically.
  ///   • Set `critical: true` for outages / maintenance (renders in
  ///     error-container color, drawing attention).
  ///   • `dismissible: false` for anything users must acknowledge.
  static final List<InfoBlock> infoBlocksHardcoded = [
    InfoBlock(
      id: "welcome-2026-04",
      priority: 100,
      title: "Добро пожаловать в VPN Pro",
      text:
          "Быстрый и приватный VPN. Если возникнут вопросы — напишите нам в поддержку.",
      ctaLabel: "Поддержка",
      ctaUrl: telegramChannelUrl,
      expiresAt: DateTime.utc(2026, 12, 31),
    ),
  ];

  // ---- Push notifications (FCM) ----
  // Feature module: lib/features/vpnpro_push/ (Phase 4 of ROADMAP).
  //
  // Broadcast flow (no backend required):
  //   1. App auto-subscribes each install to the topics below.
  //   2. Go to Firebase Console → Cloud Messaging → New campaign.
  //   3. Target: Topic → pick one of [defaultPushTopics] → Send.
  //   4. All users see the notification within ~30s.
  //
  // Silent if google-services.json (Android) / GoogleService-Info.plist (iOS)
  // is missing — initialisation fails inside `_safeInit` and the rest of the
  // app continues normally.

  /// Master switch. When `false`, FCM is never initialised.
  static const bool enablePushNotifications = true;

  /// Topics every install subscribes to on first run.
  /// Use "all-users" for unconditional broadcasts. Add more topics if you
  /// want segmentation (e.g. "promo", "critical", "beta-testers") and later
  /// let users opt out of specific ones from settings.
  static const List<String> defaultPushTopics = ["all-users"];

  /// Future: endpoint that receives `{token, platform, appVersion}` on each
  /// FCM token refresh. While `null` the app only stores tokens locally —
  /// fine for broadcasts via Firebase Console.
  ///
  /// Set this URL when you have a backend and want targeted (per-user) pushes.
  /// Client already stores the latest token in SharedPreferences, so flipping
  /// this flag is enough — no client rework needed.
  static const String? deviceTokenEndpoint = null;

  // ---- Email activation (Phase 8) ----
  // Feature module: lib/features/vpnpro_activation/ (Phase 8 of ROADMAP —
  // shipped as email-lookup variant; original key-based design deferred).
  //
  // Flow on first launch:
  //   1. User enters email on EmailActivationPage.
  //   2. App POSTs {email} to [activationEndpoint] (Supabase Edge Function
  //      `lookup-subscription` in the APPHub project).
  //   3. Edge Function fans out to configured brand Supabase projects and
  //      returns `{subscription_url, brand}` for the first match.
  //   4. App imports the subscription URL via ProfileRepository.upsertRemote,
  //      marks the new profile active, sets locale/region = ru, flips
  //      introCompleted and lands on /home.
  //
  // Escape hatch (always visible on the activation screen):
  //   - "Пропустить" → redirects to the stock Hiddify /intro flow where the
  //     user can complete onboarding and paste a subscription URL manually.
  //
  // Flipping [enableEmailActivation] back to `false` restores pristine
  // Hiddify onboarding with zero other code changes.

  /// Master switch for the email-activation first-launch screen.
  static const bool enableEmailActivation = true;

  /// Supabase Edge Function endpoint for email → subscription URL lookup.
  /// Accepts POST `{email: string, brand?: string}`; returns
  /// `{subscription_url: string, brand: string}` on 200, or 404 if the email
  /// isn't found in any configured brand DB.
  static const String activationEndpoint =
      "https://mtiagdyyujgydifquafg.supabase.co/functions/v1/lookup-subscription";

  /// Public anon JWT for the APPHub project — required by the function's
  /// JWT verification. Safe to embed in the client: the function only reads
  /// via the hub's RLS-protected `brands` table and never accepts
  /// client-driven SQL. Rotatable independently from brand service keys.
  static const String activationApiKey =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im10aWFnZHl5dWpneWRpZnF1YWZnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY1MjM5MjYsImV4cCI6MjA5MjA5OTkyNn0.3rr-xwFwgGAf1avGj0tvWlAwVPGnX6UBa5huLtulsyI";

  /// Where to send users who don't have a subscription yet. Shown as a
  /// "Нет подписки?" link on the activation screen when non-null.
  static const String? purchaseUrl = "https://vpsservice.tech/";
}
