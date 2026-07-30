import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uygulama genelinde paylaşılan tek [SharedPreferences] örneği.
///
/// `SharedPreferences.getInstance()` async olduğu için bu değer
/// `bootstrap()` içinde uygulama açılışında BİR KEZ `await`lenir ve
/// [ProviderScope] override'ıyla enjekte edilir (bkz.
/// `app/bootstrap/bootstrap.dart`); bu sayede depolamaya bağlı repository'ler
/// (örn. `readingProgressRepositoryProvider`) senkron okuma yapabilir,
/// ekranlar ek bir `AsyncValue` katmanıyla uğraşmaz.
///
/// Testlerde bu provider `SharedPreferences.setMockInitialValues({...})`
/// sonrası elde edilen bir örnekle override edilir.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider, bootstrap() (veya test kurulumunda) '
    'override edilmeden önce okunamaz.',
  );
});
