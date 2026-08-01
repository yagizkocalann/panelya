import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:panelya_mobile/app/theme/theme.dart';
import 'package:panelya_mobile/core/config/auth_feature_config.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';
import 'package:panelya_mobile/features/auth/domain/auth_repository.dart';
import 'package:panelya_mobile/features/auth/domain/auth_session_state.dart';
import 'package:panelya_mobile/features/auth/presentation/auth_providers.dart';
import 'package:panelya_mobile/features/library/domain/library_exceptions.dart';
import 'package:panelya_mobile/features/library/domain/library_repository.dart';
import 'package:panelya_mobile/features/library/presentation/library_providers.dart';
import 'package:panelya_mobile/features/library/presentation/library_screen.dart';
import 'package:panelya_mobile/shared/widgets/series_card.dart';
import 'package:panelya_mobile/shared/widgets/state_views.dart';

import '../../../support/viewports.dart';

const _fixturesDir = '../../packages/contracts/fixtures';

Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('$_fixturesDir/$name').readAsStringSync())
        as Map<String, dynamic>;

const _user = AuthUser(
  id: 'user-1',
  displayName: 'Ece Yılmaz',
  email: 'ece@example.invalid',
  emailVerified: true,
  role: 'reader',
);

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.anonymous = false});

  final bool anonymous;

  @override
  AuthSessionState get currentState => anonymous
      ? const AuthSessionState.anonymous()
      : const AuthSessionState.authenticated(_user);

  @override
  Stream<AuthSessionState> get stateChanges => Stream.value(currentState);

  @override
  Future<AuthorizationRequest> beginSignIn() => throw UnimplementedError();

  @override
  Future<void> completeSignIn(Uri callbackUri) => throw UnimplementedError();

  @override
  Future<void> refresh() => throw UnimplementedError();

  @override
  Future<void> logout() => throw UnimplementedError();

  @override
  void dispose() {}
}

class _FakeLibraryRepository implements LibraryRepository {
  _FakeLibraryRepository({LibraryResponse? response})
    : _response = response ?? _defaultResponse();

  static LibraryResponse _defaultResponse() =>
      LibraryResponse.fromJson(_fixture('library-response.v1.json'));

  final LibraryResponse _response;
  Object? fetchError;
  Object? upsertError;
  Object? removeError;
  bool removedResult = true;

  final List<String> calls = [];
  LibraryStatus? lastStatus;
  bool? lastFavorite;

  @override
  Future<LibraryResponse> fetchLibrary() async {
    calls.add('fetch');
    if (fetchError != null) throw fetchError!;
    return _response;
  }

  @override
  Future<LibraryMutationResponse> upsertEntry({
    required String slug,
    required LibraryStatus status,
    required bool favorite,
  }) async {
    calls.add('upsert:$slug');
    lastStatus = status;
    lastFavorite = favorite;
    if (upsertError != null) throw upsertError!;
    return LibraryMutationResponse.fromJson(
      _fixture('library-mutation-response.v1.json'),
    );
  }

  @override
  Future<LibraryRemovalResponse> removeEntry(String slug) async {
    calls.add('remove:$slug');
    if (removeError != null) throw removeError!;
    return LibraryRemovalResponse(
      schemaVersion: kSchemaVersion,
      removed: removedResult,
    );
  }
}

class _NeverResolvingLibraryRepository implements LibraryRepository {
  @override
  Future<LibraryResponse> fetchLibrary() => Completer<LibraryResponse>().future;

  @override
  Future<LibraryMutationResponse> upsertEntry({
    required String slug,
    required LibraryStatus status,
    required bool favorite,
  }) => Completer<LibraryMutationResponse>().future;

  @override
  Future<LibraryRemovalResponse> removeEntry(String slug) =>
      Completer<LibraryRemovalResponse>().future;
}

