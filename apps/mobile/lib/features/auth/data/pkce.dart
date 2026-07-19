import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// RFC 7636 (Authorization Code + PKCE) `code_verifier`/`code_challenge`
/// çifti. Embedded WebView ve uygulamaya gömülü client secret kullanılmaz
/// (bkz. ADR-039); PKCE bunun yerine her oturum açma denemesi için
/// tek-kullanımlık bir sır üretir.
///
/// Yalnız `S256` yöntemi desteklenir (`code_challenge_method: S256`,
/// ADR-039'da açıkça seçilen yöntem); düz-metin `plain` yöntemi hiçbir
/// zaman üretilmez.
@immutable
class PkcePair {
  const PkcePair({required this.verifier, required this.challenge});

  /// RFC 7636 §4.1: `code_verifier` kriptografik olarak rastgele, yalnız
  /// `[A-Za-z0-9\-._~]` karakter kümesinden 43-128 karakter uzunluğunda bir
  /// dizedir. [generate] 32 bayt (256 bit) entropiyi base64url ile
  /// kodlayarak 43 karakterlik, dolgusuz (padding'siz) bir değer üretir —
  /// base64url alfabesi (`A-Za-z0-9-_`) zaten bu karakter kümesinin bir alt
  /// kümesidir, bu yüzden ek bir karakter filtrelemesi gerekmez.
  final String verifier;

  /// RFC 7636 §4.2: `code_challenge = BASE64URL-ENCODE(SHA256(ASCII(code_verifier)))`,
  /// dolgusuz.
  final String challenge;

  /// Yeni, kriptografik olarak güvenli rastgele bir [PkcePair] üretir.
  ///
  /// [random] yalnız testler için enjekte edilebilir (deterministik
  /// vektör doğrulaması); üretim kodu her zaman varsayılan
  /// `Random.secure()`'u kullanır — asla `Random()` (öngörülebilir,
  /// kriptografik olarak GÜVENSİZ) değil.
  factory PkcePair.generate({Random? random}) {
    final rng = random ?? Random.secure();
    final verifierBytes = List<int>.generate(32, (_) => rng.nextInt(256));
    final verifier = base64UrlEncode(verifierBytes).replaceAll('=', '');
    return PkcePair(
      verifier: verifier,
      challenge: pkceChallengeFromVerifier(verifier),
    );
  }
}

/// `code_verifier`'dan `code_challenge` (S256) türetir. [PkcePair.generate]
/// tarafından kullanılır; ayrıca RFC 7636 Ek B test vektörüne karşı
/// doğrudan test edilebilmesi için ayrı bir üst düzey fonksiyon olarak dışa
/// açılır.
String pkceChallengeFromVerifier(String verifier) {
  final digest = sha256.convert(ascii.encode(verifier));
  return base64UrlEncode(digest.bytes).replaceAll('=', '');
}
