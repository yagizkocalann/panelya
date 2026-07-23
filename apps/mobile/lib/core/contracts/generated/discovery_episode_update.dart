// GENERATED — elle düzenleme; kaynak: packages/contracts/schema.json, üretici: tool/generate_contracts.dart
// Bu dosyayı elle düzenlemeyin; değişiklik gerekiyorsa
// packages/contracts/schema.json güncellenip codegen yeniden
// çalıştırılmalıdır (dart run tool/generate_contracts.dart).

import 'discovery_series_summary.dart';
import 'episode_summary.dart';

/// Kaynak: `packages/contracts/schema.json` -> `$defs/DiscoveryEpisodeUpdate`.
class DiscoveryEpisodeUpdate {
  const DiscoveryEpisodeUpdate({
    required this.series,
    required this.episode,
  });

  factory DiscoveryEpisodeUpdate.fromJson(Map<String, dynamic> json) {
    final series = DiscoverySeriesSummary.fromJson(
      json['series'] as Map<String, dynamic>,
    );
    final episode = EpisodeSummary.fromJson(
      json['episode'] as Map<String, dynamic>,
    );
    return DiscoveryEpisodeUpdate(
      series: series,
      episode: episode,
    );
  }

  final DiscoverySeriesSummary series;
  final EpisodeSummary episode;

  Map<String, dynamic> toJson() {
    return {
      'series': series.toJson(),
      'episode': episode.toJson(),
    };
  }
}
