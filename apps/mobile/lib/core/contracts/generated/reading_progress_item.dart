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

import 'discovery_series_summary.dart';
import 'episode_summary.dart';

/// Kaynak: `packages/contracts/schema.json` -> `$defs/ReadingProgressItem`.
class ReadingProgressItem {
  const ReadingProgressItem({
    required this.series,
    required this.episode,
    required this.percent,
    required this.updatedAt,
  });

  factory ReadingProgressItem.fromJson(Map<String, dynamic> json) {
    final series = DiscoverySeriesSummary.fromJson(
      json['series'] as Map<String, dynamic>,
    );
    final episode = EpisodeSummary.fromJson(
      json['episode'] as Map<String, dynamic>,
    );
    final percent = (json['percent'] as num).toInt();
    final updatedAt = json['updatedAt'] as String;
    return ReadingProgressItem(
      series: series,
      episode: episode,
      percent: percent,
      updatedAt: updatedAt,
    );
  }

  final DiscoverySeriesSummary series;
  final EpisodeSummary episode;
  /// Last server-accepted reading position for the episode. A value of 100 means the episode was completed.
  final int percent;
  /// ISO-8601 UTC server timestamp used for last-write-wins ordering.
  final String updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'series': series.toJson(),
      'episode': episode.toJson(),
      'percent': percent,
      'updatedAt': updatedAt,
    };
  }
}
