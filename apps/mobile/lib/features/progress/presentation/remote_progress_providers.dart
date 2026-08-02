import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/token_store.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../../core/contracts/generated/generated.dart';
import '../../account/presentation/account_retry_policy.dart';
import '../../auth/domain/auth_session_state.dart';
import '../data/http_reading_progress_repository.dart';
import '../data/reading_progress_hydration.dart';
import '../domain/remote_reading_progress_exceptions.dart';
import 'reading_progress_providers.dart';
import '../data/reading_progress_sync.dart';
import '../domain/remote_reading_progress_repository.dart';

/// Ortak `/api/progress` sözleşmesine konuşan GERÇEK adapter.
final remoteReadingProgressRepositoryProvider =
    Provider<RemoteReadingProgressRepository>((ref) {
      return HttpReadingProgressRepository(
        client: ref.watch(apiClientProvider),
        tokenStore: ref.watch(tokenStoreProvider),
        authRepository: ref.watch(authRepositoryProvider),
      );
    });

/// Okuyucunun kullandığı, istek sınırlayan senkron koordinatörü.
///
/// `autoDispose` DEĞİLDİR: okuyucu kapanırken bekleyen yazımın
/// gönderilmesi `ReadingProgressSync.flush()` ile AÇIKÇA yapılır (bkz.
/// `reader_screen.dart`), provider'ın imhasına bırakılmaz.
final readingProgressSyncProvider = Provider<ReadingProgressSync>((ref) {
  final sync = ReadingProgressSync(
    remote: ref.watch(remoteReadingProgressRepositoryProvider),
  );
  ref.onDispose(sync.dispose);
  return sync;
});

/// Sunucudaki ilerlemeyi yerel cache'e aynalayan katman.
final readingProgressHydrationProvider = Provider<ReadingProgressHydration>((
  ref,
) {
  return ReadingProgressHydration(
    remote: ref.watch(remoteReadingProgressRepositoryProvider),
    local: ref.watch(readingProgressRepositoryProvider),
  );
});

/// Oturum acildiginda ve authenticated uygulama acilisinda `GET
/// /api/progress`i BIR KEZ calistirir (bkz. ADR-049).
///
/// ANONIM iken HIC istek yapilmaz: provider oturum durumunu izler ve
/// anonimde erken doner. Boylece anonim acilista `/api/progress`
/// cagrilmaz.
///
/// `retry`: kalici hatalarda Riverpod'un tekrarli istek dongusu
/// olusmamasi icin sunucunun yapilandirilmis hatasi yeniden DENENMEZ
/// (bkz. `accountProviderRetry` ile ayni ilke). Gecici ag hatalarinda
/// varsayilan backoff korunur.
///
/// Hata durumunda sahte basari URETILMEZ ve mevcut yerel veri SILINMEZ;
/// cagiran gercek hatayi ve tekrar-dene aksiyonunu gosterir.
final readingProgressHydrationResultProvider =
    FutureProvider<ReadingProgressResponse?>((ref) async {
      final session = ref.watch(authSessionProvider);
      if (session is! AuthAuthenticated) return null;
      final response = await ref
          .watch(readingProgressHydrationProvider)
          .hydrate();
      // Yerel depo GUNCELLENDI; senkron okuyan provider'lar bayat kalmasin
      // diye acikca gecersiz kilinir (ayni desen: `reader_screen.dart`).
      ref.invalidate(mostRecentReadingProgressProvider);
      ref.invalidate(readingProgressForSeriesProvider);
      return response;
    }, retry: _hydrationRetry);

Duration? _hydrationRetry(int retryCount, Object error) {
  if (error is ReadingProgressServerException) return null;
  if (error is ReadingProgressNotAuthenticatedException) return null;
  return accountProviderRetry(retryCount, error);
}
