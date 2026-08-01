import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelya_mobile/shared/layout/content_max_width.dart';

import '../../support/viewports.dart';

/// `CenteredMaxWidth`, PLAN Görev A'da okuyucu (`ReaderScreen`), seri detay
/// (`SeriesScreen`) ve keşifteki hero/"okumaya devam et" şeridinin hepsinin
/// paylaştığı tek merkez-sütun sarmalayıcısıdır. Bu dosya onu, ekran
/// senaryolarının scroll/sliver karmaşıklığından bağımsız olarak izole
/// biçimde doğrular.
void main() {
  Widget wrap(Widget child, {double? maxWidth}) {
    return MaterialApp(
      home: Scaffold(
        body: maxWidth == null
            ? CenteredMaxWidth(child: child)
            : CenteredMaxWidth(maxWidth: maxWidth, child: child),
      ),
    );
  }

  testWidgets(
    'dar (telefon) genişlikte içerik tam genişliği kaplamaya devam eder',
    (tester) async {
      useViewport(tester, phonePortrait);
      await tester.pumpWidget(
        wrap(
          Container(
            key: const ValueKey('content'),
            width: double.infinity,
            height: 50,
            color: Colors.red,
          ),
        ),
      );

      final width = tester.getRect(find.byKey(const ValueKey('content'))).width;
      expect(width, phonePortrait.width);
    },
  );

  testWidgets(
    'geniş (tablet) genişlikte içerik kContentMaxWidth ile sınırlanır ve '
    'yatayda ortalanır',
    (tester) async {
      useViewport(tester, tabletLandscape);
      await tester.pumpWidget(
        wrap(
          Container(
            key: const ValueKey('content'),
            width: double.infinity,
            height: 50,
            color: Colors.red,
          ),
        ),
      );

      final rect = tester.getRect(find.byKey(const ValueKey('content')));
      expect(rect.width, kContentMaxWidth);
      // Ortalanmış: sol ve sağ boşluklar eşit.
      final leftGap = rect.left;
      final rightGap = tabletLandscape.width - rect.right;
      expect(leftGap, closeTo(rightGap, 0.5));
    },
  );

  testWidgets('özel bir maxWidth verilirse o kullanılır', (tester) async {
    useViewport(tester, tabletLandscape);
    await tester.pumpWidget(
      wrap(
        Container(
          key: const ValueKey('content'),
          width: double.infinity,
          height: 50,
          color: Colors.red,
        ),
        maxWidth: 400,
      ),
    );

    final width = tester.getRect(find.byKey(const ValueKey('content'))).width;
    expect(width, 400);
  });
}
