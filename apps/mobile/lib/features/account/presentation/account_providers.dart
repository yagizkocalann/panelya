import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/account_management_feature_config.dart';
import '../../../core/contracts/generated/generated.dart';
import '../../../core/storage/token_store.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/account_reauthentication.dart';
import '../data/http_account_repository.dart';
import '../domain/account_repository.dart';

/// Aktif [AccountRepository]: ortak `/api/account/*` sözleşmesine konuşan
/// GERÇEK [HttpAccountRepository]'yi bağlar (bkz. ADR-047, OpenAPI 1.4.1).
///
/// Erişim kapısı [AccountManagementFeatureConfig]'tir (varsayılan `false`,
/// bkz. o dosya): bayrak kapalıyken hesap yönetimi ekranlarına ne
/// `AccountHomeScreen`den ne router'dan ULAŞILAMAZ, bu yüzden bu provider
/// da okunmaz. Bayrak `true` yapılmadan production'da hiçbir hesap
/// mutation'ı tetiklenemez.
///
/// `FakeAccountRepository` ARTIK burada bağlanmaz — yalnız testlerde
/// override edilerek kullanılır.
final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return HttpAccountRepository(
    client: ref.watch(apiClientProvider),
    tokenStore: ref.watch(tokenStoreProvider),
  );
});

/// Taze kimlik doğrulama orkestratörü (bkz. [AccountReauthenticator]).
/// E-posta değiştirme ve hesap silme ekranları bunu kullanır; mevcut
/// oturumu/`TokenStore`'u değiştirmez.
final accountReauthenticatorProvider = Provider<AccountReauthenticator>((ref) {
  return AccountReauthenticator(
    repository: ref.watch(accountRepositoryProvider),
    browser: ref.watch(authBrowserProvider),
  );
});

/// `GET /api/account` — kullanıcı + sağlayıcı + YETENEKLER. Ekranlar hangi
/// aksiyonu göstereceğine yalnız `capabilities` üzerinden karar verir.
final accountOverviewProvider = FutureProvider<AccountOverviewResponse>(
  (ref) => ref.watch(accountRepositoryProvider).fetchOverview(),
);

/// `GET /api/account/sessions`. Mutasyonlar sonrası çağıran bu provider'ı
/// `ref.invalidate(...)` ile geçersiz kılar (bkz.
/// `offline_providers.dart` -> `downloadedEpisodesProvider` deseni).
final accountSessionsProvider = FutureProvider<AccountSessionsResponse>(
  (ref) => ref.watch(accountRepositoryProvider).fetchSessions(),
);

/// `GET /api/account/blocks`.
final blockedAccountsProvider = FutureProvider<BlockedAccountsResponse>(
  (ref) => ref.watch(accountRepositoryProvider).fetchBlockedAccounts(),
);

/// `GET /api/account/deletion` — silme/anonimleştirme/SAKLAMA özeti.
final accountDeletionSummaryProvider =
    FutureProvider<AccountDeletionSummaryResponse>(
      (ref) => ref.watch(accountRepositoryProvider).fetchDeletionSummary(),
    );
