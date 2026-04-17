# Branding & Upstream Sync Guide

This fork is a rebrand of [Hiddify](https://github.com/hiddify/hiddify-app).
This document describes how the fork is organized and how to pull in
upstream updates **without** merge-conflict hell.

---

## Git layout

| Branch | Purpose | Who updates it |
|---|---|---|
| `main` | Pristine mirror of `upstream/main`. **No custom commits ever.** | Only `git merge --ff-only upstream/main` |
| `brand/vpnpro` | Our branded branch. All customizations live here. Releases built from here. | Us |

Remotes:
- `origin` → our fork on GitHub
- `upstream` → `https://github.com/hiddify/hiddify-app`

---

## Where brand-specific stuff lives

### 1. `lib/branding/branding.dart` — **single source of truth**
All brand strings, URLs, colors, and future flags go here. Never inline
brand values in other Dart files; always reference `Branding.*`.

`lib/core/model/constants.dart` has been refactored to **reference**
`Branding` rather than hard-code values. When upstream changes
`Constants`, the conflict is confined to this one file.

### 2. Platform-specific display strings
These had to be changed in native config files (upstream owns them, so
conflicts on upstream change are possible):

| Platform | File | Field |
|---|---|---|
| Android | `android/app/src/main/AndroidManifest.xml` | `android:label` |
| iOS | `ios/Runner/Info.plist` | `CFBundleDisplayName` |
| macOS | `macos/Runner/Configs/AppInfo.xcconfig` | `PRODUCT_NAME` |
| Windows | `windows/runner/main.cpp` | Window title + mutex name |
| Windows | `windows/runner/Runner.rc` | VersionInfo strings |
| Linux | `linux/my_application.cc` | `gtk_*_set_title` calls |

### 3. `.gitattributes`, `.gitignore` (our additions)
- `.gitattributes` normalizes line endings so Windows doesn't create
  spurious diffs on Flutter-generated files.
- `.gitignore` excludes `.claude/`.

Both live only on `brand/vpnpro` — upstream never sees them, so they
**cannot** cause merge conflicts.

---

## Rules to minimize future conflicts

1. **New brand-specific values → `lib/branding/branding.dart`.** Never
   inline strings elsewhere.
2. **New features you invent → new folder `lib/features/vpnpro_*/`.**
   Upstream cannot touch files it doesn't know about.
3. **Assets: overwrite, don't rename.** If you replace the logo, keep
   the filename `assets/images/logo.svg`. Renaming forces you to change
   every reference and every upstream change to that file will conflict.
4. **Do not rename the Dart package** (`name: hiddify` in `pubspec.yaml`).
   That would change every `package:hiddify/...` import — and every
   upstream commit touching imports would conflict.
5. **One hook per integration point.** If you need your code to run in
   an upstream flow, make a single small edit at the call site that
   invokes a function defined in `lib/features/vpnpro_*/`. Don't scatter
   edits.

---

## Syncing with upstream (the routine)

Do this **per upstream release tag**, not per commit. Tags only.

```bash
# 1. Update the pristine mirror
git fetch upstream --tags
git checkout main
git merge --ff-only upstream/main    # must be fast-forward; if it fails,
                                     # someone committed to main by mistake

# 2. Merge into the brand branch
git checkout brand/vpnpro
git merge main

# 3. Resolve conflicts (expected hotspots):
#    - lib/core/model/constants.dart  (if upstream added new constants)
#    - platform config files (if upstream renamed something)
#    - assets we overwrote (if upstream changed them)

# 4. Regenerate code
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart run slang

# 5. Build-test all target platforms before releasing
flutter build apk --release
# + iOS / Windows / macOS / Linux as needed

# 6. Tag and release
git tag v4.x.y-vpnpro.1
git push origin brand/vpnpro --tags
```

If a conflict seems larger than a handful of lines, **stop and think**:
it usually means a new brand touchpoint should be factored out into
`lib/branding/` so the next merge is clean.

---

## What still needs to be done before public release

### Must-do (blocks release)
- [ ] **Change `applicationId` / `bundle id`** on all platforms so the
      branded app installs alongside (not over) Hiddify. See
      `android/app/build.gradle`, `ios/Runner.xcodeproj`, `macos/Runner`,
      `windows/runner`, `linux/CMakeLists.txt`.
- [ ] **Replace `appCastUrl` and GitHub URLs** in
      `lib/branding/branding.dart` with our own update channel.
      Otherwise users will auto-update to upstream Hiddify.
- [ ] **Replace Privacy Policy and Terms URLs** — required by App Store
      and Play Market.
- [ ] **Replace icons** — `assets/images/logo.svg`, `tray_icon*`,
      launcher icons (regenerate via `flutter_launcher_icons`), splash
      (via `flutter_native_splash`).
- [ ] **Review and honor the Hiddify license** (`LICENSE.md`) —
      attribution in About screen; verify commercial use is permitted.

### Should-do
- [ ] Own Sentry DSN (or disable). See `pubspec.yaml` `sentry:` block.
- [ ] Own Firebase project if push notifications are added.
- [ ] `assets/translations/*.i18n.json` — replace "Hiddify" occurrences
      with `{Branding.appName}` where appropriate (careful: leave
      protocol names / historical references alone).
- [ ] Set up a CI workflow (see upstream `.github/workflows/`) with our
      signing secrets.

### Nice-to-have
- [ ] `lib/features/vpnpro_activation/` — key-entry screen tied to our
      subscription API.
- [ ] `lib/features/vpnpro_info_blocks/` — server-driven content cards
      on the home screen.

---

## Quick reference: branches & remotes setup

```bash
# If cloning fresh:
git clone https://github.com/platformasiteapi-sys/hiddify-app.git vpn-pro
cd vpn-pro
git remote add upstream https://github.com/hiddify/hiddify-app.git
git fetch upstream
git checkout brand/vpnpro
```
