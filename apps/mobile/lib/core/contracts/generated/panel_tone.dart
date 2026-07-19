// GENERATED — elle düzenleme; kaynak: packages/contracts/schema.json, üretici: tool/generate_contracts.dart
// Bu dosyayı elle düzenlemeyin; değişiklik gerekiyorsa
// packages/contracts/schema.json güncellenip codegen yeniden
// çalıştırılmalıdır (dart run tool/generate_contracts.dart).

/// Kaynak: `packages/contracts/schema.json` -> `$defs/PanelTone`.
enum PanelTone {
  coral,
  mint,
  violet,
  blue,
  amber,
  rose,

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
        throw FormatException('Bilinmeyen PanelTone değeri: $value');
    }
  }

  String toJson() => name;
}
