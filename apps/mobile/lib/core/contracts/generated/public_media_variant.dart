// GENERATED — elle düzenleme; kaynak: packages/contracts/schema.json, üretici: tool/generate_contracts.dart
// Bu dosyayı elle düzenlemeyin; değişiklik gerekiyorsa
// packages/contracts/schema.json güncellenip codegen yeniden
// çalıştırılmalıdır (dart run tool/generate_contracts.dart).

/// Kaynak: `packages/contracts/schema.json` -> `$defs/PublicMediaVariant`.
class PublicMediaVariant {
  const PublicMediaVariant({
    required this.src,
    required this.width,
    required this.height,
    required this.mimeType,
  });

  factory PublicMediaVariant.fromJson(Map<String, dynamic> json) {
    final src = json['src'] as String;
    final width = (json['width'] as num).toInt();
    final height = (json['height'] as num).toInt();
    final mimeType = json['mimeType'] as String;
    return PublicMediaVariant(
      src: src,
      width: width,
      height: height,
      mimeType: mimeType,
    );
  }

  /// Public media URL for an available derivative; clients must not construct storage keys.
  final String src;
  final int width;
  final int height;
  final String mimeType;

  Map<String, dynamic> toJson() {
    return {
      'src': src,
      'width': width,
      'height': height,
      'mimeType': mimeType,
    };
  }
}
