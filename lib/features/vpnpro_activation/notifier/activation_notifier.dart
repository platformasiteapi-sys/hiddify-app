import 'package:fpdart/fpdart.dart';
import 'package:hiddify/core/haptic/haptic_service.dart';
import 'package:hiddify/core/localization/locale_preferences.dart';
import 'package:hiddify/core/model/region.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/data/profile_repository.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/vpnpro_activation/data/activation_repository.dart';
import 'package:hiddify/features/vpnpro_activation/model/activation_failure.dart';
import 'package:hiddify/gen/translations.g.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'activation_notifier.g.dart';

/// Orchestrates the full email-activation chain (Phase 5).
///
/// State machine:
///   AsyncData(null)     → idle (initial / after reset)
///   AsyncLoading        → in flight
///   AsyncData(Unit)     → success; router will redirect to /home because
///                         introCompleted was flipped to true
///   AsyncError(failure) → UI shows error, user can retry or tap "Пропустить"
///
/// Steps on [activate]:
///   1. Call [ActivationRepository.lookupByEmail] → {subscription_url, brand}
///   2. Import via [ProfileRepository.upsertRemote] (downloads + validates config)
///   3. Find the new profile by URL → [ProfileRepository.setAsActive]
///   4. Pin locale=ru, region=ru (product decision: RU-only audience for Phase 5)
///   5. Flip [Preferences.introCompleted] = true → router leaves /email-activate
///
/// Any failure in steps 1-3 throws an [ActivationFailure] and the state
/// becomes AsyncError. Steps 4-5 are best-effort: if they fail we still
/// succeed because the subscription was imported — user can always change
/// locale later from Settings. If introCompleted flip fails (which would
/// be a SharedPreferences write failure — extremely rare) we surface it as
/// unexpected so the user can retry.
@riverpod
class ActivationNotifier extends _$ActivationNotifier with AppLogger {
  @override
  AsyncValue<Unit?> build() {
    return const AsyncData(null);
  }

  ProfileRepository get _profilesRepo => ref.read(profileRepositoryProvider).requireValue;
  ActivationRepository get _activationRepo => ref.read(activationRepositoryProvider);

  Future<void> activate(String email) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    await ref.read(hapticServiceProvider.notifier).lightImpact();

    state = await AsyncValue.guard(() async {
      // 1. Look up subscription URL via Supabase Edge Function.
      final lookup = await _activationRepo.lookupByEmail(email).run();
      final result = lookup.getOrElse((err) => throw err);
      loggy.info("activation: lookup ok brand=${result.brand}");

      // 2. Import the profile (downloads, parses, validates).
      final imported = await _profilesRepo.upsertRemote(result.subscriptionUrl).match((err) {
        loggy.warning("activation: import failed", err);
        throw ActivationFailure.importFailed(err.toString());
      }, (_) => unit).run();
      // ignore: unused_local_variable
      final _ = imported;

      // 3. Look up the freshly-imported profile and mark it active.
      // upsertRemote doesn't return an ID; we find it by URL (data-source
      // uses LIKE '%url%', so an exact URL is a safe unique match here).
      final dataSource = ref.read(profileDataSourceProvider);
      final entry = await dataSource.getByUrl(result.subscriptionUrl);
      if (entry == null) {
        loggy.error("activation: imported profile not found by URL — DB race?");
        throw const ActivationFailure.importFailed("Профиль не найден после импорта");
      }
      await _profilesRepo.setAsActive(entry.id).match((err) {
        loggy.warning("activation: setAsActive failed", err);
        throw ActivationFailure.importFailed(err.toString());
      }, (_) => unit).run();

      // 4. Pin RU locale/region (best-effort — failures are not fatal).
      try {
        await ref.read(localePreferencesProvider.notifier).changeLocale(AppLocale.ru);
        await ref.read(ConfigOptions.region.notifier).update(Region.ru);
        await ref.read(ConfigOptions.directDnsAddress.notifier).reset();
      } catch (e, st) {
        loggy.warning("activation: locale/region pin failed (non-fatal)", e, st);
      }

      // 5. Leave the activation/intro flow.
      await ref.read(Preferences.introCompleted.notifier).update(true);
      loggy.info("activation: complete");

      return unit;
    });
  }

  /// User tapped "Пропустить" — skip activation and hand off to the stock
  /// Hiddify intro page. We do NOT flip introCompleted here; the stock
  /// IntroPage will do that when the user taps its "Start" button.
  void reset() {
    state = const AsyncData(null);
  }
}
