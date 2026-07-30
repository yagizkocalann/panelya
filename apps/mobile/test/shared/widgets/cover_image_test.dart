import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelya_mobile/app/theme/theme.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';
import 'package:panelya_mobile/shared/widgets/cover_image.dart';

/// `packages/contracts/fixtures/catalog.v1.json`'daki GERÇEK
/// `coverImageVariants` değerleriyle (bkz. görev bağlamı — "fixture'lardaki
/// gerçek varyant değerleriyle seçici entegrasyon testi") `CoverImage`
/// widget'ının `LayoutBuilder`/`MediaQuery` tabanlı varyant seçim yolunu
/// doğrular. Fixture içeriği buraya elle kopyalanmaz; dosyadan okunup
/// üretilen `CatalogResponse.fromJson` ile ayrıştırılır (bkz.
/// `test/core/contracts/fixture_contracts_test.dart`'taki aynı desen).
///
/// `flutter test` her zaman paket kökünden (`apps/mobile`) çalıştırıldığı
/// için repo köküne göre relative yol `../../packages/contracts/fixtures`
/// olur.
const _fixturesDir = '../../packages/contracts/fixtures';

List<PublicMediaVariant> _fixtureCoverVariants() {
  final file = File('$_fixturesDir/catalog.v1.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final response = CatalogResponse.fromJson(json);
  return response.series.single.coverImageVariants!;
}

/// Ekrandaki `Image` widget'ının yüklemeye çalıştığı nihai (mutlak) URL'i
/// döner. `Image.network` bir `NetworkImage(url)` üretir; testlerde gerçek
/// ağ erişimi yapılmaz (widget ağacı build edilir edilmez bu bilgi zaten
/// vardır), bu yüzden `tester.pump()` sonrası hatasız okunabilir.
String _renderedImageUrl(WidgetTester tester) {
  final image = tester.widget<Image>(find.byType(Image));
  return (image.image as NetworkImage).url;
}

Widget _wrap({
  required String? src,
  required List<PublicMediaVariant>? variants,
  required double width,
}) {
  return ProviderScope(
    child: MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            height: width,
            child: CoverImage(
              src: src,
              semanticLabel: 'Test kapak',
              variants: variants,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('CoverImage varyant seçimi (packages/contracts fixture entegrasyonu)', () {
    testWidgets(
      'variants null ise mevcut src davranışı birebir korunur (geri-düşüş '
      'yolu regresyonsuz — canlı yerel API henüz varyant döndürmüyor)',
      (tester) async {
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _wrap(
            src: '/api/media/fixture-cover-1',
            variants: null,
            width: 300,
          ),
        );
        await tester.pump();

        expect(
          _renderedImageUrl(tester),
          'http://localhost:3000/api/media/fixture-cover-1',
        );
      },
    );

    testWidgets(
      'dar genişlik + DPR 1.0: hedefi karşılayan en küçük fixture varyantı '
      '(480) seçilir',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _wrap(
            src: '/api/media/fixture-cover-1',
            variants: _fixtureCoverVariants(),
            width: 300,
          ),
        );
        await tester.pump();

        // 300 mantıksal px × 1.0 DPR = 300px hedef; 480 yeterli ve tek
        // sırasıyla küçük.
        expect(
          _renderedImageUrl(tester),
          'http://localhost:3000/api/media/fixture-cover-1?width=480',
        );
      },
    );

    testWidgets(
      'geniş genişlik + yüksek DPR: hedefi karşılayan büyük fixture '
      'varyantı (768) seçilir',
      (tester) async {
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _wrap(
            src: '/api/media/fixture-cover-1',
            variants: _fixtureCoverVariants(),
            width: 300,
          ),
        );
        await tester.pump();

        // 300 × 2.0 = 600px hedef; 480 yetersiz, 768 yeterli ve en küçüğü.
        expect(
          _renderedImageUrl(tester),
          'http://localhost:3000/api/media/fixture-cover-1?width=768',
        );
      },
    );

    testWidgets(
      'hiçbir fixture varyantı hedefi karşılamıyorsa (çok yüksek DPR) en '
      'büyük varyant (768) seçilir',
      (tester) async {
        tester.view.devicePixelRatio = 4.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _wrap(
            src: '/api/media/fixture-cover-1',
            variants: _fixtureCoverVariants(),
            width: 300,
          ),
        );
        await tester.pump();

        expect(
          _renderedImageUrl(tester),
          'http://localhost:3000/api/media/fixture-cover-1?width=768',
        );
      },
    );

    testWidgets(
      'src null ise variants verilse bile placeholder gösterilir (kapaksız '
      'seri davranışı değişmez)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(src: null, variants: _fixtureCoverVariants(), width: 300),
        );
        await tester.pump();

        expect(find.byType(Image), findsNothing);
        expect(find.byIcon(Icons.auto_stories_outlined), findsOneWidget);
      },
    );
  });
}
