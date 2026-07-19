// GENERATED — elle düzenleme; kaynak: packages/contracts/schema.json, üretici: tool/generate_contracts.dart
// Bu dosyayı elle düzenlemeyin; değişiklik gerekiyorsa
// packages/contracts/schema.json güncellenip codegen yeniden
// çalıştırılmalıdır (dart run tool/generate_contracts.dart).

/// Kaynak: `packages/contracts/schema.json` -> `$defs/ErrorResponse`.
class ErrorResponse {
  const ErrorResponse({
    required this.error,
  });

  factory ErrorResponse.fromJson(Map<String, dynamic> json) {
    final error = json['error'] as String;
    return ErrorResponse(
      error: error,
    );
  }

  /// Bilinen değer kümesi: "series_not_found" | "episode_not_found".
  final String error;

  Map<String, dynamic> toJson() {
    return {
      'error': error,
    };
  }
}
