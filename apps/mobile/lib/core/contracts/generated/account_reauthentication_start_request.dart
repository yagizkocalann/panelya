// GENERATED — elle düzenleme; kaynak: packages/contracts/schema.json, üretici: tool/generate_contracts.dart
// Bu dosyayı elle düzenlemeyin; değişiklik gerekiyorsa
// packages/contracts/schema.json güncellenip codegen yeniden
// çalıştırılmalıdır (dart run tool/generate_contracts.dart).
//
// `constant_identifier_names` KAPALI: üretilen enum üyeleri şemadaki
// JSON değerlerini (ör. `provider_managed`, `auth_identity`) BİREBİR
// yansıtır. lowerCamelCase'e çevirmek, `fromJson`/`toJson`
// eşlemesini şemadan görsel olarak ayırır ve sessiz bir eşleme
// hatası riski yaratır; sözleşmeyle bire bir aynı kalması bilinçli
// bir tercihtir.
// ignore_for_file: constant_identifier_names

import 'account_reauthentication_purpose.dart';

/// Kaynak: `packages/contracts/schema.json` -> `$defs/AccountReauthenticationStartRequest`.
class AccountReauthenticationStartRequest {
  const AccountReauthenticationStartRequest({
    required this.purpose,
    required this.redirectUri,
    required this.codeChallenge,
    required this.codeChallengeMethod,
  });

  factory AccountReauthenticationStartRequest.fromJson(Map<String, dynamic> json) {
    final purpose = AccountReauthenticationPurpose.fromJson(json['purpose'] as String);
    final redirectUri = json['redirectUri'] as String;
    final codeChallenge = json['codeChallenge'] as String;
    final codeChallengeMethod = json['codeChallengeMethod'] as String;
    return AccountReauthenticationStartRequest(
      purpose: purpose,
      redirectUri: redirectUri,
      codeChallenge: codeChallenge,
      codeChallengeMethod: codeChallengeMethod,
    );
  }

  final AccountReauthenticationPurpose purpose;
  final String redirectUri;
  final String codeChallenge;
  final String codeChallengeMethod;

  Map<String, dynamic> toJson() {
    return {
      'purpose': purpose.toJson(),
      'redirectUri': redirectUri,
      'codeChallenge': codeChallenge,
      'codeChallengeMethod': codeChallengeMethod,
    };
  }
}
