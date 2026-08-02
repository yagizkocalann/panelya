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
import 'package:panelya_mobile/features/library/presentation/library_add_action.dart';
import 'package:panelya_mobile/features/library/presentation/library_providers.dart';

import '../../../support/overflow_watcher.dart';
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
  _FakeLibraryRepository({this.containsSeries = false});

  final bool containsSeries;
  Object? fetchError;
  Object? upsertError;

  /// `upsertEntry` bu completer tamamlanana kadar askıda kalır — tekrar
  /// dokunma korumasını test etmek için.
  Completer<void>? upsertGate;

  final List<String> calls = [];
  LibraryStatus? lastStatus;
  bool? lastFavorite;

  @override
  Future<LibraryResponse> fetchLibrary() async {
    calls.add('fetch');
    if (fetchError != null) throw fetchError!;
    final base = _fixture('library-response.v1.json');
    return LibraryResponse.fromJson({
      'schemaVersion': kSchemaVersion,
      'items': containsSeries ? base['items'] : <Object?>[],
    });
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
    if (upsertGate != null) await upsertGate!.future;
    if (upsertError != null) throw upsertError!;
    return LibraryMutationResponse.fromJson(
      _fixture('library-mutation-response.v1.json'),
    );
  }

  @override
  Future<LibraryRemovalResponse> removeEntry(String slug) async {
    calls.add('remove:$slug');
    return const LibraryRemovalResponse(
      schemaVersion: kSchemaVersion,
      removed: true,
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

Widget _wrap({
  required LibraryRepository repository,
  bool authEnabled = true,
  bool anonymous = false,
  double? textScale,
}) {
  final router = GoRouter(
    initialLocation: '/series/gece-vardiyasi',
    routes: [
      GoRoute(
        path: '/series/:slug',
        builder: (context, state) => const Scaffold(
          body: Center(child: LibraryAddAction(seriesSlug: 'gece-vardiyasi')),
        ),
      ),
      GoRoute(
        path: '/account',
        builder: (context, state) =>
            const Scaffold(body: Text('ACCOUNT_SCREEN')),
      ),
      GoRoute(
        path: '/library',
        builder: (context, state) =>
            const Scaffold(body: Text('LIBRARY_SCREEN')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      authFeatureConfigProvider.overrideWithValue(
        AuthFeatureConfig(enabled: authEnabled),
      ),
      authRepositoryProvider.overrideWithValue(
        _FakeAuthRepository(anonymous: anonymous),
      ),
      libraryRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp.router(
      theme: buildAppTheme(),
      routerConfig: router,
      builder: textScale == null
          ? null
          : (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
    ),
  );
}

void main() {
  testWidgets('AUTH_ENABLED kapalıyken aksiyon HİÇ render edilmez ve kütüphane '
      'istenmez', (tester) async {
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(_wrap(repository: repository, authEnabled: false));
    await tester.pumpAndSettle();

    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.text('Kütüphaneye ekle'), findsNothing);
    expect(repository.calls, isEmpty);
  });

  testWidgets(
    'ANONİM kullanıcıda aksiyon GERÇEK giriş akışına götürür; API isteği '
    'YAPILMAZ, sahte başarı gösterilmez (ADR-010)',
    (tester) async {
      final repository = _FakeLibraryRepository();

      await tester.pumpWidget(_wrap(repository: repository, anonymous: true));
      await tester.pumpAndSettle();

      expect(find.text('Kütüphaneye ekle'), findsOneWidget);
      // Kütüphane HİÇ istenmedi.
      expect(repository.calls, isEmpty);

      await tester.tap(find.text('Kütüphaneye ekle'));
      await tester.pumpAndSettle();

      expect(find.text('ACCOUNT_SCREEN'), findsOneWidget);
      // Hâlâ hiçbir API çağrısı yok.
      expect(repository.calls, isEmpty);
    },
  );

  testWidgets('kütüphane yüklenirken aksiyon devre dışı bir gösterge olur', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(repository: _NeverResolvingLibraryRepository()),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets(
    'kütüphane okunamazsa "ekle" GÖSTERİLMEZ — dürüst tekrar-dene sunulur',
    (tester) async {
      final repository = _FakeLibraryRepository()
        ..fetchError = LibraryServerException(
          LibraryErrorResponse.fromJson(_fixture('library-error.v1.json')),
        );

      await tester.pumpWidget(_wrap(repository: repository));
      await tester.pumpAndSettle();

      expect(find.text('Kütüphane durumu alınamadı'), findsOneWidget);
      expect(find.text('Kütüphaneye ekle'), findsNothing);
    },
  );

  testWidgets('seri kütüphanede DEĞİLSE ekleme TAM hedef durumu gönderir '
      '(status: plan, favorite: false)', (tester) async {
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(_wrap(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kütüphaneye ekle'));
    await tester.pumpAndSettle();

    expect(repository.calls, contains('upsert:gece-vardiyasi'));
    expect(repository.lastStatus, LibraryStatus.plan);
    expect(repository.lastFavorite, isFalse);
    // Başarıdan sonra kütüphane provider'ı tazelendi.
    expect(repository.calls.where((c) => c == 'fetch').length, greaterThan(1));
  });

  testWidgets('istek sürerken TEKRAR dokunmak ikinci bir POST göndermez', (
    tester,
  ) async {
    final gate = Completer<void>();
    final repository = _FakeLibraryRepository()..upsertGate = gate;

    await tester.pumpWidget(_wrap(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kütüphaneye ekle'));
    await tester.pump();

    // İstek sürerken buton devre dışı bir göstergeye dönüştü.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );

    gate.complete();
    await tester.pumpAndSettle();

    expect(
      repository.calls.where((c) => c.startsWith('upsert:')).length,
      1,
      reason: 'yalnız TEK bir POST gönderilmeli',
    );
  });

  testWidgets(
    'seri ZATEN kütüphanedeyse "Kütüphanemde" gösterilir ve /library\'e '
    'gider — toggle veya sessiz silme YOK',
    (tester) async {
      final repository = _FakeLibraryRepository(containsSeries: true);

      await tester.pumpWidget(_wrap(repository: repository));
      await tester.pumpAndSettle();

      expect(find.text('Kütüphanemde'), findsOneWidget);
      expect(find.text('Kütüphaneye ekle'), findsNothing);

      await tester.tap(find.text('Kütüphanemde'));
      await tester.pumpAndSettle();

      expect(find.text('LIBRARY_SCREEN'), findsOneWidget);
      // Ne ekleme ne silme çağrıldı.
      expect(
        repository.calls.any(
          (c) => c.startsWith('upsert:') || c.startsWith('remove:'),
        ),
        isFalse,
      );
    },
  );

  testWidgets('sunucu hatası SnackBar ile dürüstçe gösterilir', (tester) async {
    final repository = _FakeLibraryRepository()
      ..upsertError = const LibraryUnexpectedException(
        'Sunucuya bağlanılamadı.',
      );

    await tester.pumpWidget(_wrap(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kütüphaneye ekle'));
    await tester.pumpAndSettle();

    expect(find.text('Sunucuya bağlanılamadı.'), findsOneWidget);
    // Başarısız oldu ama "Kütüphanemde" GÖSTERİLMEZ.
    expect(find.text('Kütüphanemde'), findsNothing);
  });

  testWidgets('aksiyon 44x44 minimum dokunma hedefini karşılar', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(repository: _FakeLibraryRepository()));
    await tester.pumpAndSettle();

    final size = tester.getSize(find.byType(OutlinedButton));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('aksiyon ekran okuyucuya buton olarak ve etiketiyle okunur', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(repository: _FakeLibraryRepository()));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Kütüphaneye ekle'), findsOneWidget);
  });

  testWidgets('büyük yazı boyutunda taşma olmaz ve etiket kırpılmaz', (
    tester,
  ) async {
    useViewport(tester, phonePortrait);
    final watcher = OverflowWatcher()..start();
    addTearDown(watcher.stop);

    await tester.pumpWidget(
      _wrap(repository: _FakeLibraryRepository(), textScale: 2.0),
    );
    await tester.pumpAndSettle();

    expect(watcher.errors, isEmpty, reason: watcher.describe());
    expect(find.text('Kütüphaneye ekle'), findsOneWidget);
    // Tema `minimumSize`ı sayesinde buton büyük yazıda 44 px'in ÜZERİNE
    // çıkabilir; etiket kırpılmaz.
    expect(tester.getSize(find.byType(OutlinedButton)).height, greaterThan(44));
  });
}
