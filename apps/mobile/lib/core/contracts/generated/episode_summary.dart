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

/// Kaynak: `packages/contracts/schema.json` -> `$defs/EpisodeSummary`.
class EpisodeSummary {
  const EpisodeSummary({
    required this.slug,
    required this.number,
    required this.title,
    required this.publishedAt,
    required this.readTime,
    required this.panelCount,
  });

  factory EpisodeSummary.fromJson(Map<String, dynamic> json) {
    final slug = json['slug'] as String;
    final number = (json['number'] as num).toInt();
    final title = json['title'] as String;
    final publishedAt = json['publishedAt'] as String;
    final readTime = json['readTime'] as String;
    final panelCount = (json['panelCount'] as num).toInt();
    return EpisodeSummary(
      slug: slug,
      number: number,
      title: title,
      publishedAt: publishedAt,
      readTime: readTime,
      panelCount: panelCount,
    );
  }

  final String slug;
  final int number;
  final String title;
  final String publishedAt;
  final String readTime;
  final int panelCount;

  Map<String, dynamic> toJson() {
    return {
      'slug': slug,
      'number': number,
      'title': title,
      'publishedAt': publishedAt,
      'readTime': readTime,
      'panelCount': panelCount,
    };
  }
}
