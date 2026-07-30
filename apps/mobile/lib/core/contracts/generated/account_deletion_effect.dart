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

/// Kaynak: `packages/contracts/schema.json` -> `$defs/AccountDeletionEffect`.
///
/// LENIENT enum politikası: `unknown`, sunucudan gelen tanınmayan bir
/// değer için ileri-uyumluluk fallback'idir (bkz.
/// `tool/generate_contracts.dart` dosya başlığı, tasarım kararı #6).
/// `fromJson` tanınmayan bir string için asla exception fırlatmaz.
/// `toJson()` ise `unknown` için TANIMSIZDIR (ham sunucu değeri elde
/// tutulmadığından geri serialize edilemez) ve `UnsupportedError`
/// fırlatır; bu istemci `unknown` bir değeri hiçbir zaman sunucuya
/// geri yazmaz (yalnız okur).
enum AccountDeletionEffect {
  auth_identity,
  profile,
  active_sessions,
  library,
  reading_progress,
  block_relationships,
  community_contributions,
  legal_and_audit_records,

  /// Sunucudan gelen, bu istemcinin bilmediği bir değer için ileri-uyumluluk
  /// fallback değeri. `toJson()` bu değer için çağrılamaz.
  unknown,

  ;

  static AccountDeletionEffect fromJson(String value) {
    switch (value) {
      case 'auth_identity':
        return AccountDeletionEffect.auth_identity;
      case 'profile':
        return AccountDeletionEffect.profile;
      case 'active_sessions':
        return AccountDeletionEffect.active_sessions;
      case 'library':
        return AccountDeletionEffect.library;
      case 'reading_progress':
        return AccountDeletionEffect.reading_progress;
      case 'block_relationships':
        return AccountDeletionEffect.block_relationships;
      case 'community_contributions':
        return AccountDeletionEffect.community_contributions;
      case 'legal_and_audit_records':
        return AccountDeletionEffect.legal_and_audit_records;
      default:
        return AccountDeletionEffect.unknown;
    }
  }

  String toJson() {
    if (this == AccountDeletionEffect.unknown) {
      throw UnsupportedError(
        'AccountDeletionEffect.unknown serialize edilemez (ham sunucu değeri tutulmuyor).',
      );
    }
    return name;
  }
}
