import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/reading_progress.dart';
import '../domain/reading_progress_repository.dart';

/// [LocalReadingProgressRepository]'nin tek implementasyonu:
/// `seriesSlug -> ReadingProgress` haritasını tek bir JSON string'i olarak
/// `SharedPreferences` altında saklar.
///
/// Neden `shared_preferences` (bkz. AGENTS.md "Yeni dependency gerekcesiz
/// eklenmez" kuralına gerekçeli istisna, teslim raporunda da tekrarlanır):
/// Flutter ekosisteminin standart, hafif anahtar-değer çözümü. Bu özellik
/// tek bir küçük JSON belgesi saklıyor; dosya IO'sunu elle yazmak (path,
/// atomic write, platform farkları) test edilmesi zor bir platform-kanalı
/// kodunu yeniden icat etmek olurdu. Hive/Isar/sqflite gibi daha ağır bir
/// çözüm bu basit anahtar-değer kaydı için gerekli değil.
class SharedPreferencesReadingProgressRepository
    implements LocalReadingProgressRepository {
  /// [userId] `null` ise ANONIM cihaz namespace'i kullanılır.
  ///
  /// NAMESPACE AYRIMI (bkz. ADR-049): her kullanıcının ilerlemesi kendi
  /// anahtarında tutulur; anonim cihaz kaydı ayrı bir anahtardadır. Böylece
  /// çıkış yapınca veya BAŞKA bir hesaba geçince önceki kullanıcının
  /// ilerlemesi GÖRÜNMEZ — tek anahtar kullanılsaydı veri hesaplar arasında
  /// sızardı.
  SharedPreferencesReadingProgressRepository(this._prefs, {String? userId})
    : _storageKey = userId == null ? _anonymousKey : '$_userKeyPrefix$userId';

  /// Anonim/cihaz-yerel namespace. Kullanıcı giriş yapsa bile bu kayıtlar
  /// hesaba SESSIZCE YÜKLENMEZ; burada korunur.
  static const _anonymousKey = 'panelya.reading_progress.v1';
  static const _userKeyPrefix = 'panelya.reading_progress.v1.user.';

  final String _storageKey;
  final SharedPreferences _prefs;

  Map<String, dynamic> _readAll() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return <String, dynamic>{};
      return decoded;
    } on FormatException {
      // Bozuk/eski biçim: bu salt cihaz-yerel bir önbellektir (kritik veri
      // değil), kullanıcıya hata göstermek yerine sessizce sıfırlanır.
      return <String, dynamic>{};
    }
  }

  Future<void> _writeAll(Map<String, dynamic> data) {
    return _prefs.setString(_storageKey, jsonEncode(data));
  }

  @override
  ReadingProgress? findBySeries(String seriesSlug) {
    final raw = _readAll()[seriesSlug];
    if (raw is! Map<String, dynamic>) return null;
    return ReadingProgress.fromJson(raw);
  }

  @override
  ReadingProgress? findMostRecent() {
    ReadingProgress? mostRecent;
    for (final raw in _readAll().values) {
      if (raw is! Map<String, dynamic>) continue;
      final entry = ReadingProgress.fromJson(raw);
      if (mostRecent == null || entry.updatedAt.isAfter(mostRecent.updatedAt)) {
        mostRecent = entry;
      }
    }
    return mostRecent;
  }

  @override
  Future<void> recordEpisodeOpened({
    required String seriesSlug,
    required String seriesTitle,
    required String episodeSlug,
    required int episodeNumber,
  }) {
    final all = _readAll();
    all[seriesSlug] = ReadingProgress(
      seriesSlug: seriesSlug,
      seriesTitle: seriesTitle,
      episodeSlug: episodeSlug,
      episodeNumber: episodeNumber,
      updatedAt: DateTime.now(),
      completed: false,
    ).toJson();
    return _writeAll(all);
  }

  @override
  Future<void> recordEpisodeCompleted({
    required String seriesSlug,
    required String seriesTitle,
    required String episodeSlug,
    required int episodeNumber,
    String? nextEpisodeSlug,
    int? nextEpisodeNumber,
  }) {
    final hasNext = nextEpisodeSlug != null && nextEpisodeNumber != null;
    final all = _readAll();
    all[seriesSlug] = ReadingProgress(
      seriesSlug: seriesSlug,
      seriesTitle: seriesTitle,
      episodeSlug: hasNext ? nextEpisodeSlug : episodeSlug,
      episodeNumber: hasNext ? nextEpisodeNumber : episodeNumber,
      updatedAt: DateTime.now(),
      completed: !hasNext,
    ).toJson();
    return _writeAll(all);
  }
}
