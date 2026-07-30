import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelya_mobile/app/theme/theme.dart';
import 'package:panelya_mobile/core/config/app_config.dart';
import 'package:panelya_mobile/features/legal/presentation/legal_links.dart';

/// `url_launcher` platform kanalını yakalar: gerçek bir tarayıcı açılmaz,
/// yalnız HANGI URL'in istendiği kaydedilir.
class _LaunchRecorder {
  final List<String> launched = [];
  bool result = true;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          (call) async {
            if (call.method == 'launch') {
              launched.add(call.arguments['url'] as String);
              return result;
            }
            if (call.method == 'canLaunch') return true;
            return null;
          },
        );
  }

  void remove() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          null,
        );
  }
}

Widget _wrap({required AppConfig config}) {
  return ProviderScope(
    overrides: [appConfigProvider.overrideWithValue(config)],
    child: MaterialApp(
      theme: buildAppTheme(),
      home: const Scaffold(body: LegalLinks()),
    ),
  );
}

void main() {
  late _LaunchRecorder recorder;

  setUp(() {
    recorder = _LaunchRecorder()..install();
  });
  tearDown(() => recorder.remove());

  testWidgets('uc yasal baglantinin ucu de gorunur', (tester) async {
    await tester.pumpWidget(
      _wrap(
        config: const AppConfig(
          apiOrigin: 'https://api.invalid',
          webOrigin: 'https://panelya.invalid',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gizlilik'), findsOneWidget);
    expect(find.text('Kullanım koşulları'), findsOneWidget);
    expect(find.text('Telif bildirimi'), findsOneWidget);
  });

  testWidgets('baglanti WEB origin\'i kullanir, API origin\'i DEGIL', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        config: const AppConfig(
          apiOrigin: 'https://api.invalid',
          webOrigin: 'https://panelya.invalid',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gizlilik'));
    await tester.pumpAndSettle();

    expect(recorder.launched, ['https://panelya.invalid/privacy']);
  });

  testWidgets('her baglanti web footer\'iyla AYNI yolu acar', (tester) async {
    await tester.pumpWidget(
      _wrap(
        config: const AppConfig(
          apiOrigin: 'https://panelya.invalid',
          webOrigin: 'https://panelya.invalid',
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final entry in legalPages.entries) {
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
    }

    expect(recorder.launched, [
      'https://panelya.invalid/privacy',
      'https://panelya.invalid/terms',
      'https://panelya.invalid/copyright',
    ]);
  });

  testWidgets('sayfa acilamazsa SESSIZ kalinmaz, sebep gosterilir', (
    tester,
  ) async {
    recorder.result = false;

    await tester.pumpWidget(
      _wrap(
        config: const AppConfig(
          apiOrigin: 'https://panelya.invalid',
          webOrigin: 'https://panelya.invalid',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gizlilik'));
    await tester.pumpAndSettle();

    expect(find.text('Sayfa açılamadı. Tekrar dene.'), findsOneWidget);
  });

  testWidgets('buyuk yazi boyutunda tasma olmaz — etiketler alt satira iner', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiOrigin: 'https://panelya.invalid',
              webOrigin: 'https://panelya.invalid',
            ),
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2.4)),
            child: child!,
          ),
          home: const Scaffold(body: LegalLinks()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Gizlilik'), findsOneWidget);
  });
}
