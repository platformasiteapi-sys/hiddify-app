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
}
