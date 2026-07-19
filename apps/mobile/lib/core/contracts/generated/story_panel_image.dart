// GENERATED — elle düzenleme; kaynak: packages/contracts/schema.json, üretici: tool/generate_contracts.dart
// Bu dosyayı elle düzenlemeyin; değişiklik gerekiyorsa
// packages/contracts/schema.json güncellenip codegen yeniden
// çalıştırılmalıdır (dart run tool/generate_contracts.dart).

import 'public_media_variant.dart';

/// Kaynak: `packages/contracts/schema.json` -> `$defs/StoryPanelImage`.
class StoryPanelImage {
  const StoryPanelImage({
    required this.src,
    required this.alt,
    required this.width,
    required this.height,
    this.variants,
  });

  factory StoryPanelImage.fromJson(Map<String, dynamic> json) {
    final src = json['src'] as String;
    final alt = json['alt'] as String;
    final width = (json['width'] as num).toInt();
    final height = (json['height'] as num).toInt();
    final variantsRaw = json['variants'];
    final variants = variantsRaw == null ? null : (variantsRaw as List<dynamic>)
        .map(
          (item) => PublicMediaVariant.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList(growable: false);
    return StoryPanelImage(
      src: src,
      alt: alt,
      width: width,
      height: height,
      variants: variants,
    );
  }

  final String src;
  final String alt;
  final int width;
  final int height;
  /// Ready responsive derivatives sorted by ascending width. The source URL remains the fallback.
  final List<PublicMediaVariant>? variants;

  Map<String, dynamic> toJson() {
    return {
      'src': src,
      'alt': alt,
      'width': width,
      'height': height,
      'variants': variants?.map((e) => e.toJson()).toList(),
    };
  }
}
