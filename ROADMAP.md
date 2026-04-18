# VPN Pro — Roadmap & Implementation Guide

Stateful plan for turning the Hiddify fork into a standalone commercial
VPN product. Read top-to-bottom for context; work phase-by-phase.

Companion doc: [BRANDING.md](BRANDING.md) — the git/upstream-sync rules.
This file is the product/feature roadmap.

---

## Current state (as of 2026-04-18)

Branch: `brand/vpnpro`. Pushed to `origin/brand/vpnpro` on GitHub.

**Phase 1 — Foundation** ✅
- ✅ Git hygiene: `.gitattributes`, `.gitignore` for `.claude/`
- ✅ `lib/branding/branding.dart` — single source of truth for brand values
- ✅ Display name "VPN Pro" on all 5 platforms (Android, iOS, macOS, Windows, Linux)
- ✅ Bundle/application ID changed to `com.vpnpro.app`
- ✅ Launcher icons replaced (Android mipmaps + iOS AppIcon) — temporary placeholder
- ✅ Adaptive-icon XML fixed to reference mipmap PNGs (Android 8+)
- ✅ `common.appTitle` → "VPN Pro" in all 11 locales
- ✅ [BRANDING.md](BRANDING.md) with upstream-sync procedure

**Phase 3 — Info blocks** ✅ (Phase 2 and Phases 4+ still ahead)
- ✅ `lib/branding/info_block.dart` — model
- ✅ `lib/features/vpnpro_info_blocks/` — feature module (data, providers, widgets)
- ✅ One-line hook on home screen (above active-proxy footer)
- ✅ Hardcoded list in `Branding.infoBlocksHardcoded` with expiry / priority / dismiss
- ⏳ Server-driven source (Phase 3.1) — deferred until backend endpoint exists

**Still Hiddify-themed** (intentionally, pending final art and decisions):
- `assets/images/logo.svg` — used in header, About screen, intro, connection button
- `assets/images/world_map.png` — background on home screen
- `assets/images/tray_icon*.png/.ico` — system tray
- `assets/images/connect_norouz.PNG` / `disconnect_norouz.PNG` — Iranian Nowruz holiday overlay (shown 19-23 March only)
- App theme colors (seed color)
- `appCastUrl`, GitHub URLs, Privacy Policy, Terms — still in `Branding` as Hiddify URLs
- Windows `.ico`, macOS AppIcon, Linux `hiddify.png`, Android notification icon

---

## Store submission reality (pre-work)

| Level of rebrand | Google Play | App Store |
|---|---|---|
| Name + icon + bundle id only (current) | 🟡 ~70% | 🔴 ~20% |
| + info blocks from our API | 🟢 ~80% | 🟡 ~35% |
| + push notifications | 🟢 ~85% | 🟡 ~45% |
| + account button / WebView | 🟢 ~88% | 🟡 ~50% |
| + custom home screen | 🟢 ~95% | 🟡 ~65% |
| + simplified UX (advanced hidden) | 🟢 ~95% | 🟢 ~80% |
| + custom onboarding | 🟢 ~95% | 🟢 ~90% |

**Key risks** Apple enforces against VPN reskins (2024-2026):
- Guideline 4.1 — Copycats / Spam
- Guideline 5.4 — VPN Apps must be from a single compliant entity
- VPN category requires explicit service provider identification
- Reviewers actively search for parent OSS projects and compare

**Mandatory before public release, any platform:**
- [ ] Verify Hiddify license permits commercial distribution (see [LICENSE.md](LICENSE.md))
- [ ] Attribution in About screen ("Based on Hiddify, MIT/GPL/etc.")
- [ ] Own Privacy Policy URL
- [ ] Own Terms of Service URL
- [ ] Own `appCastUrl` (otherwise users auto-update to Hiddify)

---

## Architectural rules (non-negotiable)

All new work goes into `lib/features/vpnpro_*/` folders. These are
brand-only and never collide with upstream merges.

When integration with existing screens is unavoidable, make **one hook
call** (not scattered edits):

