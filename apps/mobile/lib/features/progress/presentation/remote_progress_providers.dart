import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/token_store.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/http_reading_progress_repository.dart';
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
