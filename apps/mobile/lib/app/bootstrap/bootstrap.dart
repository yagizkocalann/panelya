import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/storage/shared_preferences_provider.dart';
import '../app.dart';

/// Uygulama giriş noktası. Faz 1'de Firebase/analytics/reklam gibi harici
/// bir SDK başlatılmaz (Novel-Project'in Firebase katmanı taşınmaz, bkz.
/// ADR-019); yalnız Flutter binding'i hazırlanır.
///
/// `SharedPreferences.getInstance()` burada BİR KEZ `await`lenir (cihaz-yerel
/// "kaldığın yerden devam et" kaydı için, bkz.
/// `features/progress/`) ve [sharedPreferencesProvider] override'ıyla
/// [ProviderScope]'a enjekte edilir; bu sayede alt katmandaki repository
/// senkron okuyabilir, ekranlar ek bir yükleniyor durumuyla uğraşmaz.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPreferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const PanelyaApp(),
    ),
  );
}
