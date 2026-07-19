// GENERATED — elle düzenleme; kaynak: packages/contracts/schema.json, üretici: tool/generate_contracts.dart
// Bu dosyayı elle düzenlemeyin; değişiklik gerekiyorsa
// packages/contracts/schema.json güncellenip codegen yeniden
// çalıştırılmalıdır (dart run tool/generate_contracts.dart).

import 'story_panel.dart';

/// Kaynak: `packages/contracts/schema.json` -> `$defs/Episode`.
class Episode {
  const Episode({
    required this.slug,
    required this.number,
    required this.title,
    required this.publishedAt,
    required this.readTime,
    required this.panels,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    final slug = json['slug'] as String;
    final number = (json['number'] as num).toInt();
    final title = json['title'] as String;
    final publishedAt = json['publishedAt'] as String;
    final readTime = json['readTime'] as String;
    final panels = (json['panels'] as List<dynamic>)
        .map(
          (item) => StoryPanel.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList(growable: false);
    return Episode(
      slug: slug,
      number: number,
      title: title,
      publishedAt: publishedAt,
      readTime: readTime,
      panels: panels,
    );
  }

  final String slug;
  final int number;
  final String title;
  /// Current v1 API returns a localized display label, not an ISO timestamp.
  final String publishedAt;
  final String readTime;
  final List<StoryPanel> panels;

  Map<String, dynamic> toJson() {
    return {
      'slug': slug,
      'number': number,
      'title': title,
      'publishedAt': publishedAt,
      'readTime': readTime,
      'panels': panels.map((e) => e.toJson()).toList(),
    };
  }
}
