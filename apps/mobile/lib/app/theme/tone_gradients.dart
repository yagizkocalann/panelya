import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/contracts/generated/generated.dart';

/// `PanelTone` -> gradyan eşlemesi.
///
/// Kaynak (SALT OKUNUR referans): `app/globals.css`
/// - satır 103-108: `.poster--<tone>` (kapak/poster gradyanları — keşif
///   kartları ve hero, kapaksız seriler için).
/// - satır 209: `.story-panel--<tone>` (okuyucu panel gradyanları —
///   görselsiz/geri düşüş panelleri için).
///
/// Web tarafında `PanelTone.unknown` diye bir CSS sınıfı yoktur (ileri-
/// uyumluluk fallback'i yalnız mobil `fromJson`'da var, bkz.
/// `panel_tone.dart`); bu yüzden burada `unknown` için bilerek KEYDE YOK —
/// çağıranlar `null` aldığında mevcut düz `surface2`/`surface3` rengine
/// düşer (bkz. `cover_image.dart`, `reader_screen.dart`).
///
/// ## Açı çevirisi (CSS `deg` -> Flutter `Alignment`)
///
/// CSS `linear-gradient(Xdeg, ...)`'de açı, "yukarı" (`to top`) yönünü 0deg
/// kabul edip SAAT YÖNÜNDE artar (CSS Images spec). Flutter [LinearGradient]
/// ise `begin`/`end` iki [Alignment] noktası arasında yön tanımlar. X derece
/// için birim yön vektörü:
///
/// ```
/// dx = sin(X°)
/// dy = -cos(X°)
/// end   = Alignment(dx, dy)
/// begin = Alignment(-dx, -dy)
/// ```
///
/// (Doğrulama: X=0 -> (0,-1) yukarı; X=90 -> (1,0) sağ; X=180 -> (0,1)
/// aşağı; X=270 -> (-1,0) sol — CSS'in "to top/right/bottom/left"
/// karşılıklarıyla eşleşir.) Web'de kullanılan iki açı, `.poster--<tone>`
/// için 145deg ve `.story-panel--<tone>` için 150deg; bu sabitler burada
/// yukarıdaki formülle önceden hesaplanmıştır.
///
/// ## Basitleştirme (belgelendi)
///
/// `.poster--<tone>` sınıflarında linear-gradient'e ek olarak küçük bir
/// `radial-gradient(circle at X% Y%, ..., transparent Z%)` "parlama" noktası
/// vardır (örn. `.poster--coral`'daki `radial-gradient(circle at 72% 24%,
/// #ff9d8c 0 9%, transparent 10%)`). Bu, kartın küçük bir köşesinde kalan,
/// salt dekoratif bir vurgu noktasıdır; mobilde AYRI bir katman gerektirir
/// (Flutter [LinearGradient]/[BoxDecoration] tek bir gradyanı destekler) ve
/// görsel katkısı kart boyutunda düşüktür. Bu yüzden yalnız her iki tonun da
/// ORTAK bileşeni olan linear-gradient aynalanır; radial nokta mobilde
/// uygulanmadı. `.story-panel--<tone>` sınıflarında zaten radial bileşen
/// yoktur; o eşleme birebirdir.

/// `X` derece için CSS `linear-gradient` yönünün Flutter karşılığı.
/// Yukarıdaki sınıf dokümanındaki formülün çalışma zamanı karşılığı; sabit
/// derece değerleri (145, 150) için önceden hesaplanmış [Alignment]
/// çiftleri döner.
({Alignment begin, Alignment end}) _alignmentsForCssDegrees(double degrees) {
  final radians = degrees * math.pi / 180;
  final dx = math.sin(radians);
  final dy = -math.cos(radians);
  return (begin: Alignment(-dx, -dy), end: Alignment(dx, dy));
}

final _posterAngle = _alignmentsForCssDegrees(145);
final _storyPanelAngle = _alignmentsForCssDegrees(150);

LinearGradient _poster(int c1, int c2, double c2Stop, int c3) {
  return LinearGradient(
    begin: _posterAngle.begin,
    end: _posterAngle.end,
    colors: [Color(c1), Color(c2), Color(c3)],
    stops: [0, c2Stop, 1],
  );
}

LinearGradient _storyPanel(int c1, int c2, int c3) {
  return LinearGradient(
    begin: _storyPanelAngle.begin,
    end: _storyPanelAngle.end,
    // Web tarafındaki tüm `.story-panel--<tone>` sınıflarının orta durağı
    // aynı (`55%`, bkz. `app/globals.css` satır 209).
    colors: [Color(c1), Color(c2), Color(c3)],
    stops: const [0, 0.55, 1],
  );
}

/// `.poster--<tone>` (satır 103-108) karşılığı. Bilinmeyen/`unknown` ton
/// için `null` döner; çağıran mevcut düz renk davranışına düşer.
final Map<PanelTone, LinearGradient> _posterGradients = {
  PanelTone.coral: _poster(0xFF511E36, 0xFFE54F4F, 0.48, 0xFF172820),
  PanelTone.mint: _poster(0xFF17382D, 0xFF4FBD91, 0.52, 0xFF10201B),
  PanelTone.violet: _poster(0xFF25183F, 0xFF7D5BC2, 0.50, 0xFF121827),
  PanelTone.blue: _poster(0xFF142D42, 0xFF3478A0, 0.48, 0xFF0F1B26),
  PanelTone.amber: _poster(0xFF3D2A14, 0xFFE59331, 0.50, 0xFF181A14),
  PanelTone.rose: _poster(0xFF351B25, 0xFFA9344F, 0.50, 0xFF18151B),
};

/// `.story-panel--<tone>` (satır 209) karşılığı. Bilinmeyen/`unknown` ton
/// için `null` döner; çağıran mevcut düz `surface2` rengine düşer.
final Map<PanelTone, LinearGradient> _storyPanelGradients = {
  PanelTone.coral: _storyPanel(0xFF552233, 0xFFE35D54, 0xFF15241F),
  PanelTone.mint: _storyPanel(0xFF17392D, 0xFF55B98E, 0xFF11231D),
  PanelTone.violet: _storyPanel(0xFF211735, 0xFF6C50A9, 0xFF121625),
  PanelTone.blue: _storyPanel(0xFF10293B, 0xFF2C6F91, 0xFF111C25),
  PanelTone.amber: _storyPanel(0xFF3C2815, 0xFFCF832E, 0xFF1B1912),
  PanelTone.rose: _storyPanel(0xFF351923, 0xFF9E344C, 0xFF17141A),
};

/// Bir [PanelTone] için `.poster--<tone>` gradyanı. `PanelTone.unknown`
/// (veya haritada karşılığı olmayan gelecekteki bir değer) için `null`
/// döner — kapaksız kart/hero placeholder'ı bu durumda mevcut düz
/// `surface3` rengine düşer (bkz. `cover_image.dart`).
LinearGradient? posterGradientForTone(PanelTone tone) => _posterGradients[tone];

/// Bir [PanelTone] için `.story-panel--<tone>` gradyanı. `PanelTone.unknown`
/// için `null` döner — okuyucudaki görselsiz geri düşüş paneli bu durumda
/// mevcut düz `surface2` rengine düşer (bkz. `reader_screen.dart`).
LinearGradient? storyPanelGradientForTone(PanelTone tone) =>
    _storyPanelGradients[tone];
