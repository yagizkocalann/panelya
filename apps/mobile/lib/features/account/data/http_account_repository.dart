import 'dart:math';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/contracts/generated/generated.dart';
import '../../../core/storage/token_store.dart';
import '../domain/account_exceptions.dart';
import '../domain/account_repository.dart';

/// [AccountRepository]'nin ortak `/api/account/*` sözleşmesine konuşan
/// GERÇEK implementasyonu (bkz. ADR-047, OpenAPI 1.4.1).
///
/// Eski local PBKDF2 web uçları (`/api/account/email`, `/api/account/password`,
/// `/api/account/delete`) KULLANILMAZ — bunlar web'in localhost-QA yolu
/// içindir ve mobil sözleşmesinin parçası değildir.
///
/// Kimlik taşıma: her istek [TokenStore]'daki access token'ı
/// `Authorization: Bearer` olarak gönderir (web aynı sözleşmeyi host-only
/// cookie ile kullanır). Saklı oturum yoksa
/// [AccountNotAuthenticatedException] fırlatır — sunucuya boş bir istek
/// GÖNDERİLMEZ.
///
/// Hata çevirisi: HTTP katmanının ham [AccountApiException]'ı domain'in
/// sealed [AccountRepositoryException] hiyerarşisine çevrilir (bkz.
/// `AccountServerException`); ağ/parse hataları
/// [AccountUnexpectedException] olur. Ekranlar yalnız domain tipini görür.
class HttpAccountRepository implements AccountRepository {
  HttpAccountRepository({
    required this._client,
    required this._tokenStore,
    Random? random,
  }) : _random = random ?? Random.secure();

  final PanelyaApiClient _client;
  final TokenStore _tokenStore;
  final Random _random;

  Future<String> _accessToken() async {
    final stored = await _tokenStore.read();
    if (stored == null) throw const AccountNotAuthenticatedException();
    return stored.accessToken;
  }

  /// Sözleşmenin `POST /api/account/deletion` için zorunlu kıldığı
  /// `Idempotency-Key` (16–128 karakter). Rastgele ve tek seferliktir;
  /// aynı anahtarla tekrar gönderim sunucuda yeni bir iş oluşturmaz.
  String _idempotencyKey() {
    final bytes = List<int>.generate(24, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Tek çeviri noktası: ham HTTP/parse hatalarını domain tipine map eder.
  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on AccountApiException catch (cause) {
      throw AccountServerException(cause.error);
    } on AccountRepositoryException {
      // Zaten domain tipinde (ör. `_accessToken`'ın fırlattığı
      // `AccountNotAuthenticatedException`) — olduğu gibi geçir.
      rethrow;
    } on ApiException catch (cause) {
      throw AccountUnexpectedException(cause.message);
    }
  }

  @override
  Future<AccountOverviewResponse> fetchOverview() => _guard(() async {
    return _client.fetchAccountOverview(accessToken: await _accessToken());
  });

  @override
  Future<AccountOverviewResponse> updateProfile({
    required String displayName,
  }) => _guard(() async {
    return _client.updateAccountProfile(
      accessToken: await _accessToken(),
      request: AccountProfileUpdateRequest(displayName: displayName),
    );
  });

  @override
  Future<AccountActionAcceptedResponse> requestPasswordReset() =>
      _guard(() async {
        return _client.requestAccountPasswordReset(
          accessToken: await _accessToken(),
        );
      });

  @override
  Future<AccountActionAcceptedResponse> requestEmailChange({
    required String newEmail,
    required String reauthenticationToken,
  }) => _guard(() async {
    return _client.requestAccountEmailChange(
      accessToken: await _accessToken(),
      request: AccountEmailChangeRequest(
        newEmail: newEmail,
        reauthenticationToken: reauthenticationToken,
      ),
    );
  });

  @override
  Future<AccountSessionsResponse> fetchSessions() => _guard(() async {
    return _client.fetchAccountSessions(accessToken: await _accessToken());
  });

  @override
  Future<AccountSessionRevocationResponse> revokeSession(String sessionId) =>
      _guard(() async {
        return _client.revokeAccountSession(
          accessToken: await _accessToken(),
          sessionId: sessionId,
        );
      });

  @override
  Future<AccountSessionRevocationResponse> revokeSessions({
    required String scope,
  }) => _guard(() async {
    // NOT: `scope: others` şu an sunucuda 503 fail-closed döner (bkz.
    // `AccountRepository.revokeSessions` sınır notu). Burada özel bir
    // "başarılı gibi davran" yolu YOKTUR — hata olduğu gibi
    // `AccountServerException`a çevrilip yüzeye çıkar.
    return _client.revokeAccountSessions(
      accessToken: await _accessToken(),
      request: AccountSessionRevocationRequest(scope: scope),
    );
  });

  @override
  Future<BlockedAccountsResponse> fetchBlockedAccounts() => _guard(() async {
    return _client.fetchAccountBlocks(accessToken: await _accessToken());
  });

  @override
  Future<AccountActionAcceptedResponse> unblockAccount(String userId) =>
      _guard(() async {
        return _client.unblockAccount(
          accessToken: await _accessToken(),
          userId: userId,
        );
      });

  @override
  Future<AccountDeletionSummaryResponse> fetchDeletionSummary() =>
      _guard(() async {
        return _client.fetchAccountDeletionSummary(
          accessToken: await _accessToken(),
        );
      });

  @override
  Future<AccountDeletionOperationResponse> deleteAccount({
    required String reauthenticationToken,
  }) => _guard(() async {
    return _client.deleteAccount(
      accessToken: await _accessToken(),
      request: AccountDeletionRequest(
        // Sözleşmede sabit (`const: "delete_my_account"`).
        confirmation: 'delete_my_account',
        reauthenticationToken: reauthenticationToken,
      ),
      idempotencyKey: _idempotencyKey(),
    );
  });

  @override
  Future<AccountReauthenticationStartResponse> startReauthentication({
    required AccountReauthenticationPurpose purpose,
    required String redirectUri,
    required String codeChallenge,
  }) => _guard(() async {
    return _client.startAccountReauthentication(
      accessToken: await _accessToken(),
      request: AccountReauthenticationStartRequest(
        purpose: purpose,
        redirectUri: redirectUri,
        codeChallenge: codeChallenge,
        // Sözleşmede sabit (`const: "S256"`); PKCE `plain` DESTEKLENMEZ.
        codeChallengeMethod: 'S256',
      ),
    );
  });

  @override
  Future<AccountReauthenticationCompleteResponse> completeReauthentication({
    required String requestId,
    required String authorizationCode,
    required String state,
    required String codeVerifier,
    required String redirectUri,
  }) => _guard(() async {
    return _client.completeAccountReauthentication(
      accessToken: await _accessToken(),
      request: AccountReauthenticationCompleteRequest(
        requestId: requestId,
        authorizationCode: authorizationCode,
        state: state,
        codeVerifier: codeVerifier,
        redirectUri: redirectUri,
      ),
    );
  });
}