```dart
// In upstream file — single line, easy to spot in merges
VpnProHooks.onHomeScreenReady(context);
```

The logic lives in our folder. Upstream file changes by one line.

Brand config lives in [lib/branding/branding.dart](lib/branding/branding.dart).
Every new toggleable feature gets a flag there, not a magic constant
scattered through the codebase.

---

## Phase 1 — Foundation complete ✅

Done. See "Current state" above.

---

## Phase 2 — Visual identity (next, when assets ready)

Goal: make the app visually ours without changing UX layout.
Risk to upstream sync: near-zero (asset replacement only).

### Assets to replace (single-file operations)

| Asset | File | Format | Notes |
|---|---|---|---|
| Main logo | `assets/images/logo.svg` | **SVG required** | Used in 5 places; painted via ColorFilter in connection button, so must be SVG with single path or simple structure. Color comes from theme. |
| Map background | `assets/images/world_map.png` | PNG | Optional — can be removed via [home_page.dart:83](lib/features/home/widget/home_page.dart:83) if we want clean background |
| Splash foreground | `assets/images/source/ic_launcher_foreground.png` | PNG | Regenerate via `flutter_native_splash` |
| Splash full | `assets/images/source/ic_launcher_splash.png` | PNG | Same |
| Windows tray | `assets/images/tray_icon*.png/.ico` (8 files) | PNG + ICO | Connected/disconnected × light/dark |
| Windows exe icon | `windows/runner/resources/app_icon.ico` | Multi-res ICO | |
| macOS icon | `macos/Runner/Assets.xcassets/AppIcon.appiconset/` | Multiple sizes | |
| Linux icon | `hiddify.png` (root) | PNG 512×512 | Keep filename to avoid editing [my_application.cc](linux/my_application.cc) |
| Android status bar | `android/app/src/main/res/drawable*/ic_stat_logo.*` | Monochrome | White silhouette on transparent |
| Android banner (TV) | `android/app/src/main/res/mipmap-xhdpi/ic_banner.png` | PNG 320×180 | Only if targeting Android TV |

### Theme (optional in this phase)

User's current preference: keep Hiddify theme colors. If that changes,
add seed-color override to `Branding`:

```dart
// lib/branding/branding.dart
static const Color? primarySeedColor = Color(0xFFHEXHEX);
// Apply in lib/core/theme/ by reading Branding.primarySeedColor
// with fallback to the original Hiddify seed.
```

One-line integration in theme builder. Reverts if `primarySeedColor == null`.

---

## Phase 3 — Info blocks (server-driven content)

**Why:** Shows reviewers this is a live commercial service, not a static
reskin. Gives us a channel for promos, maintenance notices, news.

**Apple risk:** do NOT promote third-party VPN services through these
blocks — that's an auto-reject. Promote only our own products/tiers.

### Backend contract

`GET https://api.vpnpro.app/v1/info-blocks?lang=ru&platform=android`

Returns JSON array:

```json
[
  {
    "id": "promo-2026-04",
    "priority": 100,
    "title": "Скидка 30% на годовой тариф",
    "text": "До конца месяца — годовая подписка со скидкой.",
    "image_url": "https://cdn.vpnpro.app/promo/2026-04.png",
    "cta_label": "Подробнее",
    "cta_url": "https://vpnpro.app/promo/april",
    "dismissible": true,
    "expires_at": "2026-04-30T23:59:59Z"
  }
]
```

Empty array = nothing shown.

### Flutter implementation

```
lib/features/vpnpro_info_blocks/
├── model/
│   └── info_block.dart           # Freezed, mappable
├── data/
│   └── info_blocks_repository.dart  # Dio, cached in Drift with TTL
├── notifier/
│   └── info_blocks_notifier.dart    # Riverpod AsyncNotifier
└── widget/
    ├── info_block_card.dart
    └── info_blocks_section.dart     # shown on home screen
```

**Integration hook:** one insertion in [lib/features/home/widget/home_page.dart](lib/features/home/widget/home_page.dart)
above the map background — one `InfoBlocksSection()` widget call.

