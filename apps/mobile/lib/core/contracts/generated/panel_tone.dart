// GENERATED — elle düzenleme; kaynak: packages/contracts/schema.json, üretici: tool/generate_contracts.dart
// Bu dosyayı elle düzenlemeyin; değişiklik gerekiyorsa
// packages/contracts/schema.json güncellenip codegen yeniden
// çalıştırılmalıdır (dart run tool/generate_contracts.dart).

/// Kaynak: `packages/contracts/schema.json` -> `$defs/PanelTone`.
///
/// LENIENT enum politikası: `unknown`, sunucudan gelen tanınmayan bir
/// değer için ileri-uyumluluk fallback'idir (bkz.
/// `tool/generate_contracts.dart` dosya başlığı, tasarım kararı #6).
/// `fromJson` tanınmayan bir string için asla exception fırlatmaz.
/// `toJson()` ise `unknown` için TANIMSIZDIR (ham sunucu değeri elde
/// tutulmadığından geri serialize edilemez) ve `UnsupportedError`
/// fırlatır; bu istemci `unknown` bir değeri hiçbir zaman sunucuya
/// geri yazmaz (yalnız okur).
enum PanelTone {
  coral,
  mint,
  violet,
  blue,
  amber,
  rose,

  /// Sunucudan gelen, bu istemcinin bilmediği bir değer için ileri-uyumluluk
  /// fallback değeri. `toJson()` bu değer için çağrılamaz.
  unknown,

  ;

  static PanelTone fromJson(String value) {
    switch (value) {
      case 'coral':
        return PanelTone.coral;
      case 'mint':
        return PanelTone.mint;
      case 'violet':
        return PanelTone.violet;
      case 'blue':
        return PanelTone.blue;
      case 'amber':
        return PanelTone.amber;
      case 'rose':
        return PanelTone.rose;
      default:
        return PanelTone.unknown;
    }
  }

  String toJson() {
    if (this == PanelTone.unknown) {
      throw UnsupportedError(
        'PanelTone.unknown serialize edilemez (ham sunucu değeri tutulmuyor).',
      );
    }
    return name;
  }
}
