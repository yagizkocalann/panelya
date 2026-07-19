import '../../../core/contracts/generated/generated.dart';

/// Katalogdaki tüm serilerin `genres` alanlarından tekilleştirilmiş,
/// alfabetik sıralı bir tür listesi üretir (bkz. PLAN Görev 2 — tür filtre
/// chip'leri katalogdaki `genres` alanından, istemci tarafında türetilir;
/// arama kapsam dışıdır ve API'de ayrı bir `genres` ucu yoktur).
List<String> uniqueGenres(List<SeriesSummary> series) {
  final genres = <String>{};
  for (final item in series) {
    genres.addAll(item.genres);
  }
  final sorted = genres.toList()..sort();
  return sorted;
}

/// Seçili tür filtresini istemci tarafında uygular. `genre` `null` ise tüm
/// seriler değişmeden döner.
List<SeriesSummary> filterSeriesByGenre(
  List<SeriesSummary> series,
  String? genre,
) {
  if (genre == null) return series;
  return series
      .where((item) => item.genres.contains(genre))
      .toList(growable: false);
}

/// `featuredSlug`'a karşılık gelen katalog girdisini bulur; katalogda yoksa
/// (örn. tutarsız veri) `null` döner ve keşif ekranı hero'yu atlar.
SeriesSummary? findFeaturedSeries(
  List<SeriesSummary> series,
  String? featuredSlug,
) {
  if (featuredSlug == null) return null;
  for (final item in series) {
    if (item.slug == featuredSlug) return item;
  }
  return null;
}
