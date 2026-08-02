import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelya_mobile/features/push/data/push_authorization.dart';

void main() {
  group('isAuthorizedStatus', () {
    test('authorized izin verildi sayilir', () {
      expect(isAuthorizedStatus(AuthorizationStatus.authorized), isTrue);
    });

    test('provisional (sessiz bildirim) izin verildi sayilir', () {
      expect(isAuthorizedStatus(AuthorizationStatus.provisional), isTrue);
    });

    test('denied izin verilmedi sayilir', () {
      expect(isAuthorizedStatus(AuthorizationStatus.denied), isFalse);
    });

    test('notDetermined izin verilmedi sayilir', () {
      expect(isAuthorizedStatus(AuthorizationStatus.notDetermined), isFalse);
    });
  });
}