### Feature flag

```dart
// Branding
static const bool enableInfoBlocks = true;
static const String infoBlocksApiUrl = "https://api.vpnpro.app/v1/info-blocks";
```

### Caching strategy

- Fetch on app start + every 4 hours in background
- Cache in Drift (new table `info_blocks_cache`)
- Dismissed IDs stored in `SharedPreferences`; dismissed = hidden until new `expires_at`
- Offline: show last cached

### Open questions for the user

- [ ] Design style: carousel, stack of cards, single banner?
- [ ] Position: above map, below connection button, in separate tab?
- [ ] Priority vs time order?
- [ ] API ready, or start with hardcoded placeholder list?

---

## Phase 4 — Push notifications (FCM)

**Why:** Retention + ops channel (subscription expiry, new servers,
maintenance) + signals "real service" to reviewers.

### Requirements from user

- [ ] Create Firebase project at console.firebase.google.com
- [ ] Add Android app with package `com.vpnpro.app` → download `google-services.json`
- [ ] Add iOS app with bundle `com.vpnpro.app` → download `GoogleService-Info.plist`
- [ ] **Apple Developer Program subscription** ($99/year) — without it iOS push is impossible
- [ ] APNs Auth Key in Apple Developer → upload to Firebase Cloud Messaging

### Dependencies

```yaml
# pubspec.yaml additions
firebase_core: ^3.x
firebase_messaging: ^15.x
flutter_local_notifications: ^18.x   # foreground display
```

### Android setup

- `android/app/google-services.json` (gitignored, user provides)
- `android/app/build.gradle`: apply `com.google.gms.google-services` plugin
- `android/build.gradle`: classpath for Google Services
- `POST_NOTIFICATIONS` permission is already in [AndroidManifest.xml:17](android/app/src/main/AndroidManifest.xml:17)

### iOS setup

- `ios/Runner/GoogleService-Info.plist` (gitignored)
- Enable Push Notifications + Background Modes (Remote notifications) in Xcode capabilities
- `ios/Runner/AppDelegate.swift` — Firebase configure + UNUserNotificationCenter delegate

### Flutter code

```
lib/features/vpnpro_push/
├── push_service.dart              # init, permission request, token handling
├── push_notifier.dart             # Riverpod
├── push_topics.dart               # subscribe: news, promo, critical
└── notification_handler.dart      # foreground/background/onTap
```

### Token sync

On first run + each token refresh:
`POST https://api.vpnpro.app/v1/device-tokens` with `{token, platform, app_version}`.
Our server stores; uses for targeted sends.

### Feature flag

```dart
static const bool enablePushNotifications = true;
static const String deviceTokenEndpoint = "https://api.vpnpro.app/v1/device-tokens";
static const List<String> defaultSubscribedTopics = ["news", "critical"];
```

### Use-cases to support from day 1

- Subscription expiry reminders (-7d, -3d, -1d)
- Payment receipts / renewal confirmations
- Critical service alerts (maintenance, IP changes)
- Promotional campaigns (opt-out via topic unsubscribe)

### What user needs to build server-side (not in this app)

- FCM Admin SDK integration (Node/Python/whatever)
- Cron jobs for expiry reminders
- Admin panel to send broadcasts

---

## Phase 5 — Account button / personal area

**Why:** Required for commercial VPN feel. Apple especially dislikes
apps that send users to "mystery websites" for payment/account.

### Three variants (pick one)

**A. External link (simplest, ~10 min)**
- Pro: tiny code change
- Con: kicks user to browser, breaks UX

**B. In-app WebView (recommended, ~1 hour)**
- Pro: stays in app, Apple-friendly
- Con: requires `webview_flutter` dep, SSO handling
- Best for: existing web dashboard we don't want to rebuild

**C. Native screen calling our API (ideal, ~1 day)**
- Pro: fully native, fast, looks "ours"
- Con: requires API endpoints for account data

### Variant B (WebView) — implementation

