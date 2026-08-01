// GENERATED — elle düzenleme; kaynak: packages/contracts/schema.json, üretici: tool/generate_contracts.dart
// Bu dosyayı elle düzenlemeyin; değişiklik gerekiyorsa
// packages/contracts/schema.json güncellenip codegen yeniden
// çalıştırılmalıdır (dart run tool/generate_contracts.dart).
//
// `constant_identifier_names` KAPALI: üretilen enum üyeleri şemadaki
// JSON değerlerini (ör. `provider_managed`, `auth_identity`) BİREBİR
// yansıtır. lowerCamelCase'e çevirmek, `fromJson`/`toJson`
// eşlemesini şemadan görsel olarak ayırır ve sessiz bir eşleme
// hatası riski yaratır; sözleşmeyle bire bir aynı kalması bilinçli
// bir tercihtir.
// ignore_for_file: constant_identifier_names

import 'account_action_capability.dart';

/// Kaynak: `packages/contracts/schema.json` -> `$defs/AccountCapabilities`.
class AccountCapabilities {
  const AccountCapabilities({
    required this.profileEditing,
    required this.avatarEditing,
    required this.emailChange,
    required this.passwordAction,
    required this.sessionManagement,
    required this.blockedAccounts,
    required this.accountDeletion,
  });

  factory AccountCapabilities.fromJson(Map<String, dynamic> json) {
    final profileEditing = AccountActionCapability.fromJson(json['profileEditing'] as String);
    final avatarEditing = AccountActionCapability.fromJson(json['avatarEditing'] as String);
    final emailChange = AccountActionCapability.fromJson(json['emailChange'] as String);
    final passwordAction = AccountActionCapability.fromJson(json['passwordAction'] as String);
    final sessionManagement = AccountActionCapability.fromJson(json['sessionManagement'] as String);
    final blockedAccounts = AccountActionCapability.fromJson(json['blockedAccounts'] as String);
    final accountDeletion = AccountActionCapability.fromJson(json['accountDeletion'] as String);
    return AccountCapabilities(
      profileEditing: profileEditing,
      avatarEditing: avatarEditing,
      emailChange: emailChange,
      passwordAction: passwordAction,
      sessionManagement: sessionManagement,
      blockedAccounts: blockedAccounts,
      accountDeletion: accountDeletion,
    );
  }

  final AccountActionCapability profileEditing;
  final AccountActionCapability avatarEditing;
  final AccountActionCapability emailChange;
  final AccountActionCapability passwordAction;
  final AccountActionCapability sessionManagement;
  final AccountActionCapability blockedAccounts;
  final AccountActionCapability accountDeletion;

  Map<String, dynamic> toJson() {
    return {
      'profileEditing': profileEditing.toJson(),
      'avatarEditing': avatarEditing.toJson(),
      'emailChange': emailChange.toJson(),
      'passwordAction': passwordAction.toJson(),
      'sessionManagement': sessionManagement.toJson(),
      'blockedAccounts': blockedAccounts.toJson(),
      'accountDeletion': accountDeletion.toJson(),
    };
  }
}
