import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// Faz 1'in dört zorunlu ekran durumundan (loading/empty/error/success)
/// ilk üçü için ortak, token tabanlı widget'lar (bkz.
/// docs/mobile-handoff.md Kalite çizgisi).

/// Yükleniyor durumu.
class AppLoadingView extends StatelessWidget {
  const AppLoadingView({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Center(
      child: Semantics(
        label: label ?? 'Yükleniyor',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: tokens.colors.mint),
            if (label != null) ...[
              SizedBox(height: tokens.spacing.md),
              Text(label!, style: tokens.typography.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

/// Yeniden denenebilir hata durumu. `onRetry` her zaman çalışan bir
/// aksiyona bağlanır (ADR-010); çalışmayan bir buton gösterilmez.
class AppErrorView extends StatelessWidget {
  const AppErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              color: tokens.colors.coral,
              size: 40,
              semanticLabel: 'Hata',
            ),
            SizedBox(height: tokens.spacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: tokens.typography.bodyMedium.copyWith(
                color: tokens.colors.ink,
              ),
            ),
            if (onRetry != null) ...[
              SizedBox(height: tokens.spacing.lg),
              // Sabit `SizedBox(height: minTouchTarget)` yerine tema
              // `FilledButtonThemeData.minimumSize` (44 px alt sınır)
              // uygulanır; büyük yazı tipinde buton gerekirse büyür (bkz.
              // PLAN Görev B.2 — buton etiketi kırpılmaz).
              FilledButton(
                onPressed: onRetry,
                child: const Text('Tekrar dene'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Boş durum: liste yüklendi ama gösterilecek içerik yok.
class AppEmptyView extends StatelessWidget {
  const AppEmptyView({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: tokens.typography.bodyMedium,
        ),
      ),
    );
  }
}
