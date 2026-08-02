import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';
import 'package:panelya_mobile/features/progress/data/reading_progress_sync.dart';
import 'package:panelya_mobile/features/progress/domain/remote_reading_progress_exceptions.dart';
import 'package:panelya_mobile/features/progress/domain/remote_reading_progress_repository.dart';

ReadingProgressMutationResponse _mutationFixture() =>
    ReadingProgressMutationResponse.fromJson(
      jsonDecode(
            File(
              '../../packages/contracts/fixtures/'
              'reading-progress-mutation-response.v1.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>,
    );

class _RecordingRemote implements RemoteReadingProgressRepository {
  final List<int> writtenPercents = [];
  final List<String> writtenEpisodes = [];
  Object? upsertError;

  @override
  Future<ReadingProgressResponse> fetchProgress() async =>
      const ReadingProgressResponse(schemaVersion: kSchemaVersion, items: []);

  @override
  Future<ReadingProgressMutationResponse> upsertProgress({
    required String seriesSlug,
    required String episodeSlug,
    required int percent,
  }) async {
    writtenPercents.add(percent);
    writtenEpisodes.add(episodeSlug);
    if (upsertError != null) throw upsertError!;
    return _mutationFixture();
  }
}

void main() {
  group('ReadingProgressSync — istek sınırlama', () {
    test('scroll sırasında her bildirim istek ÜRETMEZ (debounce)', () async {
      final remote = _RecordingRemote();
      final sync = ReadingProgressSync(
        remote: remote,
        debounce: const Duration(milliseconds: 40),
        minPercentDelta: 5,
      );
      addTearDown(sync.dispose);

      // Hızlı ardışık bildirimler.
      for (final p in [10, 20, 30, 40]) {
        sync.report(seriesSlug: 'seri', episodeSlug: 'bolum-1', percent: p);
      }
      expect(remote.writtenPercents, isEmpty, reason: 'henüz gönderilmemeli');

      await Future<void>.delayed(const Duration(milliseconds: 80));

      // Yalnız SON değer tek bir istekle gitti.
      expect(remote.writtenPercents, [40]);
    });

    test('anlamsız küçük değişiklikler eşiğe takılır', () async {
      final remote = _RecordingRemote();
      final sync = ReadingProgressSync(
        remote: remote,
        debounce: const Duration(milliseconds: 20),
        minPercentDelta: 10,
      );
      addTearDown(sync.dispose);

      sync.report(seriesSlug: 'seri', episodeSlug: 'bolum-1', percent: 30);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(remote.writtenPercents, [30]);

      // Eşiğin altında: gönderilmez.
      sync.report(seriesSlug: 'seri', episodeSlug: 'bolum-1', percent: 34);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(remote.writtenPercents, [30]);

      // Eşiği geçti: gönderilir.
      sync.report(seriesSlug: 'seri', episodeSlug: 'bolum-1', percent: 45);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(remote.writtenPercents, [30, 45]);
    });

    test('percent 100 KESİN yazılır: eşiği ve debounce\'ı atlar', () async {
      final remote = _RecordingRemote();
      final sync = ReadingProgressSync(
        remote: remote,
        debounce: const Duration(seconds: 30),
        minPercentDelta: 50,
      );
      addTearDown(sync.dispose);

      sync.report(seriesSlug: 'seri', episodeSlug: 'bolum-1', percent: 100);
      // Zamanlayıcı beklenmeden gönderildi.
      await Future<void>.delayed(Duration.zero);

      expect(remote.writtenPercents, [100]);
    });

    test('sonraki bölüm sunucuya otomatik olarak 0 diye YAZILMAZ', () async {
      final remote = _RecordingRemote();
      final sync = ReadingProgressSync(
        remote: remote,
        debounce: const Duration(milliseconds: 20),
      );
      addTearDown(sync.dispose);

      sync.report(seriesSlug: 'seri', episodeSlug: 'bolum-1', percent: 100);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // YALNIZ tamamlanan bölüm yazıldı; `bolum-2` için 0 gönderilmedi.
      expect(remote.writtenEpisodes, ['bolum-1']);
      expect(remote.writtenPercents, [100]);
    });
  });

  group('ReadingProgressSync — güvenli kapanış', () {
    test('flush bekleyen yazımı HEMEN gönderir (atmaz)', () async {
      final remote = _RecordingRemote();
      final sync = ReadingProgressSync(
        remote: remote,
        debounce: const Duration(seconds: 30),
      );
      addTearDown(sync.dispose);

      sync.report(seriesSlug: 'seri', episodeSlug: 'bolum-1', percent: 42);
      expect(sync.hasPendingWrite, isTrue);
      expect(remote.writtenPercents, isEmpty);

      await sync.flush();

      expect(remote.writtenPercents, [42]);
      expect(sync.hasPendingWrite, isFalse);
    });

    test('bekleyen yazım yokken flush istek üretmez', () async {
      final remote = _RecordingRemote();
      final sync = ReadingProgressSync(remote: remote);
      addTearDown(sync.dispose);

      await sync.flush();

      expect(remote.writtenPercents, isEmpty);
    });

    test('dispose sonrası bekleyen zamanlayıcı istek göndermez', () async {
      final remote = _RecordingRemote();
      final sync = ReadingProgressSync(
        remote: remote,
        debounce: const Duration(milliseconds: 20),
      );

      sync.report(seriesSlug: 'seri', episodeSlug: 'bolum-1', percent: 42);
      sync.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(remote.writtenPercents, isEmpty);
    });
  });

  group('ReadingProgressSync — dürüstlük', () {
    test(
      'uzak yazım başarısızsa okuma ENGELLENMEZ ama başarılı da SAYILMAZ',
      () async {
        final remote = _RecordingRemote()
          ..upsertError = const ReadingProgressUnexpectedException(
            'Sunucuya bağlanılamadı.',
          );
        final sync = ReadingProgressSync(
          remote: remote,
          debounce: const Duration(milliseconds: 10),
        );
        addTearDown(sync.dispose);

        sync.report(seriesSlug: 'seri', episodeSlug: 'bolum-1', percent: 50);
        await Future<void>.delayed(const Duration(milliseconds: 40));

        // Fırlatmadı (okuma akışı kesilmedi) ama durum dürüstçe işaretlendi.
        expect(sync.lastSyncFailed, isTrue);
      },
    );

    test('ANONİM kullanıcıda sunucu çağrısı sessizce geçilir ve BAŞARISIZ '
        'olarak işaretlenmez', () async {
      final remote = _RecordingRemote()
        ..upsertError = const ReadingProgressNotAuthenticatedException();
      final sync = ReadingProgressSync(
        remote: remote,
        debounce: const Duration(milliseconds: 10),
      );
      addTearDown(sync.dispose);

      sync.report(seriesSlug: 'seri', episodeSlug: 'bolum-1', percent: 50);
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(sync.lastSyncFailed, isFalse);
    });

    test(
      'BAŞARILI uzak yazımdan sonra yerel cache aynalaması tetiklenir',
      () async {
        final mirrored = <String>[];
        final remote = _SuccessfulRemote();
        final sync = ReadingProgressSync(
          remote: remote,
          debounce: const Duration(milliseconds: 10),
          onRemoteSuccess: (series, episode, percent) async {
            mirrored.add('$series/$episode:$percent');
          },
        );
        addTearDown(sync.dispose);

        sync.report(seriesSlug: 'seri', episodeSlug: 'bolum-1', percent: 50);
        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(mirrored, ['seri/bolum-1:50']);
        expect(sync.lastSyncFailed, isFalse);
      },
    );

    test('BAŞARISIZ uzak yazımda yerel aynalama YAPILMAZ', () async {
      final mirrored = <String>[];
      final remote = _RecordingRemote()
        ..upsertError = const ReadingProgressUnexpectedException('hata');
      final sync = ReadingProgressSync(
        remote: remote,
        debounce: const Duration(milliseconds: 10),
        onRemoteSuccess: (series, episode, percent) async {
          mirrored.add('$series/$episode:$percent');
        },
      );
      addTearDown(sync.dispose);

      sync.report(seriesSlug: 'seri', episodeSlug: 'bolum-1', percent: 50);
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(mirrored, isEmpty);
    });
  });
}

class _SuccessfulRemote implements RemoteReadingProgressRepository {
  @override
  Future<ReadingProgressResponse> fetchProgress() async =>
      const ReadingProgressResponse(schemaVersion: kSchemaVersion, items: []);

  @override
  Future<ReadingProgressMutationResponse> upsertProgress({
    required String seriesSlug,
    required String episodeSlug,
    required int percent,
  }) async => _mutationFixture();
}
