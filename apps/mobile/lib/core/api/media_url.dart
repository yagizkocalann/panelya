/// `coverImage` (bkz. üretilen `SeriesMetadata`/`SeriesSummary`, ikisi de
/// `lib/core/contracts/generated/`) ve panel `image.src` (bkz. üretilen
/// `StoryPanelImage`) alanları bazen mutlak (`http(s)://...`) bazen web
/// deployment'ına göre relative
/// (`/images/...`) gelir (kaynak: `app/data/catalog.ts`). Bu yardımcı,
/// relative olanları merkezi `apiOrigin` ile birleştirir; zaten mutlak
/// olanlara dokunmaz.
///
/// Ekranlar arasında (okuyucu, keşif, seri detay) aynı mantığın
/// kopyalanmaması için tek kaynak burasıdır.
String resolveMediaUrl(String apiOrigin, String path) {
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  return '$apiOrigin$path';
}
