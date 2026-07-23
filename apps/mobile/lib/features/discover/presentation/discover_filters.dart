import '../../../core/contracts/generated/generated.dart';

/// Seçili tür filtresini istemci tarafında uygular. `genre` `null` ise tüm
/// seriler değişmeden döner.
///
/// Katalog ekranındaki (`/catalog`, bkz.
/// `features/catalog/presentation/catalog_screen.dart`) tür FİLTRE
/// SEÇENEKLERİ artık bu dosyanın eski `uniqueGenres` fonksiyonuyla tam
/// katalogdan istemci tarafında yeniden toplanmıyor — `GET /api/discovery`
/// `genres` alanından (bkz. `DiscoveryResponse.genres`) okunuyor, çünkü web
/// tarafında bu iki uç aynı temel sorguyu paylaşır (`listPublishedGenres` ve
/// `listPublishedSeries` aynı "yayınlanmış ve en az bir yayınlanmış bölümü
/// olan seri" kümesini tarar, bkz. `app/lib/content-repository.ts`) ve bu
/// yüzden asla sapmaz; tek kaynaktan okumak ana sayfadaki açılır tür
/// diziniyle (bkz. `GenreDisclosure`) birebir aynı listeyi garanti eder.
/// Bu yüzden `uniqueGenres` kaldırıldı (bkz. PLAN Görev 4 — "SİLME kararını
/// sen ver"). [filterSeriesByGenre] ise hâlâ kullanılıyor: seçili türe göre
/// FİLTRELEME mantığı, kaynak listenin nereden geldiğinden (tam katalog)
/// bağımsız, saf bir fonksiyon olarak kalır.
List<SeriesSummary> filterSeriesByGenre(
  List<SeriesSummary> series,
  String? genre,
) {
  if (genre == null) return series;
  return series
      .where((item) => item.genres.contains(genre))
      .toList(growable: false);
}
