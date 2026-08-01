import '../../../core/contracts/generated/generated.dart';

/// "Hesabım" sınırının tek soyut sözleşmesi (bkz. ADR-047,
/// docs/production-account-lifecycle.md).
///
/// Tüm model tipleri artık `packages/contracts/schema.json`'dan ÜRETİLEN
/// DTO'lardır (bkz. `core/contracts/generated/account_*.dart`) — bu
/// modülde elle yazılmış provisional model KALMADI.
///
/// TAZE KİMLİK DOĞRULAMASI (reauthentication): e-posta değiştirme ve hesap
/// silme, sunucudan alınan AMACA BAĞLI, kısa ömürlü, TEK KULLANIMLIK bir
/// `reauthenticationToken` ister. Authorization code bu mutation'lara
/// ASLA doğrudan verilmez. Akış:
///   1. [startReauthentication] — PKCE `codeChallenge` ile başlar,
///      `authorizationUrl` + `requestId` döner.
///   2. Çağıran (bkz. `account_reauthentication.dart`) sistem tarayıcısında
///      bu URL'i açar ve callback'i yakalar.
///   3. [completeReauthentication] — `requestId` + `authorizationCode` +
///      `state` + `codeVerifier` ile tamamlar, `reauthenticationToken`
///      döner.
///   4. Token yalnız [requestEmailChange] / [deleteAccount] çağrısında
///      kullanılır.
/// Bu akış mevcut `AuthRepository` oturumunu ve `TokenStore`'u
/// DEĞİŞTİRMEZ (bkz. `AccountReauthenticator`).
abstract class AccountRepository {
  /// `GET /api/account` — kullanıcı, sağlayıcı ve YETENEK (capability)
  /// bilgisini birlikte döner. Ekranlar hangi aksiyonun gösterileceğine
  /// yalnız [AccountCapabilities] üzerinden karar verir (sağlayıcı türüne
  /// göre elle dallanma YAPILMAZ).
  Future<AccountOverviewResponse> fetchOverview();

  /// `PATCH /api/account/profile` — görünen adı günceller. Sözleşme gereği
  /// TAZELENMİŞ ÖZETİ döner (`AccountActionAcceptedResponse` değil), bu
  /// yüzden çağıran ayrıca yeniden okuma yapmaz.
  Future<AccountOverviewResponse> updateProfile({required String displayName});

  /// `POST /api/account/password-reset` — şifre sıfırlama e-postası
  /// gönderir. Gövdesi alansızdır ([AccountPasswordResetRequest]).
  /// Uygulama içinde eski/yeni şifre alanı HİÇBİR ZAMAN oluşturulmaz.
  Future<AccountActionAcceptedResponse> requestPasswordReset();

  /// `POST /api/account/email-change` — yeni e-posta + taze kimlik
  /// doğrulama tokeni ister (bkz. sınıf dokümantasyonu).
  Future<AccountActionAcceptedResponse> requestEmailChange({
    required String newEmail,
    required String reauthenticationToken,
  });

  /// `GET /api/account/sessions` — aktif oturumlar. Her oturum `current`
  /// (bu cihaz mı) ve `revocable` (kapatılabilir mi) bayraklarını taşır.
  Future<AccountSessionsResponse> fetchSessions();

  /// `DELETE /api/account/sessions/{sessionId}` — tek bir oturumu kapatır.
  /// Dönen [AccountSessionRevocationResponse.currentSessionRevoked],
  /// çağıranın yerel oturumu da temizlemesi gerekip gerekmediğini
  /// SUNUCUDAN bildirir — istemci bunu tahmin etmez.
  Future<AccountSessionRevocationResponse> revokeSession(String sessionId);

  /// `POST /api/account/sessions/revoke` — toplu kapatma.
  ///
  /// SINIR (web tarafının bildirdiği, mobil için geçerli): native refresh
  /// credential kimliği access token'dan kesin eşlenemediği için
  /// `scope: others` şu an sunucuda **503 fail-closed** döner. Bu durum
  /// TAKLİT EDİLİP başarılı gösterilmez; çağıran hatayı dürüstçe yüzeye
  /// çıkarır (bkz. `sessions_screen.dart`). current-device gateway
  /// eşlemesi ayrı bir teslim.
  Future<AccountSessionRevocationResponse> revokeSessions({
    required String scope,
  });

  /// `GET /api/account/blocks` — engellenen hesaplar.
  Future<BlockedAccountsResponse> fetchBlockedAccounts();

  /// `DELETE /api/account/blocks/{userId}` — engeli kaldırır.
  Future<AccountActionAcceptedResponse> unblockAccount(String userId);

  /// `GET /api/account/deletion` — silme özeti: neyin silineceği,
  /// neyin anonimleştirileceği ve neyin (yasal olarak) SAKLANACAĞI.
  Future<AccountDeletionSummaryResponse> fetchDeletionSummary();

  /// `POST /api/account/deletion` — hesabı siler.
  ///
  /// Sözleşme gereği zorunlu bir `Idempotency-Key` HEADER'ı gönderilir
  /// (adapter üretir); aynı anahtarla tekrar çağrı yeni bir iş
  /// OLUŞTURMAZ. Dönen [AccountDeletionOperationResponse.status]
  /// `pending` olabilir — silme asenkron tamamlanabilir.
  Future<AccountDeletionOperationResponse> deleteAccount({
    required String reauthenticationToken,
  });

  /// `POST /api/account/reauthentication/start` (bkz. sınıf
  /// dokümantasyonu, adım 1).
  Future<AccountReauthenticationStartResponse> startReauthentication({
    required AccountReauthenticationPurpose purpose,
    required String redirectUri,
    required String codeChallenge,
  });

  /// `POST /api/account/reauthentication/complete` (bkz. sınıf
  /// dokümantasyonu, adım 3).
  Future<AccountReauthenticationCompleteResponse> completeReauthentication({
    required String requestId,
    required String authorizationCode,
    required String state,
    required String codeVerifier,
    required String redirectUri,
  });
}
