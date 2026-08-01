import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/contracts/generated/generated.dart';
import '../../../core/storage/token_store.dart';
import '../../auth/domain/auth_repository.dart';
import '../domain/library_exceptions.dart';
import '../domain/library_repository.dart';

/// [LibraryRepository]'nin ortak `/api/library*` sözleşmesine konuşan
/// GERÇEK implementasyonu (bkz. ADR-048, OpenAPI 1.5.0).
///
/// Kimlik taşıma: her istek [TokenStore]'daki access token'ı
/// `Authorization: Bearer` olarak gönderir. OpenAPI hem Bearer hem web
/// cookie şemasını tanımlar; mobil istemci **yalnız Bearer** kullanır —
/// web'in cookie oturumu veya form gönderim mantığı KOPYALANMAZ.
///
/// Saklı oturum yoksa [LibraryNotAuthenticatedException] fırlatır ve
/// sunucuya HİÇ istek gönderilmez (ADR-010: anonim kullanıcı için sahte
/// başarı üretilmez).
///
/// Süresi dolmuş access token: hesap adapter'ıyla aynı davranış — sunucu
/// `not_authenticated` dediğinde BİR KEZ `refresh()` edilip istek
/// tekrarlanır. Yenileme başarısızsa ORİJİNAL sunucu hatası yüzeye çıkar.
class HttpLibraryRepository implements LibraryRepository {
  HttpLibraryRepository({
    required this._client,
    required this._tokenStore,
    required this._authRepository,
  });

  final PanelyaApiClient _client;
  final TokenStore _tokenStore;
  final AuthRepository _authRepository;

  Future<String> _accessToken() async {
    final stored = await _tokenStore.read();
    if (stored == null) throw const LibraryNotAuthenticatedException();
    return stored.accessToken;
  }

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on LibraryApiException catch (cause) {
      if (cause.error.error == 'not_authenticated') {
        try {
          await _authRepository.refresh();
        } catch (_) {
          throw LibraryServerException(cause.error);
        }
        try {
          return await body();
        } on LibraryApiException catch (retryCause) {
          throw LibraryServerException(retryCause.error);
        }
      }
      throw LibraryServerException(cause.error);
    } on LibraryRepositoryException {
      rethrow;
    } on ApiException catch (cause) {
      throw LibraryUnexpectedException(cause.message);
    }
  }

  @override
  Future<LibraryResponse> fetchLibrary() => _guard(() async {
    // Sunucunun sırası KORUNUR: burada hiçbir sort/reorder yapılmaz.
    return _client.fetchLibrary(accessToken: await _accessToken());
  });

  @override
  Future<LibraryMutationResponse> upsertEntry({
    required String slug,
    required LibraryStatus status,
    required bool favorite,
  }) => _guard(() async {
    return _client.upsertLibraryEntry(
      accessToken: await _accessToken(),
      slug: slug,
      // Hedef durumun TAMAMI — toggle değil.
      request: LibraryUpsertRequest(status: status, favorite: favorite),
    );
  });

  @override
  Future<LibraryRemovalResponse> removeEntry(String slug) => _guard(() async {
    // `removed: false` başarılı bir idempotent sonuçtur; burada hataya
    // ÇEVRİLMEZ.
    return _client.removeLibraryEntry(
      accessToken: await _accessToken(),
      slug: slug,
    );
  });
}
