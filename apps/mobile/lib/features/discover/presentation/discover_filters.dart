import '../../../core/contracts/series_contract.dart';

/// Katalogdaki tüm serilerin `genres` alanlarından tekilleştirilmiş,
/// alfabetik sıralı bir tür listesi üretir (bkz. PLAN Görev 2 — tür filtre
/// chip'leri katalogdaki `genres` alanından, istemci tarafında türetilir;
/// arama kapsam dışıdır ve API'de ayrı bir `genres` ucu yoktur).
List<String> uniqueGenres(List<SeriesSummaryContract> series) {
  final genres = <String>{};
  for (final item in series) {
    genres.addAll(item.metadata.genres);
  }
  final sorted = genres.toList()..sort();
  return sorted;
}

/// Seçili tür filtresini istemci tarafında uygular. `genre` `null` ise tüm
/// seriler değişmeden döner.
List<SeriesSummaryContract> filterSeriesByGenre(
  List<SeriesSummaryContract> series,
  String? genre,
) {
  if (genre == null) return series;
  return series
      .where((item) => item.metadata.genres.contains(genre))
      .toList(growable: false);
}

/// `featuredSlug`'a karşılık gelen katalog girdisini bulur; katalogda yoksa
/// (örn. tutarsız veri) `null` döner ve keşif ekranı hero'yu atlar.
SeriesSummaryContract? findFeaturedSeries(
  List<SeriesSummaryContract> series,
  String? featuredSlug,
) {
  if (featuredSlug == null) return null;
  for (final item in series) {
    if (item.metadata.slug == featuredSlug) return item;
  }
  return null;
}
