import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/failures.dart';

part 'activation_failure.freezed.dart';

/// Errors surfaced by the email-activation flow (Phase 5).
///
/// Kept brand-local (lib/features/vpnpro_activation/) so upstream Hiddify
/// merges never touch it.
///
/// Presentation is best-effort — strings are hardcoded Russian, not routed
/// through arb. The activation screen is RU-only by product decision.
@freezed
sealed class ActivationFailure with _$ActivationFailure, Failure {
  const ActivationFailure._();

  /// Email field failed client-side validation.
  @With<ExpectedFailure>()
  const factory ActivationFailure.invalidEmail([String? message]) = ActivationInvalidEmailFailure;

  /// Edge Function returned 404 `not_found` — email has no active
  /// subscription in any configured brand project.
  @With<ExpectedFailure>()
  const factory ActivationFailure.notFound() = ActivationNotFoundFailure;

  /// Network error reaching the Edge Function (timeout, no internet,
  /// DNS failure, TLS error, etc).
  @With<ExpectedFailure>()
  const factory ActivationFailure.network([String? message]) = ActivationNetworkFailure;

  /// Edge Function returned a non-success status we don't know how to
  /// handle, or the response body was malformed.
  @With<ExpectedFailure>()
  const factory ActivationFailure.server([int? statusCode, String? message]) = ActivationServerFailure;

  /// Profile import (ProfileRepository.upsertRemote) failed after a
  /// successful lookup. Usually means the subscription URL on record is
  /// broken / returns an invalid config.
  @With<ExpectedFailure>()
  const factory ActivationFailure.importFailed([String? message]) = ActivationImportFailure;

  /// Catch-all for anything else (DB errors, unexpected exceptions).
  @With<UnexpectedFailure>()
  const factory ActivationFailure.unexpected([Object? error, StackTrace? stackTrace]) = ActivationUnexpectedFailure;

  @override
  ({String type, String? message}) present(TranslationsEn t) {
    return switch (this) {
      ActivationInvalidEmailFailure(:final message) => (type: "Некорректный email", message: message),
      ActivationNotFoundFailure() => (
        type: "Подписка не найдена",
        message: "Мы не нашли подписку для этого email. Проверьте адрес или обратитесь в поддержку.",
      ),
      ActivationNetworkFailure(:final message) => (
        type: "Нет соединения",
        message: message ?? "Не удалось связаться с сервером. Проверьте интернет и попробуйте снова.",
      ),
      ActivationServerFailure(:final statusCode, :final message) => (
        type: "Ошибка сервера",
        message: message ?? (statusCode != null ? "Код: $statusCode" : null),
      ),
      ActivationImportFailure(:final message) => (type: "Не удалось импортировать подписку", message: message),
      ActivationUnexpectedFailure() => (type: "Неизвестная ошибка", message: null),
    };
  }
}
