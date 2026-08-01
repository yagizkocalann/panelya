import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/config/app_config.dart';

/// Herkese açık web sitesindeki yasal sayfalar. Yollar web'in
/// `SiteFooter` bileşeniyle AYNIDIR (bkz. `app/components/SiteFooter.tsx`).
const legalPages = <String, String>{
  'Gizlilik': '/privacy',
  'Kullanım koşulları': '/terms',
  'Telif bildirimi': '/copyright',
};

/// Yasal sayfa bağlantıları.
///
/// NEDEN VAR: hem App Store (Review Guideline 5.1.1) hem Play Console,
/// hesap açan ve kişisel veri işleyen uygulamalarda gizlilik politikasının
/// UYGULAMA İÇİNDEN erişilebilir olmasını ister. Bu bağlantılar daha önce
/// mobil tarafta hiç yoktu; yalnız web footer'ında vardı.
///
/// Giriş yapılmış olsun ya da olmasın HER ZAMAN görünür: yasal bilgiye
/// ulaşmak hesap gerektirmez.
///
/// Sayfalar SİSTEM TARAYICISINDA açılır, uygulama içi WebView'da değil —
/// ADR-039'un auth için koyduğu sınırla aynı gerekçe: kullanıcı adres
/// çubuğunu ve sertifikayı görebilmeli.
class LegalLinks extends ConsumerWidget {
  const LegalLinks({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, String path) async {
    final origin = ref.read(appConfigProvider).webOrigin;
    final uri = Uri.parse('$origin$path');
    final messenger = ScaffoldMessenger.of(context);

    // `launchUrl` false dönebilir VE fırlatabilir; ikisi de "açılamadı"
    // demektir ve sessizce yutulmaz (ADR-010).
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      opened = false;
    }
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Sayfa açılamadı. Tekrar dene.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.md,
        vertical: tokens.spacing.sm,
      ),
      // `Wrap`: büyük yazı boyutunda etiketler yan yana sığmazsa alt
      // satıra iner, taşma olmaz.
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: tokens.spacing.sm,
        children: [
          for (final entry in legalPages.entries)
            TextButton(
              onPressed: () => _open(context, ref, entry.value),
              child: Text(entry.key),
            ),
        ],
      ),
    );
  }
}
