import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/contracts/generated/generated.dart';
import '../../../core/storage/token_store.dart';
import '../../account/presentation/account_retry_policy.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/http_library_repository.dart';
import '../domain/library_exceptions.dart';
import '../domain/library_repository.dart';

/// Aktif [LibraryRepository]: ortak `/api/library*` sözleşmesine konuşan
/// GERÇEK [HttpLibraryRepository]'yi bağlar (bkz. ADR-048, OpenAPI 1.5.0).
final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return HttpLibraryRepository(
    client: ref.watch(apiClientProvider),
    tokenStore: ref.watch(tokenStoreProvider),
    authRepository: ref.watch(authRepositoryProvider),
  );
});

/// Kütüphane listesi (`GET /api/library`).
///
/// Sunucunun SIRASI korunur — burada da, ekranda da yeniden sıralama
/// yapılmaz (bkz. [LibraryRepository]).
///
/// `retry`: hesap providerlarıyla aynı politika — sunucu yapılandırılmış
/// bir hata döndüyse sonuç deterministiktir, boşuna tekrar denenmez ve
/// kullanıcı hatayı hemen görür (bkz. `accountProviderRetry`).
final libraryProvider = FutureProvider<LibraryResponse>((ref) {
  return ref.watch(libraryRepositoryProvider).fetchLibrary();
}, retry: _libraryRetry);

Duration? _libraryRetry(int retryCount, Object error) {
  if (error is LibraryServerException) return null;
  if (error is LibraryNotAuthenticatedException) return null;
  return accountProviderRetry(retryCount, error);
}
