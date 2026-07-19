import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelya_mobile/app/theme/tone_gradients.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';

void main() {
  group('posterGradientForTone', () {
    // Web referansı: app/globals.css satır 103-108 (`.poster--<tone>`),
    // yalnız linear-gradient bileşeni (radial "parlama" noktası bilerek
    // basitleştirildi, bkz. tone_gradients.dart dosya başlığı).
    const expectedFirstAndLastColor = {
      PanelTone.coral: (0xFF511E36, 0xFF172820),
      PanelTone.mint: (0xFF17382D, 0xFF10201B),
      PanelTone.violet: (0xFF25183F, 0xFF121827),
      PanelTone.blue: (0xFF142D42, 0xFF0F1B26),
      PanelTone.amber: (0xFF3D2A14, 0xFF181A14),
      PanelTone.rose: (0xFF351B25, 0xFF18151B),
    };

    for (final entry in expectedFirstAndLastColor.entries) {
      test('${entry.key.name} matches .poster--${entry.key.name} endpoints', () {
        final gradient = posterGradientForTone(entry.key);
        expect(gradient, isNotNull);
        expect(gradient!.colors.first, Color(entry.value.$1));
        expect(gradient.colors.last, Color(entry.value.$2));
        // 3 stop: başlangıç, orta (tona özgü yüzde), bitiş.
        expect(gradient.colors, hasLength(3));
        expect(gradient.stops, hasLength(3));
        expect(gradient.stops!.first, 0);
        expect(gradient.stops!.last, 1);
      });
    }

    test(
      'PanelTone.unknown has no mapping — callers fall back to the flat '
      'surface color (cover_image.dart)',
      () {
        expect(posterGradientForTone(PanelTone.unknown), isNull);
      },
    );

    test(
      '145deg CSS angle points from upper-left-ish to lower-right-ish '
      '(begin/end are opposite unit-circle points)',
      () {
        final gradient = posterGradientForTone(PanelTone.coral)!;
        expect(gradient.begin, isA<Alignment>());
        final begin = gradient.begin as Alignment;
        final end = gradient.end as Alignment;
        // begin ve end birbirinin tam tersi (merkeze göre simetrik).
        expect(begin.x, closeTo(-end.x, 1e-9));
        expect(begin.y, closeTo(-end.y, 1e-9));
        // 145deg (90deg=sağ ile 180deg=aşağı arası): x ve y bileşenleri
        // ikisi de pozitif yönde (end sağ-aşağıya doğru).
        expect(end.x, greaterThan(0));
        expect(end.y, greaterThan(0));
      },
    );
  });

  group('storyPanelGradientForTone', () {
    // Web referansı: app/globals.css satır 209 (`.story-panel--<tone>`).
    const expectedFirstMiddleLastColor = {
      PanelTone.coral: (0xFF552233, 0xFFE35D54, 0xFF15241F),
      PanelTone.mint: (0xFF17392D, 0xFF55B98E, 0xFF11231D),
      PanelTone.violet: (0xFF211735, 0xFF6C50A9, 0xFF121625),
      PanelTone.blue: (0xFF10293B, 0xFF2C6F91, 0xFF111C25),
      PanelTone.amber: (0xFF3C2815, 0xFFCF832E, 0xFF1B1912),
      PanelTone.rose: (0xFF351923, 0xFF9E344C, 0xFF17141A),
    };

    for (final entry in expectedFirstMiddleLastColor.entries) {
      test(
        '${entry.key.name} matches .story-panel--${entry.key.name} '
        'colors and the shared 55% middle stop',
        () {
          final gradient = storyPanelGradientForTone(entry.key);
          expect(gradient, isNotNull);
          expect(gradient!.colors, [
            Color(entry.value.$1),
            Color(entry.value.$2),
            Color(entry.value.$3),
          ]);
          expect(gradient.stops, [0, 0.55, 1]);
        },
      );
    }

    test(
      'PanelTone.unknown has no mapping — callers fall back to the flat '
      'surface2 background (reader_screen.dart no-image fallback)',
      () {
        expect(storyPanelGradientForTone(PanelTone.unknown), isNull);
      },
    );
  });
}
