import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hiddify/branding/branding.dart';
import 'package:hiddify/features/vpnpro_activation/model/activation_failure.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'activation_repository.g.dart';

/// Result returned by the lookup Edge Function on a successful match.
class ActivationLookupResult {
  const ActivationLookupResult({required this.subscriptionUrl, required this.brand});

  /// Remnawave subscription URL — fed directly into
  /// [ProfileRepository.upsertRemote].
  final String subscriptionUrl;

  /// Slug of the brand project where the email was found (e.g. `aura`,
  /// `brand_1`). Useful for analytics/logging; not persisted for now.
  final String brand;
}

/// Calls the APPHub `lookup-subscription` Edge Function to resolve
/// email → subscription URL.
///
/// The Edge Function fans out across all configured brand Supabase projects
/// and returns the first match. See:
///   - [Branding.activationEndpoint]
///   - [Branding.activationApiKey]
///   - supabase/functions/lookup-subscription/ in the APPHub project
abstract interface class ActivationRepository {
  TaskEither<ActivationFailure, ActivationLookupResult> lookupByEmail(String email);
}

class ActivationRepositoryImpl with InfraLogger implements ActivationRepository {
  ActivationRepositoryImpl({Dio? dio}) : _dio = dio ?? _defaultDio();

  final Dio _dio;

  static Dio _defaultDio() => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      // Edge Function requires a JWT-format Authorization header.
      // The key is a Supabase anon JWT — safe to embed; the function only
      // reads the RLS-protected `brands` table and never runs client SQL.
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer ${Branding.activationApiKey}",
        "apikey": Branding.activationApiKey,
      },
      // We interpret statuses ourselves (404 is a legitimate outcome).
      validateStatus: (_) => true,
    ),
  );

  @override
  TaskEither<ActivationFailure, ActivationLookupResult> lookupByEmail(String email) {
    final normalized = email.trim().toLowerCase();
    if (!_isValidEmail(normalized)) {
      return TaskEither.left(const ActivationFailure.invalidEmail());
    }

    return TaskEither.tryCatch(
      () async {
        loggy.debug("activation lookup for [$normalized]");
        final res = await _dio.post<Map<String, dynamic>>(Branding.activationEndpoint, data: {"email": normalized});

        final status = res.statusCode ?? 0;
        final body = res.data;

        if (status == 200 && body != null) {
          final url = body["subscription_url"];
          final brand = body["brand"];
          if (url is String && url.isNotEmpty && brand is String && brand.isNotEmpty) {
            return ActivationLookupResult(subscriptionUrl: url, brand: brand);
          }
          loggy.warning("activation: 200 but malformed body: $body");
          throw const ActivationFailure.server(200, "Некорректный ответ сервера");
        }

        if (status == 404) {
          throw const ActivationFailure.notFound();
        }

        loggy.warning("activation: HTTP $status body=$body");
        throw ActivationFailure.server(status, body?["error"]?.toString());
      },
      (error, stackTrace) {
        if (error is ActivationFailure) return error;
        if (error is DioException) {
          loggy.warning("activation network error: ${error.type} ${error.message}");
          return ActivationFailure.network(error.message);
        }
        loggy.error("activation unexpected error", error, stackTrace);
        return ActivationFailure.unexpected(error, stackTrace);
      },
    );
  }

  // Lightweight RFC-5322-ish check. We intentionally avoid a strict regex —
  // the server is the authority on whether an email maps to a subscription.
  // We only reject obvious garbage (empty, no @, no dot in domain) so the
  // user sees a nicer inline error instead of a server round-trip.
  static final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static bool _isValidEmail(String email) {
    if (email.isEmpty || email.length > 254) return false;
    return _emailRegex.hasMatch(email);
  }
}

@Riverpod(keepAlive: true)
ActivationRepository activationRepository(Ref ref) {
  return ActivationRepositoryImpl();
}
