import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Anasayfaya ("/") doğrudan atlama aksiyonu (bkz. PLAN Görev 3 — kullanıcı
/// şikayeti: bir seri/bölüme girildiğinde anasayfaya dönecek bir yol yoktu).
/// `AppBar.actions`'a eklenen tek, tutarlı bir [IconButton]; her ekranda
/// aynı ikon/tooltip/davranışla görünür (keşif ekranının kendisi hariç —
/// zaten ana sayfa olduğu için gerekmez).
///
/// `context.go('/')` burada DOĞRU kullanımdır: "ana sayfaya git" semantik
/// olarak mevcut push yığınını geçersiz kılıp köke dönmek anlamına gelir.
/// Bu, okuyucudaki "seriye dön" (gerçek `pop()`, bkz. `reader_screen.dart`
/// `_returnToSeries`) veya bölüm geçişi (`pushReplacement()`) aksiyonlarının
/// geçmişi koruyan semantiğiyle KARIŞTIRILMAMALIDIR — "anasayfaya git" için
/// yığını temizlemek tam olarak istenen davranıştır.
///
/// Global `IconButtonThemeData` (bkz. `app/theme/theme.dart`) zaten en az
/// 44x44 dokunma hedefini garanti eder; `tooltip` ekran okuyucu etiketini
/// sağlar (ek bir `Semantics` sarmalayıcıya gerek yok — okuyucudaki mevcut
/// `_SeriesReturnButton` ile aynı desen).
class HomeButton extends StatelessWidget {
  const HomeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.home_outlined),
      tooltip: 'Ana sayfa',
      onPressed: () => context.go('/'),
    );
  }
}
