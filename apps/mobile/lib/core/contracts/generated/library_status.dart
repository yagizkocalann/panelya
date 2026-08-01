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

/// Kaynak: `packages/contracts/schema.json` -> `$defs/LibraryStatus`.
///
/// LENIENT enum politikası: `unknown`, sunucudan gelen tanınmayan bir
/// değer için ileri-uyumluluk fallback'idir (bkz.
/// `tool/generate_contracts.dart` dosya başlığı, tasarım kararı #6).
/// `fromJson` tanınmayan bir string için asla exception fırlatmaz.
/// `toJson()` ise `unknown` için TANIMSIZDIR (ham sunucu değeri elde
/// tutulmadığından geri serialize edilemez) ve `UnsupportedError`
/// fırlatır; bu istemci `unknown` bir değeri hiçbir zaman sunucuya
/// geri yazmaz (yalnız okur).
enum LibraryStatus {
  plan,
  reading,
  completed,
  paused,
  dropped,

  /// Sunucudan gelen, bu istemcinin bilmediği bir değer için ileri-uyumluluk
  /// fallback değeri. `toJson()` bu değer için çağrılamaz.
  unknown,

  ;

  static LibraryStatus fromJson(String value) {
    switch (value) {
      case 'plan':
        return LibraryStatus.plan;
      case 'reading':
        return LibraryStatus.reading;
      case 'completed':
        return LibraryStatus.completed;
      case 'paused':
        return LibraryStatus.paused;
      case 'dropped':
        return LibraryStatus.dropped;
      default:
        return LibraryStatus.unknown;
    }
  }

  String toJson() {
    if (this == LibraryStatus.unknown) {
      throw UnsupportedError(
        'LibraryStatus.unknown serialize edilemez (ham sunucu değeri tutulmuyor).',
      );
    }
    return name;
  }
}
