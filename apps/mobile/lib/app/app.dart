import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/router.dart';
import 'theme/theme.dart';

/// Kök widget: go_router yapılandırmasını `MaterialApp.router` içine,
/// Panelya'nın tek (koyu) temasıyla birlikte bağlar.
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
    );
  }
}
