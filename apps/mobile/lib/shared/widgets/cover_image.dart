import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../app/theme/tone_gradients.dart';
import '../../core/api/media_url.dart';
import '../../core/api/media_variant_selector.dart';
import '../../core/config/app_config.dart';
import '../../core/contracts/generated/generated.dart';

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
/// - `tone` verilirse (bkz. `SeriesSummary.tone`/`SeriesMetadata.tone`) kapak
///   yoksa/yüklenirken/hata durumunda düz `surface3` yerine web'deki
///   `.poster--<tone>` gradyanı kullanılır (bkz. `tone_gradients.dart`).
///   `tone` `null` veya `PanelTone.unknown` ise davranış değişmez.
/// - `variants` verilirse (bkz. üretilen `SeriesSummary.coverImageVariants`/
///   `SeriesMetadata.coverImageVariants`, `lib/core/contracts/generated/`)
///   widget kendi düzen kısıtlarını (`LayoutBuilder`) ve cihaz piksel oranını
///   (`MediaQuery.devicePixelRatioOf`) kullanarak gerçek görüntüleme
///   genişliğini hesaplar, `selectMediaVariant` (bkz.
///   `core/api/media_variant_selector.dart`) ile ihtiyacı GEREKSİZ AŞMAYAN en
///   uygun varyantı seçer ve onun `src`'ini yükler. `variants` `null`/boşsa
///   ya da seçici `null` dönerse (örn. düzen kısıtı henüz bilinmiyorsa)
///   davranış birebir `src` alanına düşer — canlı yerel API şu an varyant
///   DÖNDÜRMEDİĞİ için bu geri-düşüş yolu tüm gerçek çalıştırmalarda
///   kullanılan tek yoldur (bkz. görev bağlamı); varyant seçim yolu
///   `packages/contracts` fixture'ları ve widget testleriyle doğrulanır.
class CoverImage extends ConsumerWidget {
  const CoverImage({
    super.key,
    required this.src,
    required this.semanticLabel,
    this.position,
    this.fit = BoxFit.cover,
    this.tone,
    this.showDecorativeIcon = true,
    this.variants,
  });

  /// Mutlak veya web origin'ine göre relative görsel yolu (varsa). `variants`
  /// boş/null olduğunda veya seçici bir varyant döndürmediğinde yüklenen
  /// tek yoldur.
  final String? src;

  /// Ekran okuyucular için görsel açıklaması.
  final String semanticLabel;

  /// `"50% 96%"` gibi CSS `background-position` değeri (varsa).
  final String? position;

  final BoxFit fit;

  /// Serinin tonu (varsa); placeholder gradyanı için kullanılır.
  final PanelTone? tone;

  /// Ready responsive kapak derivatives'i (bkz. üretilen
  /// `SeriesSummary.coverImageVariants`/`SeriesMetadata.coverImageVariants`).
  /// `null`/boş ise mevcut `src` davranışı birebir korunur.
  final List<PublicMediaVariant>? variants;

  /// Kapak yokken ortadaki dekoratif `Icons.auto_stories_outlined` ikonunun
  /// gösterilip gösterilmeyeceği (bkz. QA bulgusu — keşif hero'sunda büyük
  /// yazı tipinde durum/tür chip'leri ikinci satıra sarınca bu SALT
  /// DEKORATİF ikon (Semantics dışı) içerik bloğuyla çakışıyordu). Varsayılan
  /// `true` — ızgara kartı ve seri detay çağrıları mevcut görünümü korur;
  /// yalnız çakışma riski olan çağıran yer (keşif hero'su) `false` geçer.
  /// Yükleme spinner'ını ve hata ikonunu ETKİLEMEZ — onlar bilgilendirici,
  /// dekoratif değildir.
  final bool showDecorativeIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final source = src;
    final gradient = tone == null ? null : posterGradientForTone(tone!);

    if (source == null || source.isEmpty) {
      return _CoverPlaceholder(
        tokens: tokens,
        semanticLabel: semanticLabel,
        gradient: gradient,
        showDecorativeIcon: showDecorativeIcon,
      );
    }

    final apiOrigin = ref.watch(appConfigProvider).apiOrigin;
    final variantList = variants;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Varyant yoksa (ya da düzen kısıtı henüz sınırsızsa, örn. bir
        // `Row`/`Column` içinde `Expanded` olmadan) doğrudan `source`
        // kullanılır — mevcut davranış birebir korunur.
        var resolvedSource = source;
        if (variantList != null &&
            variantList.isNotEmpty &&
            constraints.maxWidth.isFinite &&
            constraints.maxWidth > 0) {
          final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
          final targetWidthPx = constraints.maxWidth * devicePixelRatio;
          final selected = selectMediaVariant(variantList, targetWidthPx);
          if (selected != null) {
            resolvedSource = selected.src;
          }
        }

        final url = resolveMediaUrl(apiOrigin, resolvedSource);

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
                gradient: gradient,
              );
            },
            errorBuilder: (context, error, stackTrace) => _CoverPlaceholder(
              tokens: tokens,
              semanticLabel: semanticLabel,
              isError: true,
              gradient: gradient,
            ),
          ),
        );
      },
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({
    required this.tokens,
    required this.semanticLabel,
    this.loading = false,
    this.isError = false,
    this.gradient,
    this.showDecorativeIcon = true,
  });

  final AppTokens tokens;
  final String semanticLabel;
  final bool loading;
  final bool isError;

  /// `null` ise (ton yok/`unknown`) mevcut düz `surface3` rengi kullanılır.
  final LinearGradient? gradient;

  /// bkz. `CoverImage.showDecorativeIcon` doc yorumu. Yalnız normal (yükleme/
  /// hata dışı) kapaksız durumdaki dekoratif ikonu etkiler.
  final bool showDecorativeIcon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: isError
          ? '$semanticLabel. Kapak görseli yüklenemedi.'
          : semanticLabel,
      child: Container(
        decoration: BoxDecoration(
          color: gradient == null ? tokens.colors.surface3 : null,
          gradient: gradient,
        ),
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
            : isError
            ? Icon(Icons.broken_image_outlined, color: tokens.colors.muted)
            : showDecorativeIcon
            ? Icon(Icons.auto_stories_outlined, color: tokens.colors.muted)
            : const SizedBox.shrink(),
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
