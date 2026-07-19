import 'package:flutter/widgets.dart';

/// Geniş ekranlarda (tablet ve üzeri) ana içerik sütununun en fazla
/// genişliği.
///
/// production-bible.md §1: "Okuyucu içeriği 690-800 px merkez kolonda,
/// boşluksuz dikey akışta sunulur." Bu bir renk/spacing token'ı değil, ürün
/// ilkesinden gelen bir düzen sınırıdır. Okuyucu, seri detay ve keşifteki
/// hero/"okumaya devam et" şeridi aynı merkez kolon deseninde tutarlı kalır
/// (bkz. PLAN Görev A — "okuyucudaki 760px merkez kolon deseniyle tutarlı
/// ol"). Telefon genişliklerinde (360-430 px) bu sınırın hiçbir etkisi
/// yoktur; yalnız tablet/geniş ekranlarda içerik merkeze alınır.
const double kContentMaxWidth = 760;

/// İçeriği [maxWidth] (varsayılan [kContentMaxWidth]) ile sınırlı bir
/// sütunda yatayda ortalar. Dar (telefon) genişliklerde tam genişliği
/// kaplamaya devam eder — [Center] + [ConstrainedBox] yalnızca üst sınırı
/// aşan genişliklerde devreye girer.
class CenteredMaxWidth extends StatelessWidget {
  const CenteredMaxWidth({
    super.key,
    required this.child,
    this.maxWidth = kContentMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
