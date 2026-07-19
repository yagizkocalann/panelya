import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/shared_preferences_provider.dart';
import '../data/shared_preferences_reading_progress_repository.dart';
import '../domain/reading_progress.dart';
import '../domain/reading_progress_repository.dart';

/// Aktif [LocalReadingProgressRepository]. Ekranlar `SharedPreferences`'ı
/// değil bu provider'ı (veya aşağıdaki türetilmiş provider'ları) kullanır.
final readingProgressRepositoryProvider =
    Provider<LocalReadingProgressRepository>((ref) {
      return SharedPreferencesReadingProgressRepository(
        ref.watch(sharedPreferencesProvider),
      );
    });

/// Belirli bir seri için kayıtlı ilerleme (seri detay ekranı: "Devam et"
/// / "Baştan başla" kararı için). Kayıt yoksa `null`.
///
/// Bu bilerek bir `Provider.family` (senkron), `FutureProvider.family`
/// DEĞİL: depolama katmanı zaten senkron (bkz. `sharedPreferencesProvider`
/// dokümantasyonu). Değer, okuyucu bir bölüm açtığında/bitirdiğinde
/// bayatlar; okuyucu o noktada bu provider'ı (ve
/// [mostRecentReadingProgressProvider]'ı) açıkça `ref.invalidate` eder
/// (bkz. `reader_screen.dart`) — aksi halde seri sayfasına geri dönüldüğünde
/// eski değer önbellekte kalırdı.
final readingProgressForSeriesProvider = Provider.family<ReadingProgress?, String>(
  (ref, seriesSlug) =>
      ref.watch(readingProgressRepositoryProvider).findBySeries(seriesSlug),
);

/// Tüm serilerdeki en son güncellenen kayıt (keşif ekranındaki "Okumaya
/// devam et" şeridi için). Hiç kayıt yoksa `null` — bu durumda şerit hiç
/// render edilmez (ADR-010, bkz. `discover_screen.dart`).
final mostRecentReadingProgressProvider = Provider<ReadingProgress?>((ref) {
  return ref.watch(readingProgressRepositoryProvider).findMostRecent();
});
