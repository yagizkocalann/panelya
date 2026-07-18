import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';

/// Uygulama giriş noktası. Faz 1'de Firebase/analytics/reklam gibi harici
/// bir SDK başlatılmaz (Novel-Project'in Firebase katmanı taşınmaz, bkz.
/// ADR-019); yalnız Flutter binding'i hazırlanır ve [ProviderScope] içinde
/// [PanelyaApp] çalıştırılır.
void bootstrap() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: PanelyaApp()));
}
