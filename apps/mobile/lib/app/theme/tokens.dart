import 'package:flutter/material.dart';

/// Panelya design tokens.
///
/// Kaynak: `docs/mobile-handoff.md` "Tasarım token'ları" tablosu, ki o da
/// web tarafındaki `app/globals.css` token'larını birebir aynalar. Yeni
/// veya bağımsız bir renk paleti oluşturulmaz; ekranlar bu dosyadaki
/// değerler dışında renk/spacing/tipografi hardcode etmez.
///
/// Tasarım değerleri ileride `packages/design-tokens` tek kaynağına
/// bağlanacak (bkz. docs/mobile-handoff.md, Ortaklık kuralları #4);
/// o zamana kadar bu dosya geçici tek kaynaktır.
///
/// Panelya koyu tema tek temadır (gece orman yeşili zemin); açık tema yok.
@immutable
class AppColors {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.ink,
    required this.muted,
    required this.line,
    required this.mint,
    required this.mintStrong,
    required this.coral,
  });

  /// Ana arka plan (koyu orman yeşili).
  final Color background;

  /// Ana yüzey.
  final Color surface;

  /// İkinci yüzey.
  final Color surface2;

  /// Üçüncü yüzey.
  final Color surface3;

  /// Ana metin.
  final Color ink;

  /// Soluk metin.
  final Color muted;

  /// Çizgi/kenarlık. Web'de `rgba(197,226,213,.14)`.
  final Color line;

  /// Ana vurgu.
  final Color mint;

  /// Güçlü vurgu.
  final Color mintStrong;

  /// Uyarı/ikincil vurgu.
  final Color coral;

  static const AppColors dark = AppColors(
    background: Color(0xFF07100E),
    surface: Color(0xFF0B1512),
    surface2: Color(0xFF101D19),
    surface3: Color(0xFF162520),
    ink: Color(0xFFF3F6F2),
    muted: Color(0xFF94A39D),
    line: Color.fromRGBO(197, 226, 213, 0.14),
    mint: Color(0xFF66E2AE),
    mintStrong: Color(0xFF35C98E),
    coral: Color(0xFFFF6F61),
  );
}

/// Type scale. Renkler token'lardan sabitlenir; ekranlar kendi TextStyle
/// renk/boyutunu tanımlamaz.
@immutable
class AppTypography {
  const AppTypography({
    required this.displayLarge,
    required this.titleLarge,
    required this.titleMedium,
    required this.bodyLarge,
    required this.bodyMedium,
    required this.bodySmall,
    required this.label,
  });

  final TextStyle displayLarge;
  final TextStyle titleLarge;
  final TextStyle titleMedium;
  final TextStyle bodyLarge;
  final TextStyle bodyMedium;
  final TextStyle bodySmall;
  final TextStyle label;

  // `const` değil: renkler `AppColors.dark`'ın instance alanlarını
  // referans alıyor.
  static final AppTypography standard = AppTypography(
    displayLarge: TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w700,
      height: 1.15,
      color: AppColors.dark.ink,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      height: 1.2,
      color: AppColors.dark.ink,
    ),
    titleMedium: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      height: 1.25,
      color: AppColors.dark.ink,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: AppColors.dark.ink,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: AppColors.dark.muted,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.3,
      color: AppColors.dark.muted,
    ),
    label: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 1.2,
      letterSpacing: 0.2,
      color: AppColors.dark.ink,
    ),
  );
}

/// 4-pt spacing skalası.
@immutable
class AppSpacing {
  const AppSpacing({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.xxl,
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;

  static const AppSpacing standard = AppSpacing(
    xs: 4,
    sm: 8,
    md: 16,
    lg: 24,
    xl: 32,
    xxl: 48,
  );
}

/// Köşe yarıçapları.
@immutable
class AppRadii {
  const AppRadii({
    required this.sm,
    required this.md,
    required this.lg,
    required this.pill,
  });

  final double sm;
  final double md;
  final double lg;
  final double pill;

  static const AppRadii standard = AppRadii(sm: 8, md: 14, lg: 24, pill: 999);
}

/// Dokunma hedefi minimumu (44x44) burada tek kaynak olarak tutulur.
@immutable
class AppSizes {
  const AppSizes({required this.minTouchTarget});

  final double minTouchTarget;

  static const AppSizes standard = AppSizes(minTouchTarget: 44);
}

/// Animasyon süreleri.
@immutable
class AppDurations {
  const AppDurations({
    required this.fast,
    required this.medium,
    required this.slow,
  });

  final Duration fast;
  final Duration medium;
  final Duration slow;

  static const AppDurations standard = AppDurations(
    fast: Duration(milliseconds: 150),
    medium: Duration(milliseconds: 300),
    slow: Duration(milliseconds: 500),
  );
}

/// Tüm token'ları toplayan tek [ThemeExtension]. Widget'lar renk, spacing,
/// tipografi, radii ve boyutları yalnız bu sınıf üzerinden okur; hiçbir
/// zaman hardcode etmez.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.colors,
    required this.typography,
    required this.spacing,
    required this.radii,
    required this.sizes,
    required this.durations,
  });

  final AppColors colors;
  final AppTypography typography;
  final AppSpacing spacing;
  final AppRadii radii;
  final AppSizes sizes;
  final AppDurations durations;

  // `const` değil: `AppTypography.standard`'a bağımlı.
  static final AppTokens dark = AppTokens(
    colors: AppColors.dark,
    typography: AppTypography.standard,
    spacing: AppSpacing.standard,
    radii: AppRadii.standard,
    sizes: AppSizes.standard,
    durations: AppDurations.standard,
  );

  @override
  AppTokens copyWith({
    AppColors? colors,
    AppTypography? typography,
    AppSpacing? spacing,
    AppRadii? radii,
    AppSizes? sizes,
    AppDurations? durations,
  }) {
    return AppTokens(
      colors: colors ?? this.colors,
      typography: typography ?? this.typography,
      spacing: spacing ?? this.spacing,
      radii: radii ?? this.radii,
      sizes: sizes ?? this.sizes,
      durations: durations ?? this.durations,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    // Panelya'da tek (koyu) tema var; interpolasyon gerekmiyor.
    if (other is! AppTokens) return this;
    return t < 0.5 ? this : other;
  }
}

/// Kolay erişim: `context.tokens.colors.background` vb.
extension AppTokensX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