```yaml
# pubspec.yaml
webview_flutter: ^4.x
```

```
lib/features/vpnpro_account/
├── widget/
│   └── account_webview_screen.dart
└── account_route.dart               # go_router entry: /account
```

Added to drawer/settings menu as top item.

### SSO flow

1. User taps "Личный кабинет"
2. App opens WebView with `https://vpnpro.app/app/login?token=<stored-auth-token>`
3. Our server validates token, drops session cookie
4. Dashboard loads

Token comes from login step during Phase 7 (activation). Until then,
WebView opens generic `/login` page.

### Variant C (native) — later, if we want

API endpoints needed:
- `GET /v1/account/me` — email, tier, expiry
- `GET /v1/account/subscription` — current plan details
- `GET /v1/account/devices` — connected devices
- `POST /v1/account/logout`

---

## Phase 6 — Simplification (hide advanced features)

**Why:** Hiddify exposes protocol selection, route rules, per-app proxy,
DNS config, CLI tuning — overwhelming for non-technical users and a
reviewer tells on sight this is a power-user tool.

Paid mass-market VPN users expect a "one button" experience.

### Targets for hiding

Controlled by `Branding.enableAdvancedMode` flag (default `false`):

- `/route-rules` screen — hide route from go_router
- `/per-app-proxy` — same
- Advanced settings in `/settings` (hide sections, not individual lines)
- Profile list — show only active one, hide "add/edit/delete" UI
- Log viewer — hide from UI (keep for `flutter run --debug`)
- Quick settings panel (top-right gear on home) — remove or gut

### Implementation pattern

```dart
// In go_router config (one file):
if (Branding.enableAdvancedMode) ...[
  GoRoute(path: '/route-rules', ...),
  GoRoute(path: '/per-app-proxy', ...),
],

// In settings_page.dart:
if (Branding.enableAdvancedMode) AdvancedSection(),
```

Files are **not deleted** — they stay for possible toggling back and to
avoid upstream-merge conflicts.

---

## Phase 7 — Custom home screen (Level 3 rebrand)

**Why:** Biggest visual signal to reviewers that this isn't a reskin.
Also dramatically improves UX for paying customers.

### What to build

New home screen with:
- Branded hero illustration (replaces map background)
- Connection button in own layout (position, shape, animation up to design)
- Subscription status card: email / tier / days remaining / traffic used
- Server picker simplified (maybe flag + city, not protocol list)
- Promo/info block inline (from Phase 3)
- Support shortcut (Telegram / email)

### Implementation

```
lib/features/vpnpro_home/
├── vpnpro_home_page.dart          # new screen
├── widget/
│   ├── vpnpro_connect_button.dart
│   ├── subscription_card.dart
│   ├── server_picker_chip.dart
│   └── support_row.dart
```

### Integration

One change in router: if `Branding.useCustomHomeScreen == true`, route
`/` maps to `VpnProHomePage`. Otherwise — Hiddify's `HomePage`.

Original [home_page.dart](lib/features/home/widget/home_page.dart) is
untouched. All logic (connection state, profile, proxy switching) is
reused via existing Riverpod providers.

### Reused existing state (DO NOT duplicate)

- `connectionNotifierProvider` — connect/disconnect
- `activeProfileProvider` — current subscription/profile
- `selectedProxyProvider` — server selection
- `statsNotifierProvider` — traffic stats

---

## Phase 8 — Activation flow

**Why:** Users buy a key on our site → need to activate in app → app
should pull subscription. Current Hiddify flow ("paste subscription URL")
is geek-level.

### Flow design

1. First launch → onboarding (3 screens, Phase 9)
2. Final onboarding screen: "Enter activation key" input
3. User types key (short code, e.g. `VPN-XXXX-XXXX`)
4. App → `POST api.vpnpro.app/v1/activate {key}` → returns `{subscription_url, user_token}`
5. App imports `subscription_url` via existing `ProfileRepository.add(...)`
6. Stores `user_token` securely (for WebView SSO, push token registration, account API)
7. User lands on home screen, already configured

