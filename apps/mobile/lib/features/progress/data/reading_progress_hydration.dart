import '../../../core/contracts/generated/generated.dart';
import '../domain/reading_progress_repository.dart';
import '../domain/remote_reading_progress_repository.dart';

/// Sunucudaki ilerlemeyi kullanıcının YEREL cache'ine aynalar (bkz.
/// ADR-049).
///
/// KURALLAR — hiçbiri istemcide türetilmez, hepsi ADR-049'dan gelir:
///
/// * Giriş yapıldıktan sonra **sunucudaki ilerleme kanoniktir**.
/// * Aynı seri hem yerelde hem sunucuda varsa **uzak kayıt kazanır**.
///   İstemci `updatedAt` üzerinden YENİ BİR ÇATIŞMA KURALI ÜRETMEZ; son
///   sunucu yazımı esastır.
/// * Yalnız sunucuda bulunan kayıtlar yerel cache'e aynalanır.
/// * Yalnız yerelde bulunan (anonim namespace'ten gelen) kayıtlar hesaba
///   SESSİZCE YÜKLENMEZ. Kullanıcı o seriyi yeniden okursa normal `POST`
///   akışı hesap ilerlemesini zaten oluşturur.
///
/// Bu sınıf yalnız YAZAR; hata yönetimi ve "ne zaman çalışır" kararı
/// çağırana aittir (bkz. `readingProgressHydrationProvider`).
class ReadingProgressHydration {
  const ReadingProgressHydration({required this._remote, required this._local});

  final RemoteReadingProgressRepository _remote;
  final LocalReadingProgressRepository _local;

  /// `GET /api/progress` sonucunu kullanıcının yerel cache'ine yazar ve
  /// sunucudan gelen listeyi döner.
  ///
  /// Hata FIRLATIRSA çağıran gerçek hatayı gösterir; burada sahte başarı
  /// üretilmez ve MEVCUT YEREL VERİ SİLİNMEZ (aşağıda hiçbir `clear`
  /// çağrısı yoktur — yalnız üstüne yazılır).
  Future<ReadingProgressResponse> hydrate() async {
    final response = await _remote.fetchProgress();

    for (final item in response.items) {
      // Uzak kayıt KAZANIR: yerelde aynı seri varsa üstüne yazılır.
      //
      // `percent == 100` ise bölüm TAMAMLANMIŞTIR. Sonraki bölüm kararı
      // burada VERİLMEZ — seri detayındaki bölüm sırasından belirlenir
      // (bkz. `SeriesDetailResponse.episodes`); sunucuya da otomatik `0`
      // yazılmaz.
      await _local.recordEpisodeOpened(
        seriesSlug: item.series.slug,
        seriesTitle: item.series.title,
        episodeSlug: item.episode.slug,
        episodeNumber: item.episode.number,
      );
      if (item.percent >= 100) {
        await _local.recordEpisodeCompleted(
          seriesSlug: item.series.slug,
          seriesTitle: item.series.title,
          episodeSlug: item.episode.slug,
          episodeNumber: item.episode.number,
          // Sonraki bölüm BİLİNMİYOR: ilerleme sözleşmesi bölüm sırası
          // taşımaz. `null` verilerek kayıt tamamlanan bölümde bırakılır;
          // "sonraki bölüm" kararı seri ekranındaki yayın sırasına ait.
          nextEpisodeSlug: null,
          nextEpisodeNumber: null,
        );
      }
    }

    return response;
  }
}
