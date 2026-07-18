// GEÇİCİ ADAPTER: packages/contracts main'e gelince bu dosya ortak sözleşmeyle
// değiştirilecek (bkz. docs/mobile-handoff.md Ortaklık kuralları #3).

/// Bu istemcinin anladığı, `app/api/catalog`, `app/api/series/[slug]` ve
/// `app/api/series/[slug]/episodes/[episode]` route handler'larının bugün
/// döndürdüğü `schemaVersion` değeri.
///
/// Sunucu farklı bir sürüm dönerse (`SchemaVersionMismatchException`),
/// istemci sessizce yanlış alanlar okumak yerine açık bir hata fırlatır
/// (bkz. PLAN madde 5 — schemaVersion uyumsuzluğunda açık hata).
const String kSupportedSchemaVersion = '1.0';

/// `schemaVersion` alanı `kSupportedSchemaVersion` ile eşleşmiyorsa fırlatılır.
class SchemaVersionMismatchException implements Exception {
  const SchemaVersionMismatchException({
    required this.expected,
    required this.actual,
  });

  final String expected;
  final Object? actual;

  @override
  String toString() =>
      'SchemaVersionMismatchException: beklenen=$expected, gelen=$actual';
}

/// JSON gövdesindeki `schemaVersion` alanını doğrular. Eksik veya farklı bir
/// sürümde [SchemaVersionMismatchException] fırlatır.
void assertSupportedSchemaVersion(Map<String, dynamic> json) {
  final actual = json['schemaVersion'];
  if (actual != kSupportedSchemaVersion) {
    throw SchemaVersionMismatchException(
      expected: kSupportedSchemaVersion,
      actual: actual,
    );
  }
}
