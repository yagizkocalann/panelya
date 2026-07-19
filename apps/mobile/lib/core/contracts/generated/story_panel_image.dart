// GENERATED — elle düzenleme; kaynak: packages/contracts/schema.json, üretici: tool/generate_contracts.dart
// Bu dosyayı elle düzenlemeyin; değişiklik gerekiyorsa
// packages/contracts/schema.json güncellenip codegen yeniden
// çalıştırılmalıdır (dart run tool/generate_contracts.dart).

/// Kaynak: `packages/contracts/schema.json` -> `$defs/StoryPanelImage`.
class StoryPanelImage {
  const StoryPanelImage({
    required this.src,
    required this.alt,
    required this.width,
    required this.height,
  });

  factory StoryPanelImage.fromJson(Map<String, dynamic> json) {
    final src = json['src'] as String;
    final alt = json['alt'] as String;
    final width = (json['width'] as num).toInt();
    final height = (json['height'] as num).toInt();
    return StoryPanelImage(
      src: src,
      alt: alt,
      width: width,
      height: height,
    );
  }

  final String src;
  final String alt;
  final int width;
  final int height;

  Map<String, dynamic> toJson() {
    return {
      'src': src,
      'alt': alt,
      'width': width,
      'height': height,
    };
  }
}
