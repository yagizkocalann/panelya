import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';
import 'package:panelya_mobile/features/account/domain/account_exceptions.dart';
import 'package:panelya_mobile/features/account/presentation/account_retry_policy.dart';

AccountServerException _serverError({
  String error = 'service_unavailable',
  String description = 'Hesap çalışma anahtarı yapılandırılmamış.',
}) {
  return AccountServerException(
    AccountErrorResponse(
      schemaVersion: kSchemaVersion,
      error: error,
      errorDescription: description,
      reauthenticate: false,
    ),
  );
}

void main() {
  group('accountProviderRetry', () {
    test('sunucunun YAPILANDIRILMIŞ hata gövdesi yeniden DENENMEZ — sonuc '
        'deterministik, kullanici hatayi hemen gormeli', () {
      expect(accountProviderRetry(0, _serverError()), isNull);
      expect(accountProviderRetry(0, _serverError(error: 'forbidden')), isNull);
    });

    test('sakli oturum yokken yeniden DENENMEZ (istek zaten gonderilmedi)', () {
      expect(
        accountProviderRetry(0, const AccountNotAuthenticatedException()),
        isNull,
      );
    });

    test(
      'ag/parse hatasi GERCEK gecici arizadir — Riverpod varsayilani korunur',
      () {
        final delay = accountProviderRetry(
          0,
          const AccountUnexpectedException('Baglanti kurulamadi.'),
        );

        expect(delay, isNotNull);
        expect(
          delay,
          ProviderContainer.defaultRetry(
            0,
            const AccountUnexpectedException('Baglanti kurulamadi.'),
          ),
        );
      },
    );

    test('gecici hatada backoff denemeyle birlikte BUYUR', () {
      const error = AccountUnexpectedException('Baglanti kurulamadi.');
      final first = accountProviderRetry(0, error)!;
      final third = accountProviderRetry(2, error)!;

      expect(third, greaterThan(first));
    });

    test('gecici hata sonsuza kadar denenmez, bir noktada durur', () {
      const error = AccountUnexpectedException('Baglanti kurulamadi.');
      // Riverpod varsayilani 10 denemede durur.
      expect(accountProviderRetry(10, error), isNull);
    });
  });
}
