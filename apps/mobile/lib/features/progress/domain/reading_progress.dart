import 'package:flutter/foundation.dart';

/// Bir seri için cihaz-yerel "kaldığın yerden devam et" kaydı.
///
/// Bu, auth'lu `POST /api/progress` sözleşmesinin bir mobil kopyası
/// DEĞİLDİR (bkz. docs/mobile-handoff.md — o uç hesap kimliğine bağlıdır ve
/// production auth adaptörü netleşene kadar mobilden çağrılmaz). Bu kayıt
/// yalnız cihazda yaşar, hiçbir API'ye gönderilmez ve hesapsız kullanıcı
/// için de çalışır.
///
/// [episodeSlug]/[episodeNumber] her zaman "devam edilecek" bölümü işaret
/// eder: bir bölüm açıldığında o bölümü, bir bölüm sonuna kadar
/// okunduğunda (varsa) bir sonraki bölümü gösterir (bkz.
/// [LocalReadingProgressRepository] implementasyonundaki güncelleme
/// mantığı).
@immutable
class ReadingProgress {
  const ReadingProgress({
    required this.seriesSlug,
    required this.seriesTitle,
    required this.episodeSlug,
    required this.episodeNumber,
    required this.updatedAt,
    required this.completed,
  });

  final String seriesSlug;
  final String seriesTitle;
  final String episodeSlug;
  final int episodeNumber;

  /// Bu kaydın en son yazıldığı an (bölüm açılışı veya bitişi).
  final DateTime updatedAt;

  /// `true` yalnız [episodeSlug] serinin o anda bilinen son bölümüyse VE o
  /// bölüm sonuna kadar okunmuşsa (bkz. `recordEpisodeCompleted`). Bu alan
  /// ekranda ayrı bir metin/rozet olarak KULLANILMAZ (kapsam dışı); yalnız
  /// depolama katmanının iç mantığı ve testleri için tutulur.
  final bool completed;

  factory ReadingProgress.fromJson(Map<String, dynamic> json) {
    return ReadingProgress(
      seriesSlug: json['seriesSlug'] as String,
      seriesTitle: json['seriesTitle'] as String,
      episodeSlug: json['episodeSlug'] as String,
      episodeNumber: (json['episodeNumber'] as num).toInt(),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      completed: json['completed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'seriesSlug': seriesSlug,
      'seriesTitle': seriesTitle,
      'episodeSlug': episodeSlug,
      'episodeNumber': episodeNumber,
      'updatedAt': updatedAt.toIso8601String(),
      'completed': completed,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is ReadingProgress &&
            runtimeType == other.runtimeType &&
            seriesSlug == other.seriesSlug &&
            seriesTitle == other.seriesTitle &&
            episodeSlug == other.episodeSlug &&
            episodeNumber == other.episodeNumber &&
            updatedAt == other.updatedAt &&
            completed == other.completed);
  }

  @override
  int get hashCode => Object.hash(
    seriesSlug,
    seriesTitle,
    episodeSlug,
    episodeNumber,
    updatedAt,
    completed,
  );

  @override
  String toString() =>
      'ReadingProgress(seriesSlug: $seriesSlug, episodeSlug: $episodeSlug, '
      'episodeNumber: $episodeNumber, updatedAt: $updatedAt, '
      'completed: $completed)';
}
