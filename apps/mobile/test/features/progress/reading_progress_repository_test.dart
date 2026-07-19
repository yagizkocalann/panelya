import 'package:flutter_test/flutter_test.dart';
import 'package:panelya_mobile/features/progress/data/shared_preferences_reading_progress_repository.dart';
import 'package:panelya_mobile/features/progress/domain/reading_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [SharedPreferencesReadingProgressRepository] birim testleri: cihaz-yerel
/// "kaldığın yerden devam et" depolama mantığının, gerçek bir ekran/widget
/// olmadan doğrulanması (bkz. PLAN — repository birim testleri).
///
/// `SharedPreferences.setMockInitialValues` platform kanalını taklit eder;
/// gerçek bir cihaza/dosya sistemine dokunmadan `getInstance()` çalışır
/// (bkz. görev talimatı — testlerde mock/in-memory kullanılabilir).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ReadingProgress model', () {
    test('toJson/fromJson round-trips every field, including completed and'
        ' updatedAt precision', () {
      final original = ReadingProgress(
        seriesSlug: 'gece-vardiyasi',
        seriesTitle: 'Gece Vardiyası',
        episodeSlug: 'bolum-2',
        episodeNumber: 2,
        updatedAt: DateTime.utc(2026, 7, 18, 12, 30),
        completed: true,
      );

      final restored = ReadingProgress.fromJson(original.toJson());

      expect(restored, original);
    });

    test('fromJson defaults completed to false when the field is missing '
        '(forward-compatible with older/partial records)', () {
      final restored = ReadingProgress.fromJson({
        'seriesSlug': 'gece-vardiyasi',
        'seriesTitle': 'Gece Vardiyası',
        'episodeSlug': 'bolum-1',
        'episodeNumber': 1,
        'updatedAt': DateTime.utc(2026, 7, 18).toIso8601String(),
      });

      expect(restored.completed, isFalse);
    });
  });

  group('SharedPreferencesReadingProgressRepository', () {
    test('findBySeries returns null when there is no record for that '
        'series', () async {
      final prefs = await SharedPreferences.getInstance();
      final repository = SharedPreferencesReadingProgressRepository(prefs);

      expect(repository.findBySeries('gece-vardiyasi'), isNull);
    });

    test('recordEpisodeOpened persists a record findable by series slug, '
        'with completed: false', () async {
      final prefs = await SharedPreferences.getInstance();
      final repository = SharedPreferencesReadingProgressRepository(prefs);

      await repository.recordEpisodeOpened(
        seriesSlug: 'gece-vardiyasi',
        seriesTitle: 'Gece Vardiyası',
        episodeSlug: 'bolum-1',
        episodeNumber: 1,
      );

      final stored = repository.findBySeries('gece-vardiyasi');
      expect(stored, isNotNull);
      expect(stored!.seriesSlug, 'gece-vardiyasi');
      expect(stored.seriesTitle, 'Gece Vardiyası');
      expect(stored.episodeSlug, 'bolum-1');
      expect(stored.episodeNumber, 1);
      expect(stored.completed, isFalse);
    });

    test('opening a second episode in the same series overwrites the '
        'continue target (most recently opened wins)', () async {
      final prefs = await SharedPreferences.getInstance();
      final repository = SharedPreferencesReadingProgressRepository(prefs);

      await repository.recordEpisodeOpened(
        seriesSlug: 'gece-vardiyasi',
        seriesTitle: 'Gece Vardiyası',
        episodeSlug: 'bolum-1',
        episodeNumber: 1,
      );
      await repository.recordEpisodeOpened(
        seriesSlug: 'gece-vardiyasi',
        seriesTitle: 'Gece Vardiyası',
        episodeSlug: 'bolum-2',
        episodeNumber: 2,
      );

      final stored = repository.findBySeries('gece-vardiyasi');
      expect(stored!.episodeSlug, 'bolum-2');
      expect(stored.episodeNumber, 2);
    });

    test('recordEpisodeCompleted with a next episode advances the continue '
        'target to that next episode and keeps completed: false', () async {
      final prefs = await SharedPreferences.getInstance();
      final repository = SharedPreferencesReadingProgressRepository(prefs);

      await repository.recordEpisodeOpened(
        seriesSlug: 'gece-vardiyasi',
        seriesTitle: 'Gece Vardiyası',
        episodeSlug: 'bolum-1',
        episodeNumber: 1,
      );
      await repository.recordEpisodeCompleted(
        seriesSlug: 'gece-vardiyasi',
        seriesTitle: 'Gece Vardiyası',
        episodeSlug: 'bolum-1',
        episodeNumber: 1,
        nextEpisodeSlug: 'bolum-2',
        nextEpisodeNumber: 2,
      );

      final stored = repository.findBySeries('gece-vardiyasi');
      expect(stored!.episodeSlug, 'bolum-2');
      expect(stored.episodeNumber, 2);
      expect(stored.completed, isFalse);
    });

    test('recordEpisodeCompleted with no next episode keeps the continue '
        'target on the finished episode and marks completed: true', () async {
      final prefs = await SharedPreferences.getInstance();
      final repository = SharedPreferencesReadingProgressRepository(prefs);

      await repository.recordEpisodeOpened(
        seriesSlug: 'gece-vardiyasi',
        seriesTitle: 'Gece Vardiyası',
        episodeSlug: 'bolum-3',
        episodeNumber: 3,
      );
      await repository.recordEpisodeCompleted(
        seriesSlug: 'gece-vardiyasi',
        seriesTitle: 'Gece Vardiyası',
        episodeSlug: 'bolum-3',
        episodeNumber: 3,
      );

      final stored = repository.findBySeries('gece-vardiyasi');
      expect(stored!.episodeSlug, 'bolum-3');
      expect(stored.episodeNumber, 3);
      expect(stored.completed, isTrue);
    });

    test('findMostRecent returns the most recently updated record across '
        'multiple series', () async {
      final prefs = await SharedPreferences.getInstance();
      final repository = SharedPreferencesReadingProgressRepository(prefs);

      await repository.recordEpisodeOpened(
        seriesSlug: 'gece-vardiyasi',
        seriesTitle: 'Gece Vardiyası',
        episodeSlug: 'bolum-1',
        episodeNumber: 1,
      );
      // İkinci seri kaydı sonradan yazıldığı için en son güncellenen odur.
      await repository.recordEpisodeOpened(
        seriesSlug: 'yarinki-ses',
        seriesTitle: 'Yarınki Ses',
        episodeSlug: 'bolum-1',
        episodeNumber: 1,
      );

      final mostRecent = repository.findMostRecent();
      expect(mostRecent!.seriesSlug, 'yarinki-ses');
    });

    test('findMostRecent returns null when there are no records at all', () async {
      final prefs = await SharedPreferences.getInstance();
      final repository = SharedPreferencesReadingProgressRepository(prefs);

      expect(repository.findMostRecent(), isNull);
    });

    test('records for different series are independent (recording one '
        'series does not affect another\'s stored progress)', () async {
      final prefs = await SharedPreferences.getInstance();
      final repository = SharedPreferencesReadingProgressRepository(prefs);

      await repository.recordEpisodeOpened(
        seriesSlug: 'gece-vardiyasi',
        seriesTitle: 'Gece Vardiyası',
        episodeSlug: 'bolum-1',
        episodeNumber: 1,
      );
      await repository.recordEpisodeOpened(
        seriesSlug: 'yarinki-ses',
        seriesTitle: 'Yarınki Ses',
        episodeSlug: 'bolum-5',
        episodeNumber: 5,
      );

      expect(
        repository.findBySeries('gece-vardiyasi')!.episodeSlug,
        'bolum-1',
      );
      expect(repository.findBySeries('yarinki-ses')!.episodeSlug, 'bolum-5');
    });

    test('a record persists across repository instances sharing the same '
        'underlying SharedPreferences store (device-local durability)', () async {
      final prefs = await SharedPreferences.getInstance();
      final writer = SharedPreferencesReadingProgressRepository(prefs);
      await writer.recordEpisodeOpened(
        seriesSlug: 'gece-vardiyasi',
        seriesTitle: 'Gece Vardiyası',
        episodeSlug: 'bolum-1',
        episodeNumber: 1,
      );

      // Yeni bir repository örneği, aynı `SharedPreferences` deposunu
      // (kalıcı katmanı) okuyarak kurulur — bir sonraki uygulama
      // açılışında `bootstrap()`'ın yapacağı şeyin eşdeğeri.
      final reader = SharedPreferencesReadingProgressRepository(prefs);
      final stored = reader.findBySeries('gece-vardiyasi');

      expect(stored, isNotNull);
      expect(stored!.episodeSlug, 'bolum-1');
    });

    test('a corrupted/unexpected stored value is treated as no records, '
        'not a crash', () async {
      SharedPreferences.setMockInitialValues({
        'panelya.reading_progress.v1': '{not valid json',
      });
      final prefs = await SharedPreferences.getInstance();
      final repository = SharedPreferencesReadingProgressRepository(prefs);

      expect(repository.findBySeries('gece-vardiyasi'), isNull);
      expect(repository.findMostRecent(), isNull);
    });
  });
}
