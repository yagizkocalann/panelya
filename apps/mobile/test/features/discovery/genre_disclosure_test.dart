import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:panelya_mobile/app/router/route_args.dart';
import 'package:panelya_mobile/app/theme/theme.dart';
import 'package:panelya_mobile/features/discovery/presentation/genre_disclosure.dart';

const _toggleKey = ValueKey('genre-disclosure-toggle');

Finder _chip(String genre) => find.byKey(ValueKey('genre-disclosure-chip-$genre'));

/// Gerçek bir `go_router` kurar: `/` `GenreDisclosure`'ı gösterir, `/catalog`
/// ise yalnız aldığı `CatalogRouteArgs.initialGenre`'ı metin olarak gösteren
/// bir işaretçi ekrandır (bkz. `catalog_screen_test.dart`'taki aynı desen —
/// gerçek `CatalogScreen` yerine hedefi doğrulayan bir sahte).
Widget _wrap(List<String> genres) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            Scaffold(body: GenreDisclosure(genres: genres)),
      ),
      GoRoute(
        path: '/catalog',
        builder: (context, state) {
          final extra = state.extra;
          final initialGenre = extra is CatalogRouteArgs
              ? extra.initialGenre
              : null;
          return Scaffold(
            body: Text('CATALOG:${initialGenre ?? 'none'}'),
          );
        },
      ),
    ],
  );

  return MaterialApp.router(theme: buildAppTheme(), routerConfig: router);
}

void main() {
  testWidgets('renders nothing when the genre list is empty (ADR-010)', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const []));
    await tester.pumpAndSettle();

    expect(find.byKey(_toggleKey), findsNothing);
    expect(find.text('Türler'), findsNothing);
  });

  testWidgets(
    'starts closed: shows the down arrow and hides the genre chips',
    (tester) async {
      await tester.pumpWidget(_wrap(const ['Gizem', 'Romantizm']));
      await tester.pumpAndSettle();

      expect(find.text('Türler'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_up), findsNothing);
      expect(_chip('Gizem'), findsNothing);
      expect(_chip('Romantizm'), findsNothing);
    },
  );

  testWidgets(
    'tapping the toggle opens it: arrow flips up and genre chips appear',
    (tester) async {
      await tester.pumpWidget(_wrap(const ['Gizem', 'Romantizm']));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_toggleKey));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
      expect(_chip('Gizem'), findsOneWidget);
      expect(_chip('Romantizm'), findsOneWidget);
    },
  );

  testWidgets('tapping the toggle again closes it back down', (tester) async {
    await tester.pumpWidget(_wrap(const ['Gizem']));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_toggleKey));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);

    await tester.tap(find.byKey(_toggleKey));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    expect(_chip('Gizem'), findsNothing);
  });

  testWidgets(
    'selecting a genre navigates to /catalog with that genre pre-selected '
    '(CatalogRouteArgs.initialGenre)',
    (tester) async {
      await tester.pumpWidget(_wrap(const ['Gizem', 'Romantizm']));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_toggleKey));
      await tester.pumpAndSettle();

      await tester.tap(_chip('Romantizm'));
      await tester.pumpAndSettle();

      expect(find.text('CATALOG:Romantizm'), findsOneWidget);
    },
  );
}
