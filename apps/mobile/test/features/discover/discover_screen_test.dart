import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelya_mobile/app/theme/theme.dart';
import 'package:panelya_mobile/core/api/api_exception.dart';
import 'package:panelya_mobile/core/contracts/catalog_response.dart';
import 'package:panelya_mobile/core/contracts/episode_contract.dart';
import 'package:panelya_mobile/core/contracts/series_contract.dart';
import 'package:panelya_mobile/core/contracts/story_panel.dart';
import 'package:panelya_mobile/features/discover/domain/discover_repository.dart';
import 'package:panelya_mobile/features/discover/presentation/discover_providers.dart';
import 'package:panelya_mobile/features/discover/presentation/discover_screen.dart';

class _FakeDiscoverRepository implements DiscoverRepository {
  _FakeDiscoverRepository(this._result);

  final Future<CatalogResponse> Function() _result;

  @override
  Future<CatalogResponse> fetchCatalog() => _result();
}

CatalogResponse _catalogWith(List<SeriesSummaryContract> series) {
  return CatalogResponse(
    schemaVersion: '1.0',
    featuredSlug: series.isEmpty ? null : series.first.metadata.slug,
    series: series,
  );
}

SeriesSummaryContract _series(String slug, String title) {
  return SeriesSummaryContract(
    metadata: SeriesMetadataContract(
      slug: slug,
      title: title,
      eyebrow: 'Eyebrow',
      creator: 'Panelya Originals',
      description: 'Description',
      longDescription: 'Long description',
      status: 'Devam Ediyor',
      genres: const ['Gizem'],
      tone: 'mint',
      updatedAt: 'Bugün',
      rating: 4.5,
      followers: '1 B',
    ),
    episodeCount: 1,
    latestEpisode: const EpisodeContract(
      slug: 'bolum-1',
      number: 1,
      title: 'Bölüm 1',
      publishedAt: '18 Temmuz 2026',
      readTime: '5 dk',
      panels: [
        StoryPanel(id: 'panel-1', scene: 'Sahne', tone: PanelTone.mint),
      ],
    ),
  );
}

Widget _wrap(DiscoverRepository repository) {
  return ProviderScope(
    overrides: [discoverRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      theme: buildAppTheme(),
      home: const DiscoverScreen(),
    ),
  );
}

void main() {
  testWidgets('shows a loading indicator while the catalog loads', (
    tester,
  ) async {
    final repository = _FakeDiscoverRepository(
      () => Future<CatalogResponse>.delayed(
        const Duration(seconds: 1),
        () => _catalogWith(const []),
      ),
    );

    await tester.pumpWidget(_wrap(repository));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // The fake repository's `Future.delayed` timer must resolve before the
    // test ends, otherwise flutter_test's teardown asserts on a pending timer.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('renders series cards once the catalog resolves', (
    tester,
  ) async {
    final repository = _FakeDiscoverRepository(
      () async => _catalogWith([
        _series('gece-vardiyasi', 'Gece Vardiyası'),
        _series('yarinki-ses', 'Yarınki Ses'),
      ]),
    );

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(find.text('Gece Vardiyası'), findsOneWidget);
    expect(find.text('Yarınki Ses'), findsOneWidget);
  });

  testWidgets('shows the empty state when the catalog has no series', (
    tester,
  ) async {
    final repository = _FakeDiscoverRepository(
      () async => _catalogWith(const []),
    );

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(find.text('Henüz yayınlanmış bir seri yok.'), findsOneWidget);
  });

  testWidgets('shows an error view with a working retry button', (
    tester,
  ) async {
    var attempt = 0;
    final repository = _FakeDiscoverRepository(() async {
      attempt += 1;
      if (attempt == 1) {
        throw const NetworkException('bağlantı yok');
      }
      return _catalogWith([_series('gece-vardiyasi', 'Gece Vardiyası')]);
    });

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(find.text('Gece Vardiyası'), findsNothing);

    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();

    expect(find.text('Gece Vardiyası'), findsOneWidget);
  });
}
