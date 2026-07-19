import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../core/api/media_url.dart';
import '../../core/config/app_config.dart';

/// Seri kapağı/poster görseli için tek ortak widget. Keşif kartları, keşif
/// hero'su ve seri detay ekranı bu widget'ı kullanır; her biri kendi
/// yükleme/hata placeholder mantığını tekrar etmez.
///
/// - `src` `null`/boş ise doğrudan placeholder gösterilir (kapağı olmayan
///   seriler için; kaynak: üretilen `SeriesMetadata.coverImage`/
///   `SeriesSummary.coverImage` opsiyoneldir, bkz.
///   `lib/core/contracts/generated/`).
/// - `src` relative ise (`app/data/catalog.ts`'teki gibi `/images/...`)
///   `resolveMediaUrl` ile `apiOrigin` ile birleştirilir.
/// - `position` web tarafındaki CSS `background-position` (`"50% 96%"` gibi)
///   değeriyle aynı sözleşimi (`coverPosition`) kullanır; en yakın Flutter
///   karşılığı olan [Alignment]'a çevrilir.
/// - Yükleme ve hata durumları animasyonsuzdur (bkz. `disableAnimations`
///   uyumu — burada zaten hiçbir geçiş animasyonu kullanılmaz).
class CoverImage extends ConsumerWidget {
  const CoverImage({
    super.key,
    required this.src,
    required this.semanticLabel,
    this.position,
    this.fit = BoxFit.cover,
  });

  /// Mutlak veya web origin'ine göre relative görsel yolu (varsa).
  final String? src;

  /// Ekran okuyucular için görsel açıklaması.
  final String semanticLabel;

  /// `"50% 96%"` gibi CSS `background-position` değeri (varsa).
  final String? position;

  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final source = src;

    if (source == null || source.isEmpty) {
      return _CoverPlaceholder(tokens: tokens, semanticLabel: semanticLabel);
    }

    final apiOrigin = ref.watch(appConfigProvider).apiOrigin;
    final url = resolveMediaUrl(apiOrigin, source);

    return Semantics(
      image: true,
      label: semanticLabel,
      child: Image.network(
        url,
        fit: fit,
        alignment: parseCoverAlignment(position),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _CoverPlaceholder(
            tokens: tokens,
            semanticLabel: semanticLabel,
            loading: true,
          );
        },
        errorBuilder: (context, error, stackTrace) => _CoverPlaceholder(
          tokens: tokens,
          semanticLabel: semanticLabel,
          isError: true,
        ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({
    required this.tokens,
    required this.semanticLabel,
    this.loading = false,
    this.isError = false,
  });

  final AppTokens tokens;
  final String semanticLabel;
  final bool loading;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: isError
          ? '$semanticLabel. Kapak görseli yüklenemedi.'
          : semanticLabel,
      child: Container(
        color: tokens.colors.surface3,
        alignment: Alignment.center,
        child: loading
            ? SizedBox(
                width: tokens.spacing.lg,
                height: tokens.spacing.lg,
                child: CircularProgressIndicator(
                  color: tokens.colors.mint,
                  strokeWidth: 2,
                ),
              )
            : Icon(
                isError
                    ? Icons.broken_image_outlined
                    : Icons.auto_stories_outlined,
                color: tokens.colors.muted,
              ),
      ),
    );
  }
}

/// `"50% 96%"` gibi bir CSS `background-position` değerini en yakın
/// [Alignment]'a çevirir. Ayrıştırılamazsa [Alignment.center] döner.
Alignment parseCoverAlignment(String? coverPosition) {
  if (coverPosition == null) return Alignment.center;
  final parts = coverPosition.trim().split(RegExp(r'\s+'));
  if (parts.length != 2) return Alignment.center;
  final x = _parsePercent(parts[0]);
  final y = _parsePercent(parts[1]);
  if (x == null || y == null) return Alignment.center;
  return Alignment(x * 2 - 1, y * 2 - 1);
}

double? _parsePercent(String token) {
  if (!token.endsWith('%')) return null;
  final value = double.tryParse(token.substring(0, token.length - 1));
  if (value == null) return null;
  return value.clamp(0, 100) / 100;
}
