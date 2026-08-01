import 'package:flutter/foundation.dart';

/// `/catalog` rotasına go_router `extra` ile geçilen tipli argüman.
///
/// Ana sayfadaki açılır tür dizini (bkz.
/// `features/discovery/presentation/genre_disclosure.dart`) bir tür
/// seçildiğinde bu tipi taşıyarak `/catalog`'a gider; katalog ekranı
/// (`features/catalog/presentation/catalog_screen.dart`) bunu okuyup tür
/// filtresini seçili açar. `state.extra` beklenmeyen bir tipteyse (örn.
/// doğrudan `/catalog` linkine gidilmişse) çağıran taraf `null`'a düşer —
/// bu sınıfın kendisi hiçbir varsayım yapmaz, yalnız veri taşır.
@immutable
class CatalogRouteArgs {
  const CatalogRouteArgs({this.initialGenre});

  /// Katalog ekranının açılışta seçili göstereceği tür (varsa).
  final String? initialGenre;
}
