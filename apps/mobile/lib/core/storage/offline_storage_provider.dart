import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Uygulama genelinde paylaşılan, çevrimdışı bölüm indirmelerinin (bkz.
/// `features/offline/`) yazıldığı kök [Directory].
///
/// `path_provider`'ın `getApplicationDocumentsDirectory()` çağrısı async
/// olduğu için (bkz. `sharedPreferencesProvider`'daki aynı desen) bu değer
/// `bootstrap()` içinde uygulama açılışında BİR KEZ `await`lenir ve
/// [ProviderScope] override'ıyla enjekte edilir; böylece
/// `offlineEpisodeRepositoryProvider` senkron bir [Directory] üzerinden
/// kurulur.
///
/// Testlerde bu provider `Directory.systemTemp.createTempSync()` ile elde
/// edilen geçici bir dizinle override edilir — gerçek `path_provider`
/// platform kanalı hiç çağrılmaz.
final offlineStorageDirectoryProvider = Provider<Directory>((ref) {
  throw UnimplementedError(
    'offlineStorageDirectoryProvider, bootstrap() (veya test kurulumunda) '
    'override edilmeden önce okunamaz.',
  );
});
