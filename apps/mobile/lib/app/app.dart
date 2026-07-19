import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/router.dart';
import 'theme/theme.dart';

/// Kök widget: go_router yapılandırmasını `MaterialApp.router` içine,
/// Panelya'nın tek (koyu) temasıyla birlikte bağlar.
///
/// Yerelleştirme: uygulama metinleri zaten Türkçe hardcoded'dır; buradaki
/// `localizationsDelegates`/`locale` yalnız Flutter'ın kendi sistem widget
/// metinlerini (geri tooltip'i, metin seçim menüleri — Kopyala/Yapıştır/Tümünü
/// Seç, semantics duyuruları) Türkçe'ye çevirir (bkz. AGENTS.md,
/// production-bible.md). Uygulama içeriğini ARB'ye taşımak bu kapsamın
/// dışındadır.
class PanelyaApp extends ConsumerWidget {
  const PanelyaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Panelya',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('tr')],
      locale: const Locale('tr'),
    );
  }
}
