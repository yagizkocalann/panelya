import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelya_mobile/app/theme/theme.dart';
import 'package:panelya_mobile/shared/widgets/state_views.dart';

import '../../support/overflow_watcher.dart';
import '../../support/viewports.dart';

/// PLAN Görev B: `AppLoadingView`/`AppErrorView`/`AppEmptyView` her ekranın
/// (keşif, seri detay, okuyucu) ortak yükleniyor/hata/boş durumlarıdır (bkz.
/// docs/mobile-handoff.md "Kalite çizgisi" — her ekran bu üç durumu
/// tamamlar). Bu dosya onları kendi başlarına, uzun mesajlarla ve büyük
/// yazı tipinde (1.3/1.6/2.0) izole biçimde test eder.
Widget _wrap(Widget child, {double? textScale}) {
  return MaterialApp(
    theme: buildAppTheme(),
    builder: textScale == null
        ? null
        : (context, materialChild) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: materialChild!,
          ),
    home: Scaffold(body: child),
  );
}

const _longMessage =
    'Sunucuya ulaşılamadı; bağlantınızı kontrol edip tekrar deneyin. Bu '
    'hata mesajı, büyük yazı tipinde bile taşmadan sarmalanabilmesi için '
    'kasıtlı olarak uzun tutulmuştur.';

void main() {
  group('AppLoadingView', () {
    for (final scale in [1.0, 1.3, 1.6, 2.0]) {
      testWidgets('uzun etiketle taşmaz (scale=$scale)', (tester) async {
        useViewport(tester, phonePortrait);
        final watcher = OverflowWatcher()..start();
        addTearDown(watcher.stop);

        await tester.pumpWidget(
          _wrap(const AppLoadingView(label: _longMessage), textScale: scale),
        );
        await tester.pump();

        expect(find.text(_longMessage), findsOneWidget);
        expect(watcher.errors, isEmpty, reason: watcher.describe());
      });
    }
  });

  group('AppErrorView', () {
    for (final scale in [1.0, 1.3, 1.6, 2.0]) {
      testWidgets(
        'uzun mesaj + "Tekrar dene" butonu taşmaz, buton >= 44 px (scale=$scale)',
        (tester) async {
          useViewport(tester, phonePortrait);
          final watcher = OverflowWatcher()..start();
          addTearDown(watcher.stop);

          await tester.pumpWidget(
            _wrap(
              AppErrorView(message: _longMessage, onRetry: () {}),
              textScale: scale,
            ),
          );
          await tester.pump();

          expect(find.text(_longMessage), findsOneWidget);
          final buttonFinder = find.ancestor(
            of: find.text('Tekrar dene'),
            matching: find.byType(FilledButton),
          );
          expect(tester.getSize(buttonFinder).height, greaterThanOrEqualTo(44));
          expect(watcher.errors, isEmpty, reason: watcher.describe());
        },
      );

      testWidgets(
        'onRetry olmadan (yeniden deneme yok) taşmaz (scale=$scale)',
        (tester) async {
          useViewport(tester, phonePortrait);
          final watcher = OverflowWatcher()..start();
          addTearDown(watcher.stop);

          await tester.pumpWidget(
            _wrap(const AppErrorView(message: _longMessage), textScale: scale),
          );
          await tester.pump();

          expect(find.text('Tekrar dene'), findsNothing);
          expect(watcher.errors, isEmpty, reason: watcher.describe());
        },
      );
    }

    for (final entry in {
      'tablet dikey (768x1024)': tabletPortrait,
      'tablet yatay (1024x768)': tabletLandscape,
    }.entries) {
      testWidgets('${entry.key} taşmaz', (tester) async {
        useViewport(tester, entry.value);
        final watcher = OverflowWatcher()..start();
        addTearDown(watcher.stop);

        await tester.pumpWidget(
          _wrap(AppErrorView(message: _longMessage, onRetry: () {})),
        );
        await tester.pump();

        expect(watcher.errors, isEmpty, reason: watcher.describe());
      });
    }
  });

  group('AppEmptyView', () {
    for (final scale in [1.0, 1.3, 1.6, 2.0]) {
      testWidgets('uzun mesajla taşmaz (scale=$scale)', (tester) async {
        useViewport(tester, phonePortrait);
        final watcher = OverflowWatcher()..start();
        addTearDown(watcher.stop);

        await tester.pumpWidget(
          _wrap(const AppEmptyView(message: _longMessage), textScale: scale),
        );
        await tester.pump();

        expect(find.text(_longMessage), findsOneWidget);
        expect(watcher.errors, isEmpty, reason: watcher.describe());
      });
    }
  });
}
