import 'package:flutter/foundation.dart';

/// RenderFlex/RenderBox taşma hatalarını yakalayıp toplayan test yardımcısı.
///
/// Flutter'da bir `Row`/`Column` (RenderFlex) taşması normalde throw
/// EDİLMEZ — yalnızca `FlutterError.onError` üzerinden raporlanır ve ekranda
/// sarı/siyah çizgili bir uyarı olarak boyanır. Bu yüzden düz bir
/// `tester.takeException()` kontrolü büyük yazı tipinde (`textScaler`
/// 1.3/1.6/2.0) sessizce oluşan bir taşmayı YAKALAMAZ (bkz. PLAN Görev B.1
/// — "FlutterError.onError ile overflow'u hataya çevirme deseni").
///
/// Kullanım: `start()` ile geçici olarak `FlutterError.onError`'ı sarar,
/// `stop()` ile eski haline döndürür (bkz. `addTearDown(watcher.stop)`).
/// Testler `watcher.errors`'ın boş olduğunu doğrular.
class OverflowWatcher {
  final List<FlutterErrorDetails> errors = [];
  FlutterExceptionHandler? _previous;

  void start() {
    _previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final description = details.exception.toString();
      if (description.contains('overflowed')) {
        errors.add(details);
      }
      // HER ZAMAN önceki (test binding'in kendi) handler'ına iletilir.
      // `flutter_test`'in kendi `FlutterError.onError` sarmalayıcısı, bir
      // hatayı `_pendingExceptionDetails` içinde tutup testi kendi
      // mekanizmasıyla düşürmeyi bekler; burada yutup iletmemek bu iç
      // muhasebeyi bozar ve "test overrode FlutterError.onError but either
      // failed to return it..." gibi alakasız bir meta-assertion'a yol
      // açar (bkz. bu dosyanın eklenmesine yol açan gerçek RenderFlex
      // taşması hata ayıklaması).
      _previous?.call(details);
    };
  }

  void stop() {
    FlutterError.onError = _previous;
  }

  /// Hata mesajlarını okunabilir tek bir metinde birleştirir (test
  /// `reason`/başarısızlık çıktısında kullanılmak üzere).
  String describe() =>
      errors.map((d) => d.exception.toString()).join('\n---\n');
}