### Alternative entry: deep link

Email after purchase contains `vpnpro://activate?key=VPN-XXXX-XXXX`.
Tapping on phone → opens app → auto-activates.

### Implementation

```
lib/features/vpnpro_activation/
├── data/activation_repository.dart
├── notifier/activation_notifier.dart
└── widget/
    ├── activation_screen.dart
    └── deep_link_handler.dart
```

Add scheme `vpnpro` to:
- Android: [AndroidManifest.xml:77-83](android/app/src/main/AndroidManifest.xml) — add `<data android:scheme="vpnpro" />`
- iOS: [Info.plist:32](ios/Runner/Info.plist) — add `vpnpro` to URL schemes array

### Existing schemes are kept

`hiddify://`, `v2ray://`, `clash://`, etc. stay — lets power users still
import subscriptions from other sources. We just add ours.

---

## Phase 9 — Custom onboarding

**Why:** First impression. Apple reviewers heavily weight the first 30
seconds of the app.

### Design target

3-4 screens:
1. **Welcome** — brand hero, "Fast & private VPN"
2. **How it works** — animated illustration: encrypted tunnel
3. **Privacy promise** — no-logs policy, jurisdiction, audit
4. **Activation** (merges with Phase 8) — enter key or "I'll do it later"

### Implementation

```
lib/features/vpnpro_onboarding/
├── onboarding_page.dart           # PageView of 4 screens
├── widget/
│   ├── onboarding_page_1_welcome.dart
│   ├── onboarding_page_2_how.dart
│   ├── onboarding_page_3_privacy.dart
│   └── onboarding_page_4_activate.dart
```

Hiddify's existing `lib/features/intro/` can be kept as fallback
(`Branding.useCustomOnboarding = true` to switch). Or disabled entirely.

Shown once per install (flag in `SharedPreferences`).

---

## Phase 10 — Release infrastructure

### CI/CD

- Fork `.github/workflows/` from upstream
- Replace signing secrets with ours (Android keystore, Apple certificates)
- Build matrix: android-apk, android-aab, ios, macos, windows, linux

### Code signing

- **Android**: generate own `upload-keystore.jks`, put config in `android/key.properties` (gitignored)
- **iOS**: Apple Developer account, App Store Connect app record, provisioning profiles
- **macOS**: Developer ID Application cert + notarization
- **Windows**: code-signing cert (optional but avoids SmartScreen warning); MSIX for Store
- **Linux**: sign .deb with GPG if distributing ourselves

### Auto-update

- Desktop (Sparkle via `upgrader`): own `appcast.xml` on our CDN
- Android: Play Store handles if published there
- iOS: App Store handles
- Side-loaded Android (APK from our site): in-app version check against our API

### Stores checklist

**Google Play Console:**
- [ ] Data safety form (what's collected, how, why, sharing)
- [ ] Content rating (usually IARC "Everyone" for VPN)
- [ ] Privacy Policy URL
- [ ] Closed testing → open testing → production

**App Store Connect:**
- [ ] Network Extensions entitlement request
- [ ] Export compliance (ITSAppUsesNonExemptEncryption is already `false` in [Info.plist:56](ios/Runner/Info.plist))
- [ ] App Privacy details
- [ ] TestFlight → App Store review

---

## Deferred / nice-to-have

- In-app purchase (IAP) for iOS — if we ever want to sell directly (Apple's 30% cut applies)
- Apple Watch companion app
- Android TV layout polish
- Widget for home screen (quick connect)
- Siri shortcuts / Quick Actions
- Split tunneling UI (exists in upstream as `per_app_proxy`, but hidden in Phase 6)

---

## How to use this document

- When starting a phase: read its section, confirm with user the
  open questions / required inputs, then implement.
- When a phase is done: check it off in "Current state" at the top.
- When upstream syncing: no action here — see [BRANDING.md](BRANDING.md).
- When scope changes: update relevant phase or add a new one. Don't
  edit phases already done.
