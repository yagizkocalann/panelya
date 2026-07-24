import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/storage/offline_storage_provider.dart';
import '../../core/storage/shared_preferences_provider.dart';
import '../app.dart';

/// Uygulama giriş noktası. Faz 1'de Firebase/analytics/reklam gibi harici
/// bir SDK başlatılmaz (Novel-Project'in Firebase katmanı taşınmaz, bkz.
/// ADR-019); yalnız Flutter binding'i hazırlanır.
///
/// `SharedPreferences.getInstance()` ve `getApplicationDocumentsDirectory()`
/// burada BİR KEZ `await`lenir (sırasıyla cihaz-yerel "kaldığın yerden devam
/// et" kaydı için, bkz. `features/progress/`, ve çevrimdışı bölüm indirmeleri
/// için, bkz. `features/offline/`) ve ilgili provider override'larıyla
/// [ProviderScope]'a enjekte edilir; bu sayede alt katmandaki repository'ler
/// senkron kurulabilir, ekranlar ek bir yükleniyor durumuyla uğraşmaz.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPreferences = await SharedPreferences.getInstance();
  final offlineStorageDirectory = await getApplicationDocumentsDirectory();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        offlineStorageDirectoryProvider.overrideWithValue(
          offlineStorageDirectory,
        ),
      ],
      child: const PanelyaApp(),
    ),
  );
}
