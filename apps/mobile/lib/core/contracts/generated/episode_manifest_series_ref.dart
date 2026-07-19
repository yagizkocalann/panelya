// GENERATED — elle düzenleme; kaynak: packages/contracts/schema.json, üretici: tool/generate_contracts.dart
// Bu dosyayı elle düzenlemeyin; değişiklik gerekiyorsa
// packages/contracts/schema.json güncellenip codegen yeniden
// çalıştırılmalıdır (dart run tool/generate_contracts.dart).

/// Kaynak: `packages/contracts/schema.json` -> `$defs/EpisodeManifestSeriesRef`.
class EpisodeManifestSeriesRef {
  const EpisodeManifestSeriesRef({
    required this.slug,
    required this.title,
  });

  factory EpisodeManifestSeriesRef.fromJson(Map<String, dynamic> json) {
    final slug = json['slug'] as String;
    final title = json['title'] as String;
    return EpisodeManifestSeriesRef(
      slug: slug,
      title: title,
    );
  }

  final String slug;
  final String title;

  Map<String, dynamic> toJson() {
    return {
      'slug': slug,
      'title': title,
    };
  }
}
