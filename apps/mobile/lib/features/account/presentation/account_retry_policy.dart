import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/account_exceptions.dart';

/// Hesap `FutureProvider`'larının yeniden deneme politikası.
///
/// Riverpod 3'ün varsayılanı (`ProviderContainer.defaultRetry`) BAŞARISIZ
/// her provider'ı 10 kez, 200ms'den 6400ms'e büyüyen backoff ile yeniden
/// dener. Hesap uçlarında bu yanlış davranıyordu: sunucu sözleşmeye uygun
/// YAPILANDIRILMIŞ bir hata gövdesi döndüğünde (ör. `ACCOUNT_RUNTIME_SECRET`
/// eksikken gelen 503 "Hesap çalışma anahtarı yapılandırılmamış.") sonuç
/// deterministiktir — tekrar denemek onu başarılı yapmaz. Canlı QA'da
/// gözlenen etki: 11 istek ve kullanıcının ~25 saniye "yükleniyor"
/// ekranında bekletilmesi, ardından zaten baştan bilinen hatanın
/// gösterilmesi.
///
/// Bu politika ayrımı şöyle yapar:
///
/// * [AccountServerException] — sunucu KARAR VERDİ ve sebebini bildirdi.
///   Yeniden denenmez; kullanıcı hatayı HEMEN görür (bkz. ADR-010, dürüst
///   durum gösterimi).
/// * [AccountNotAuthenticatedException] — saklı oturum yok. İstek zaten
///   gönderilmedi; tekrar denemek anlamsız.
/// * Diğerleri (ör. [AccountUnexpectedException] — ağ/parse hatası) GERÇEK
///   geçici arızalardır; Riverpod'un varsayılan backoff'u korunur.
Duration? accountProviderRetry(int retryCount, Object error) {
  if (error is AccountServerException) return null;
  if (error is AccountNotAuthenticatedException) return null;
  return ProviderContainer.defaultRetry(retryCount, error);
}
