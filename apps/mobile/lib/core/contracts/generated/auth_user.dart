// GENERATED — elle düzenleme; kaynak: packages/contracts/schema.json, üretici: tool/generate_contracts.dart
// Bu dosyayı elle düzenlemeyin; değişiklik gerekiyorsa
// packages/contracts/schema.json güncellenip codegen yeniden
// çalıştırılmalıdır (dart run tool/generate_contracts.dart).

/// Kaynak: `packages/contracts/schema.json` -> `$defs/AuthUser`.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.displayName,
    required this.email,
    required this.emailVerified,
    required this.role,
    this.avatarUrl,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final displayName = json['displayName'] as String;
    final email = json['email'] as String;
    final emailVerified = json['emailVerified'] as bool;
    final role = json['role'] as String;
    final avatarUrl = json['avatarUrl'] as String?;
    return AuthUser(
      id: id,
      displayName: displayName,
      email: email,
      emailVerified: emailVerified,
      role: role,
      avatarUrl: avatarUrl,
    );
  }

  /// Panelya user identifier. Provider subject identifiers are not exposed.
  final String id;
  final String displayName;
  final String email;
  final bool emailVerified;
  /// Bilinen değer kümesi: "reader" | "admin".
  final String role;
  final String? avatarUrl;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'email': email,
      'emailVerified': emailVerified,
      'role': role,
      'avatarUrl': avatarUrl,
    };
  }
}
