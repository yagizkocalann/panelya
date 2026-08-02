import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/contracts/generated/generated.dart';
import '../../../core/storage/token_store.dart';
import '../../auth/domain/auth_repository.dart';
import '../domain/remote_reading_progress_exceptions.dart';
import '../domain/remote_reading_progress_repository.dart';

/// [RemoteReadingProgressRepository]'nin ortak `/api/progress` sözleşmesine
/// konuşan GERÇEK implementasyonu (bkz. OpenAPI 1.6.0).
///
/// Kimlik YALNIZ `Authorization: Bearer` ile taşınır; web cookie veya
/// `localStorage` mantığı KOPYALANMAZ.
///
/// Saklı oturum yoksa [ReadingProgressNotAuthenticatedException] fırlatır
/// ve sunucuya HİÇ istek gönderilmez — anonim mobil kullanıcı
/// `/api/progress` çağırmaz.
///
/// Süresi dolmuş access token: hesap/kütüphane adapter'larıyla AYNI
/// tek-yenileme davranışı yeniden kullanılır.
class HttpReadingProgressRepository implements RemoteReadingProgressRepository {
  HttpReadingProgressRepository({
    required this._client,
    required this._tokenStore,
    required this._authRepository,
  });

  final PanelyaApiClient _client;
  final TokenStore _tokenStore;
  final AuthRepository _authRepository;

  Future<String> _accessToken() async {
    final stored = await _tokenStore.read();
    if (stored == null) {
      throw const ReadingProgressNotAuthenticatedException();
    }
    return stored.accessToken;
  }

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on ReadingProgressApiException catch (cause) {
      if (cause.error.error == 'not_authenticated') {
        try {
          await _authRepository.refresh();
        } catch (_) {
          throw ReadingProgressServerException(cause.error);
        }
        try {
          return await body();
        } on ReadingProgressApiException catch (retryCause) {
          throw ReadingProgressServerException(retryCause.error);
        }
      }
      throw ReadingProgressServerException(cause.error);
    } on RemoteReadingProgressException {
      rethrow;
    } on ApiException catch (cause) {
      throw ReadingProgressUnexpectedException(cause.message);
    }
  }

  @override
  Future<ReadingProgressResponse> fetchProgress() => _guard(() async {
    // Sunucu sırası KORUNUR: burada sort/reorder yok.
    return _client.fetchReadingProgress(accessToken: await _accessToken());
  });

  @override
  Future<ReadingProgressMutationResponse> upsertProgress({
    required String seriesSlug,
    required String episodeSlug,
    required int percent,
  }) => _guard(() async {
    return _client.upsertReadingProgress(
      accessToken: await _accessToken(),
      // Hedef durumun TAMAMI — delta değil.
      request: ReadingProgressUpsertRequest(
        seriesSlug: seriesSlug,
        episodeSlug: episodeSlug,
        percent: percent,
      ),
    );
  });
}
