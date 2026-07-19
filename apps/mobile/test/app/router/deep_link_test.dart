import 'package:flutter_test/flutter_test.dart';
import 'package:panelya_mobile/app/router/deep_link.dart';

void main() {
  group('mapWebPathToMobileRoute', () {
    // Web tarafının URL yapısı `/<slug>` ve `/<slug>/<episodeSlug>`'dır
    // (bkz. `app/[slug]` ve `app/[slug]/[episode]`); mobil rota yapısı
    // `/series/:slug` ve `/series/:slug/read/:episodeSlug`'dır. Bu testler
    // Universal Links/App Links geldiğinde bu fonksiyonun kullanılacağı
    // dönüşümü sabitler (bkz. docs/mobile-handoff.md, README "Gelecek adım").

    test('root path maps to discover', () {
      expect(mapWebPathToMobileRoute('/'), '/');
    });

    test('empty path maps to discover', () {
      expect(mapWebPathToMobileRoute(''), '/');
    });

    test('single segment maps to series detail', () {
      expect(
        mapWebPathToMobileRoute('/gece-vardiyasi'),
        '/series/gece-vardiyasi',
      );
    });

    test('two segments map to the reader', () {
      expect(
        mapWebPathToMobileRoute('/gece-vardiyasi/bolum-1'),
        '/series/gece-vardiyasi/read/bolum-1',
      );
    });

    test('trailing slash on a single segment is tolerated', () {
      expect(
        mapWebPathToMobileRoute('/gece-vardiyasi/'),
        '/series/gece-vardiyasi',
      );
    });

    test('query strings do not leak into the mapped route', () {
      expect(
        mapWebPathToMobileRoute('/gece-vardiyasi?ref=share'),
        '/series/gece-vardiyasi',
      );
    });

    for (final webOnly in [
      '/about',
      '/login',
      '/studio',
      '/api',
      '/series', // mobil önekiyle karışmasın diye kasıtlı olarak elenir
    ]) {
      test('web-only top-level route "$webOnly" is not a series slug', () {
        expect(mapWebPathToMobileRoute(webOnly), isNull);
      });
    }

    test('three or more segments are unknown', () {
      expect(
        mapWebPathToMobileRoute('/gece-vardiyasi/bolum-1/extra'),
        isNull,
      );
    });
  });

  group('resolveCustomSchemeRoute', () {
    // `panelya://` custom scheme linkleri her zaman geçerli bir mobil rota
    // path'ine çözülür; hiçbir girdi için null veya exception fırlatmaz
    // (güvenli düşüş, bkz. PLAN Görev 3).

    test('bare scheme root maps to discover', () {
      expect(resolveCustomSchemeRoute(Uri.parse('panelya://')), '/');
    });

    test('series deep link maps to series detail route', () {
      expect(
        resolveCustomSchemeRoute(
          Uri.parse('panelya://series/gece-vardiyasi'),
        ),
        '/series/gece-vardiyasi',
      );
    });

    test('episode deep link maps to the reader route', () {
      expect(
        resolveCustomSchemeRoute(
          Uri.parse('panelya://series/gece-vardiyasi/read/bolum-1'),
        ),
        '/series/gece-vardiyasi/read/bolum-1',
      );
    });

    test('triple-slash (explicit empty host) form resolves the same way', () {
      // Bazı platformlarda/ayrıştırıcılarda `panelya:///series/x` biçimi
      // (boş host, path'te tüm segmentler) kullanılabilir; her iki biçim
      // de aynı sonucu üretmelidir.
      expect(
        resolveCustomSchemeRoute(
          Uri.parse('panelya:///series/gece-vardiyasi'),
        ),
        '/series/gece-vardiyasi',
      );
      expect(
        resolveCustomSchemeRoute(
          Uri.parse('panelya:///series/gece-vardiyasi/read/bolum-1'),
        ),
        '/series/gece-vardiyasi/read/bolum-1',
      );
    });

    test('unrecognized scheme falls back to discover', () {
      expect(
        resolveCustomSchemeRoute(Uri.parse('https://panelya.app/gece-vardiyasi')),
        '/',
      );
    });

    test('unknown top-level segment falls back to discover', () {
      expect(
        resolveCustomSchemeRoute(Uri.parse('panelya://unknown/thing')),
        '/',
      );
    });

    test('malformed series link missing a slug falls back to discover', () {
      expect(resolveCustomSchemeRoute(Uri.parse('panelya://series')), '/');
    });

    test('malformed read link missing the "read" segment falls back', () {
      expect(
        resolveCustomSchemeRoute(
          Uri.parse('panelya://series/gece-vardiyasi/bolum-1'),
        ),
        '/',
      );
    });

    test('extra trailing segments fall back to discover', () {
      expect(
        resolveCustomSchemeRoute(
          Uri.parse(
            'panelya://series/gece-vardiyasi/read/bolum-1/extra',
          ),
        ),
        '/',
      );
    });
  });
}
