import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:panelya_mobile/features/auth/data/pkce.dart';

/// [PkcePair] birim testleri (bkz. ADR-039 — Authorization Code + PKCE,
/// `S256`). RFC 7636 Ek B'deki resmi test vektörü, `code_challenge`
/// hesaplamasının (SHA-256 + base64url, dolgusuz) doğru olduğunu
/// bağımsız bir kaynağa karşı doğrular.
void main() {
  group('pkceChallengeFromVerifier (RFC 7636 vektörü)', () {
    test('RFC 7636 Ek B örneği: verifier -> S256 challenge', () {
      // https://www.rfc-editor.org/rfc/rfc7636#appendix-B
      const verifier = 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk';
      const expectedChallenge = 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM';

      expect(pkceChallengeFromVerifier(verifier), expectedChallenge);
    });
  });

  group('PkcePair.generate', () {
    test('verifier length is within RFC 7636 §4.1 bounds (43-128)', () {
      final pair = PkcePair.generate();
      expect(pair.verifier.length, greaterThanOrEqualTo(43));
      expect(pair.verifier.length, lessThanOrEqualTo(128));
    });

    test('verifier only uses the RFC 7636 unreserved character set', () {
      final pair = PkcePair.generate();
      expect(RegExp(r'^[A-Za-z0-9\-._~]+$').hasMatch(pair.verifier), isTrue);
      // base64url alfabesi hiçbir zaman `+`, `/` ya da dolgu (`=`) üretmez.
      expect(pair.verifier.contains('+'), isFalse);
      expect(pair.verifier.contains('/'), isFalse);
      expect(pair.verifier.contains('='), isFalse);
    });

    test('challenge is the S256 derivation of the same verifier', () {
      final pair = PkcePair.generate();
      expect(pair.challenge, pkceChallengeFromVerifier(pair.verifier));
    });

    test('challenge is base64url (no padding, no + or /)', () {
      final pair = PkcePair.generate();
      expect(RegExp(r'^[A-Za-z0-9\-_]+$').hasMatch(pair.challenge), isTrue);
    });

    test('two independent calls never produce the same verifier '
        '(entropy sanity check, not a formal randomness proof)', () {
      final first = PkcePair.generate();
      final second = PkcePair.generate();
      expect(first.verifier, isNot(second.verifier));
      expect(first.challenge, isNot(second.challenge));
    });

    test('deterministic with an injected Random (test-only seam)', () {
      final first = PkcePair.generate(random: Random(42));
      final second = PkcePair.generate(random: Random(42));
      expect(first.verifier, second.verifier);
      expect(first.challenge, second.challenge);
    });
  });
}
