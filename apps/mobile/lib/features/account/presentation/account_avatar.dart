import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/contracts/generated/generated.dart';

/// "Hesabım" ekranlarında tekrar eden avatar gösterimi: gerçek bir
/// `avatarUrl` varsa görsel, yoksa görünen adın baş harflerinden oluşan
/// bir yer tutucu.
///
/// Bilerek tamamen NON-INTERACTIVE'tir (tıklanamaz, `InkWell`/`onTap`
/// yok) — avatar DÜZENLEME şu an desteklenmiyor (bkz. `pubspec.yaml`,
/// image-picker benzeri bir bağımlılık yok); bu widget bunu ASLA
/// çalışıyormuş gibi göstermez (ADR-010), yalnız gösterir. Düzenleme
/// affordansı `profile_screen.dart`da ayrı, açıkça non-interactive bir
/// açıklama metniyle ele alınır.
class AccountAvatar extends StatelessWidget {
  const AccountAvatar({super.key, required this.user, this.radius = 36});

  final AuthUser user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return CircleAvatar(
      radius: radius,
      backgroundColor: tokens.colors.surface2,
      backgroundImage: user.avatarUrl != null
          ? NetworkImage(user.avatarUrl!)
          : null,
      child: user.avatarUrl == null
          ? Text(
              _accountInitials(user.displayName),
              style: tokens.typography.titleLarge,
            )
          : null,
    );
  }
}

String _accountInitials(String displayName) {
  final parts = displayName
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  final first = parts.first.substring(0, 1);
  final last = parts.length > 1 ? parts.last.substring(0, 1) : '';
  return (first + last).toUpperCase();
}
