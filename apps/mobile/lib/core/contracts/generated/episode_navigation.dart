// GENERATED — elle düzenleme; kaynak: packages/contracts/schema.json, üretici: tool/generate_contracts.dart
// Bu dosyayı elle düzenlemeyin; değişiklik gerekiyorsa
// packages/contracts/schema.json güncellenip codegen yeniden
// çalıştırılmalıdır (dart run tool/generate_contracts.dart).

import 'episode_navigation_ref.dart';

/// Kaynak: `packages/contracts/schema.json` -> `$defs/EpisodeNavigation`.
class EpisodeNavigation {
  const EpisodeNavigation({
    required this.previous,
    required this.next,
  });

  factory EpisodeNavigation.fromJson(Map<String, dynamic> json) {
    final previousRaw = json['previous'];
    final previous = previousRaw == null
        ? null
        : EpisodeNavigationRef.fromJson(
            previousRaw as Map<String, dynamic>,
          );
    final nextRaw = json['next'];
    final next = nextRaw == null
        ? null
        : EpisodeNavigationRef.fromJson(
            nextRaw as Map<String, dynamic>,
          );
    return EpisodeNavigation(
      previous: previous,
      next: next,
    );
  }

  final EpisodeNavigationRef? previous;
  final EpisodeNavigationRef? next;

  Map<String, dynamic> toJson() {
    return {
      'previous': previous?.toJson(),
      'next': next?.toJson(),
    };
  }
}
