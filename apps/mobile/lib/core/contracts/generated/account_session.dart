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

import 'account_session_platform.dart';

/// Kaynak: `packages/contracts/schema.json` -> `$defs/AccountSession`.
class AccountSession {
  const AccountSession({
    required this.id,
    required this.deviceLabel,
    required this.platform,
    required this.lastActiveAt,
    required this.current,
    required this.revocable,
  });

  factory AccountSession.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final deviceLabel = json['deviceLabel'] as String;
    final platform = AccountSessionPlatform.fromJson(json['platform'] as String);
    final lastActiveAt = json['lastActiveAt'] as String;
    final current = json['current'] as bool;
    final revocable = json['revocable'] as bool;
    return AccountSession(
      id: id,
      deviceLabel: deviceLabel,
      platform: platform,
      lastActiveAt: lastActiveAt,
      current: current,
      revocable: revocable,
    );
  }

  final String id;
  final String deviceLabel;
  final AccountSessionPlatform platform;
  final String lastActiveAt;
  final bool current;
  final bool revocable;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceLabel': deviceLabel,
      'platform': platform.toJson(),
      'lastActiveAt': lastActiveAt,
      'current': current,
      'revocable': revocable,
    };
  }
}