Widget _wrap({required LibraryRepository repository, bool anonymous = false}) {
  final router = GoRouter(
    initialLocation: '/library',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: '/library',
        builder: (context, state) => const LibraryScreen(),
      ),
      GoRoute(
        path: '/account',
        builder: (context, state) =>
            const Scaffold(body: Text('ACCOUNT_SCREEN')),
      ),
      GoRoute(
        path: '/series/:slug',
        builder: (context, state) =>
            Scaffold(body: Text('SERIES:${state.pathParameters['slug']}')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      // `authSessionProvider` önce bu bayrağı okur; kapalıyken oturumu
      // ANONİM sayar (bkz. `auth_providers.dart`).
      authFeatureConfigProvider.overrideWithValue(
        const AuthFeatureConfig(enabled: true),
      ),
      authRepositoryProvider.overrideWithValue(
        _FakeAuthRepository(anonymous: anonymous),
      ),
      libraryRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
  );
}

void main() {
  testWidgets('yüklenirken AppLoadingView gösterir', (tester) async {
    await tester.pumpWidget(
      _wrap(repository: _NeverResolvingLibraryRepository()),
    );
    await tester.pump();

    expect(find.byType(AppLoadingView), findsOneWidget);
  });

  testWidgets('boş kütüphanede boş durum mesajı gösterilir', (tester) async {
    final repository = _FakeLibraryRepository(
      response: const LibraryResponse(schemaVersion: kSchemaVersion, items: []),
    );

    await tester.pumpWidget(_wrap(repository: repository));
    await tester.pumpAndSettle();

    expect(find.byType(AppEmptyView), findsOneWidget);
    expect(find.text('Kütüphanende henüz seri yok.'), findsOneWidget);
  });

  testWidgets(
    'hata durumunda sunucunun KENDİ açıklaması gösterilir + Tekrar dene',
    (tester) async {
      final repository = _FakeLibraryRepository()
        ..fetchError = LibraryServerException(
          LibraryErrorResponse.fromJson(_fixture('library-error.v1.json')),
        );

      await tester.pumpWidget(_wrap(repository: repository));
      await tester.pumpAndSettle();

      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.text('Bu işlem için giriş yapmalısın.'), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
    },
  );

  testWidgets('ANONİM kullanıcıya sahte kütüphane GÖSTERİLMEZ; giriş akışına '
      'yönlendirilir (ADR-010)', (tester) async {
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(_wrap(repository: repository, anonymous: true));
    await tester.pumpAndSettle();

    // Kütüphane HİÇ istenmedi.
    expect(repository.calls, isEmpty);
    expect(find.byType(SeriesCard), findsNothing);
    expect(find.text('Kütüphaneni görmek için giriş yap.'), findsOneWidget);

    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    // Gerçek Auth0 akışını taşıyan ekrana gider.
    expect(find.text('ACCOUNT_SCREEN'), findsOneWidget);
  });

  testWidgets('kütüphane kartı mevcut SeriesCard ile render edilir', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(repository: _FakeLibraryRepository()));
    await tester.pumpAndSettle();

    expect(find.byType(SeriesCard), findsOneWidget);
    expect(find.text('Okuyorum'), findsOneWidget);
  });

  testWidgets(
    'sunucunun verdiği SIRA korunur — istemci yeniden sıralama üretmez',
    (tester) async {
      // Lazy `ListView`: varsayilan 800x600 viewport'ta yalniz ilk kart
      // insa edilirdi. Iki kartin da agacta olmasi icin uzun bir viewport
      // kullanilir (bkz. `test/support/viewports.dart`).
      useViewport(tester, const Size(390, 2400));
      final base = _fixture('library-response.v1.json');
      final item = (base['items'] as List).first as Map<String, dynamic>;

      Map<String, dynamic> withTitle(String title, String updatedAt) {
        final copy = jsonDecode(jsonEncode(item)) as Map<String, dynamic>;
        (copy['series'] as Map<String, dynamic>)['title'] = title;
        (copy['series'] as Map<String, dynamic>)['slug'] = title.toLowerCase();
        copy['updatedAt'] = updatedAt;
        return copy;
      }

      final repository = _FakeLibraryRepository(
        response: LibraryResponse.fromJson({
          'schemaVersion': kSchemaVersion,
          'items': [
            withTitle('Eski', '2020-01-01T00:00:00.000Z'),
            withTitle('Yeni', '2030-01-01T00:00:00.000Z'),
          ],
        }),
      );

      await tester.pumpWidget(_wrap(repository: repository));
      await tester.pumpAndSettle();

      final cards = tester.widgetList<SeriesCard>(find.byType(SeriesCard));
      expect(
        cards.map((c) => c.series.title).toList(),
        ['Eski', 'Yeni'],
        reason: 'sunucu sırası korunmalı',
      );
    },
  );

  testWidgets(
    'okuma durumu değiştirmek hedef durumun TAMAMINI gönderir (toggle değil)',
    (tester) async {
      final repository = _FakeLibraryRepository();

      await tester.pumpWidget(_wrap(repository: repository));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Okuyorum'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Okuyorum'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bitirdim').last);
      await tester.pumpAndSettle();

      expect(repository.calls, contains('upsert:gece-vardiyasi'));
      expect(repository.lastStatus, LibraryStatus.completed);
      // Favori DEĞİŞMEDİ ama yine de gövdede mevcut değeriyle gönderildi.
      expect(repository.lastFavorite, isTrue);
    },
  );

  testWidgets('favori aksiyonu mevcut durumu koruyarak favoriyi değiştirir', (
    tester,
  ) async {
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(_wrap(repository: repository));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byTooltip('Favorilerden çıkar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Favorilerden çıkar'));
    await tester.pumpAndSettle();

    expect(repository.lastFavorite, isFalse);
    // Okuma durumu korunur.
    expect(repository.lastStatus, LibraryStatus.reading);
  });

  testWidgets('kütüphaneden çıkarma onay ister; vazgeçilirse çağrılmaz', (
    tester,
  ) async {
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(_wrap(repository: repository));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Kütüphaneden çıkar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kütüphaneden çıkar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();

    expect(repository.calls.any((c) => c.startsWith('remove:')), isFalse);
  });

  testWidgets(
    'çıkarma IDEMPOTENTTIR: `removed: false` hata olarak GÖSTERİLMEZ',
    (tester) async {
      final repository = _FakeLibraryRepository()..removedResult = false;

      await tester.pumpWidget(_wrap(repository: repository));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Kütüphaneden çıkar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kütüphaneden çıkar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Çıkar'));
      await tester.pumpAndSettle();

      expect(repository.calls, contains('remove:gece-vardiyasi'));
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets('mutation başarısız olursa sebep SnackBar ile gösterilir', (
    tester,
  ) async {
    final repository = _FakeLibraryRepository()
      ..upsertError = const LibraryUnexpectedException(
        'Sunucuya bağlanılamadı.',
      );

    await tester.pumpWidget(_wrap(repository: repository));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byTooltip('Favorilerden çıkar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Favorilerden çıkar'));
    await tester.pumpAndSettle();

    expect(find.text('Sunucuya bağlanılamadı.'), findsOneWidget);
  });

  testWidgets('karta dokunmak seri detayına gider', (tester) async {
    useViewport(tester, phonePortrait);
    await tester.pumpWidget(_wrap(repository: _FakeLibraryRepository()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(SeriesCard));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SeriesCard));
    await tester.pumpAndSettle();

    expect(find.text('SERIES:gece-vardiyasi'), findsOneWidget);
  });
}
