import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';
import 'package:panelya_mobile/features/progress/data/reading_progress_hydration.dart';
import 'package:panelya_mobile/features/progress/data/shared_preferences_reading_progress_repository.dart';
import 'package:panelya_mobile/features/progress/domain/remote_reading_progress_exceptions.dart';
import 'package:panelya_mobile/features/progress/domain/remote_reading_progress_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _fixturesDir = '../../packages/contracts/fixtures';

Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('$_fixturesDir/$name').readAsStringSync())
        as Map<String, dynamic>;

class _FakeRemote implements RemoteReadingProgressRepository {
  _FakeRemote(this._response);

  final ReadingProgressResponse _response;
  Object? fetchError;
  int fetchCalls = 0;

  @override
  Future<ReadingProgressResponse> fetchProgress() async {
    fetchCalls++;
    if (fetchError != null) throw fetchError!;
    return _response;
  }

  @override
  Future<ReadingProgressMutationResponse> upsertProgress({
    required String seriesSlug,
    required String episodeSlug,
    required int percent,
  }) async => throw UnimplementedError();
}

ReadingProgressResponse _remoteWith({
  required String seriesSlug,
  required String episodeSlug,
  required int episodeNumber,
  required int percent,
}) {
  final base = _fixture('reading-progress-response.v1.json');
  final item =
      jsonDecode(jsonEncode((base['items'] as List).first))
          as Map<String, dynamic>;
  (item['series'] as Map<String, dynamic>)['slug'] = seriesSlug;
  (item['episode'] as Map<String, dynamic>)['slug'] = episodeSlug;
  (item['episode'] as Map<String, dynamic>)['number'] = episodeNumber;
  item['percent'] = percent;
  return ReadingProgressResponse.fromJson({
    'schemaVersion': kSchemaVersion,
    'items': [item],
  });
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('yalniz SUNUCUDA bulunan kayit yerel cache e aynalanir', () async {
    final local = SharedPreferencesReadingProgressRepository(
      prefs,
      userId: 'user-1',
    );
    expect(local.findBySeries('yeni-seri'), isNull);

    await ReadingProgressHydration(
      remote: _FakeRemote(
        _remoteWith(
          seriesSlug: 'yeni-seri',
          episodeSlug: 'bolum-3',
          episodeNumber: 3,
          percent: 40,
        ),
      ),
      local: local,
    ).hydrate();

    final stored = local.findBySeries('yeni-seri');
    expect(stored, isNotNull);
    expect(stored!.episodeSlug, 'bolum-3');
    expect(stored.episodeNumber, 3);
  });

  test('ayni seri hem yerelde hem sunucuda varsa UZAK kayit KAZANIR', () async {
    final local = SharedPreferencesReadingProgressRepository(
      prefs,
      userId: 'user-1',
    );
    // Yerelde eski bir konum var.
    await local.recordEpisodeOpened(
      seriesSlug: 'gece-vardiyasi',
      seriesTitle: 'Gece Vardiyası',
      episodeSlug: 'bolum-1',
      episodeNumber: 1,
    );

    await ReadingProgressHydration(
      remote: _FakeRemote(
        _remoteWith(
          seriesSlug: 'gece-vardiyasi',
          episodeSlug: 'bolum-2',
          episodeNumber: 2,
          percent: 64,
        ),
      ),
      local: local,
    ).hydrate();

    // Istemci `updatedAt` karsilastirmasi YAPMAZ; sunucu kaydi gecer.
    expect(local.findBySeries('gece-vardiyasi')!.episodeSlug, 'bolum-2');
  });

  test('uzak yuzde 100 ise kayit TAMAMLANMIS isaretlenir ve sonraki bolum '
      'UYDURULMAZ', () async {
    final local = SharedPreferencesReadingProgressRepository(
      prefs,
      userId: 'user-1',
    );

    await ReadingProgressHydration(
      remote: _FakeRemote(
        _remoteWith(
          seriesSlug: 'gece-vardiyasi',
          episodeSlug: 'bolum-1',
          episodeNumber: 1,
          percent: 100,
        ),
      ),
      local: local,
    ).hydrate();

    final stored = local.findBySeries('gece-vardiyasi')!;
    expect(stored.completed, isTrue);
    // Kayit TAMAMLANAN bolumde kalir; "sonraki bolum" karari seri
    // ekranindaki yayin sirasina aittir.
    expect(stored.episodeSlug, 'bolum-1');
  });

  test('yalniz YERELDE bulunan kayit hesaba yuklenmez ve SILINMEZ', () async {
    final local = SharedPreferencesReadingProgressRepository(
      prefs,
      userId: 'user-1',
    );
    await local.recordEpisodeOpened(
      seriesSlug: 'yalniz-yerel',
      seriesTitle: 'Yalniz Yerel',
      episodeSlug: 'bolum-1',
      episodeNumber: 1,
    );

    final remote = _FakeRemote(
      _remoteWith(
        seriesSlug: 'baska-seri',
        episodeSlug: 'bolum-1',
        episodeNumber: 1,
        percent: 10,
      ),
    );
    await ReadingProgressHydration(remote: remote, local: local).hydrate();

    // Sunucuya HIC yazilmadi (upsert cagrilsa UnimplementedError firlardi)
    // ve yerel kayit KORUNDU.
    expect(local.findBySeries('yalniz-yerel'), isNotNull);
  });

  test(
    'GET basarisiz olursa hata YUZEYE CIKAR ve mevcut yerel veri SILINMEZ',
    () async {
      final local = SharedPreferencesReadingProgressRepository(
        prefs,
        userId: 'user-1',
      );
      await local.recordEpisodeOpened(
        seriesSlug: 'mevcut',
        seriesTitle: 'Mevcut',
        episodeSlug: 'bolum-1',
        episodeNumber: 1,
      );

      final remote = _FakeRemote(
        _remoteWith(
          seriesSlug: 'x',
          episodeSlug: 'y',
          episodeNumber: 1,
          percent: 1,
        ),
      )..fetchError = const ReadingProgressUnexpectedException('ag hatasi');

      await expectLater(
        ReadingProgressHydration(remote: remote, local: local).hydrate(),
        throwsA(isA<ReadingProgressUnexpectedException>()),
      );
      // Sahte basari yok, yerel veri duruyor.
      expect(local.findBySeries('mevcut'), isNotNull);
    },
  );

  group('namespace ayrimi (ADR-049)', () {
    test('anonim ve kullanici cache leri AYRIDIR', () async {
      final anonymous = SharedPreferencesReadingProgressRepository(prefs);
      final user = SharedPreferencesReadingProgressRepository(
        prefs,
        userId: 'user-1',
      );

      await anonymous.recordEpisodeOpened(
        seriesSlug: 'anon-seri',
        seriesTitle: 'Anonim',
        episodeSlug: 'bolum-1',
        episodeNumber: 1,
      );

      // Kullanici namespace inde GORUNMEZ.
      expect(user.findBySeries('anon-seri'), isNull);
      expect(anonymous.findBySeries('anon-seri'), isNotNull);
    });

    test(
      'BASKA hesaba gecince onceki kullanicinin ilerlemesi GORUNMEZ',
      () async {
        final userA = SharedPreferencesReadingProgressRepository(
          prefs,
          userId: 'user-a',
        );
        final userB = SharedPreferencesReadingProgressRepository(
          prefs,
          userId: 'user-b',
        );

        await userA.recordEpisodeOpened(
          seriesSlug: 'gizli-seri',
          seriesTitle: 'Gizli',
          episodeSlug: 'bolum-1',
          episodeNumber: 1,
        );

        expect(userB.findBySeries('gizli-seri'), isNull);
        expect(userB.findMostRecent(), isNull);
        // A nin verisi kendi namespace inde duruyor.
        expect(userA.findBySeries('gizli-seri'), isNotNull);
      },
    );
  });
}
