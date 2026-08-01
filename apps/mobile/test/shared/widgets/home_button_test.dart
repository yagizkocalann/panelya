import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:panelya_mobile/app/theme/theme.dart';
import 'package:panelya_mobile/shared/widgets/home_button.dart';

/// [HomeButton] birim testleri (bkz. PLAN Görev 3 — kullanıcı şikayeti:
/// "bir seriye veya bölüme girdiğimizde geri dönemiyoruz, anasayfaya direk
/// dönecek bir şey yok"). Her ekranın kendi test dosyasında da bu butonun
/// AppBar'da göründüğü ayrıca doğrulanır (bkz. `series_screen_test.dart`,
/// `catalog_screen_test.dart`, `new_series_screen_test.dart`,
/// `new_episodes_screen_test.dart`, `reader_screen_test.dart`); burada
/// widget'ın kendi davranışı (navigasyon + erişilebilirlik + dokunma
/// hedefi) tek bir yerde, tekrar etmeden doğrulanır.
void main() {
  Widget wrap({String initialLocation = '/somewhere'}) {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('HOME')),
        ),
        GoRoute(
          path: '/somewhere',
          builder: (context, state) => Scaffold(
            appBar: AppBar(
              title: const Text('Bir ekran'),
              actions: const [HomeButton()],
            ),
            body: const SizedBox.shrink(),
          ),
        ),
      ],
    );

    return MaterialApp.router(theme: buildAppTheme(), routerConfig: router);
  }

  testWidgets('tapping the home button navigates to "/"', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Bir ekran'), findsOneWidget);
    expect(find.text('HOME'), findsNothing);

    await tester.tap(find.byTooltip('Ana sayfa'));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets(
    'meets the 44x44 minimum touch target and exposes an accessible label',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      final homeButton = find.byTooltip('Ana sayfa');
      expect(homeButton, findsOneWidget);
      expect(tester.getSize(homeButton).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(homeButton).height, greaterThanOrEqualTo(44));

      // `IconButton` + `Tooltip`, ek bir `Semantics` sarmalayıcı olmadan
      // kendi `button: true` semantics düğümünü üretir; erişilebilir etiket
      // `tooltip` alanında taşınır (bkz. `home_button.dart` doc yorumu —
      // mevcut `_SeriesReturnButton` ile aynı desen).
      final semantics = tester.getSemantics(homeButton);
      expect(semantics.flagsCollection.isButton, isTrue);
      expect(semantics.tooltip, 'Ana sayfa');

      semanticsHandle.dispose();
    },
  );
}
