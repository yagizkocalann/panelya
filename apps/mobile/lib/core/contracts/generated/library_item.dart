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
import 'library_status.dart';

/// Kaynak: `packages/contracts/schema.json` -> `$defs/LibraryItem`.
class LibraryItem {
  const LibraryItem({
    required this.series,
    required this.status,
    required this.favorite,
    required this.updatedAt,
  });

  factory LibraryItem.fromJson(Map<String, dynamic> json) {
    final series = DiscoverySeriesSummary.fromJson(
      json['series'] as Map<String, dynamic>,
    );
    final status = LibraryStatus.fromJson(json['status'] as String);
    final favorite = json['favorite'] as bool;
    final updatedAt = json['updatedAt'] as String;
    return LibraryItem(
      series: series,
      status: status,
      favorite: favorite,
      updatedAt: updatedAt,
    );
  }

  final DiscoverySeriesSummary series;
  final LibraryStatus status;
  final bool favorite;
  /// ISO-8601 UTC timestamp used for stable server ordering.
  final String updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'series': series.toJson(),
      'status': status.toJson(),
      'favorite': favorite,
      'updatedAt': updatedAt,
    };
  }
}
