// GENERATED — elle düzenleme; kaynak: packages/contracts/schema.json, üretici: tool/generate_contracts.dart
// Bu dosyayı elle düzenlemeyin; değişiklik gerekiyorsa
// packages/contracts/schema.json güncellenip codegen yeniden
// çalıştırılmalıdır (dart run tool/generate_contracts.dart).

/// Kaynak: `packages/contracts/schema.json` -> `$defs/EpisodeNavigationRef`.
class EpisodeNavigationRef {
  const EpisodeNavigationRef({
    required this.slug,
    required this.number,
  });

  factory EpisodeNavigationRef.fromJson(Map<String, dynamic> json) {
    final slug = json['slug'] as String;
    final number = (json['number'] as num).toInt();
    return EpisodeNavigationRef(
      slug: slug,
      number: number,
    );
  }

  final String slug;
  final int number;

  Map<String, dynamic> toJson() {
    return {
      'slug': slug,
      'number': number,
    };
  }
}
