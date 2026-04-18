import 'package:dio/dio.dart';
import 'package:hiddify/branding/branding.dart';
import 'package:hiddify/branding/info_block.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'info_blocks_repository.g.dart';

/// Fetches home-screen info blocks from the APPHub Supabase REST endpoint.
///
/// Filtering (active, not-expired) is done server-side via RLS policy; we
/// simply GET the table and ask PostgREST to order by `priority desc`.
///
/// See also:
///   - [Branding.infoBlocksEndpoint] — URL of the PostgREST resource
///   - `public.info_blocks` table + RLS in the APPHub Supabase project
class InfoBlocksRepository with InfraLogger {
  InfoBlocksRepository({Dio? dio}) : _dio = dio ?? _defaultDio();

  final Dio _dio;

  static Dio _defaultDio() => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      sendTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 10),
      // Supabase PostgREST requires both `apikey` header and
      // `Authorization: Bearer <jwt>`. Anon JWT — safe to embed.
      headers: {
        "Accept": "application/json",
        "Authorization": "Bearer ${Branding.infoBlocksApiKey}",
        "apikey": Branding.infoBlocksApiKey,
      },
      validateStatus: (_) => true,
    ),
  );

  /// Fetches and parses the current visible blocks.
  ///
  /// Throws on network / server errors — caller decides whether to fall
  /// back to cache or hardcoded. We deliberately don't swallow errors
  /// here so the notifier can log them with proper context.
  Future<List<InfoBlock>> fetch() async {
    const endpoint = Branding.infoBlocksEndpoint;
    if (endpoint == null) {
      // Caller shouldn't even get here if endpoint is null, but belt +
      // suspenders: treat as "no remote content" without an error.
      return const [];
    }

    // `select=*` returns all columns; `order=priority.desc` delegates
    // sorting to PostgREST so we don't have to re-sort (though we still
    // do client-side to be safe if the server ordering ever changes).
    final res = await _dio.get<List<dynamic>>(
      endpoint,
      queryParameters: {"select": "*", "order": "priority.desc"},
    );

    final status = res.statusCode ?? 0;
    if (status != 200 || res.data == null) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        message: "info_blocks HTTP $status",
      );
    }

    final rows = res.data!;
    final blocks = <InfoBlock>[];
    for (final row in rows) {
      if (row is! Map<String, dynamic>) continue;
      try {
        blocks.add(_parse(row));
      } catch (e, st) {
        // One bad row shouldn't kill the entire feed. Log and skip.
        loggy.warning("skipping malformed info_block row: $row", e, st);
      }
    }
    return blocks;
  }

  /// Maps a PostgREST row (snake_case) onto the [InfoBlock] model.
  static InfoBlock _parse(Map<String, dynamic> row) {
    final id = row["id"];
    final title = row["title"];
    final body = row["body"];
    if (id is! String || title is! String || body is! String) {
      throw FormatException("missing required fields: $row");
    }

    DateTime? expiresAt;
    final rawExpires = row["expires_at"];
    if (rawExpires is String && rawExpires.isNotEmpty) {
      expiresAt = DateTime.tryParse(rawExpires);
    }

    return InfoBlock(
      id: id,
      title: title,
      text: body,
      ctaLabel: row["cta_label"] as String?,
      ctaUrl: row["cta_url"] as String?,
      dismissible: row["dismissible"] as bool? ?? true,
      priority: (row["priority"] as num?)?.toInt() ?? 0,
      expiresAt: expiresAt,
      critical: row["critical"] as bool? ?? false,
    );
  }
}

@Riverpod(keepAlive: true)
InfoBlocksRepository infoBlocksRepository(Ref ref) {
  return InfoBlocksRepository();
}
