import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_args.dart';
import '../../../app/theme/tokens.dart';

/// Ana sayfanın en üstündeki açılır tür dizini (bkz. PLAN Görev 4,
/// docs/mobile-handoff.md "Güncel web bilgi mimarisinin Flutter karşılığı"
/// #2). Kontrolün TEK görünür içeriği "Türler" etiketi + yön okudur; kapalıyken
/// aşağı (`Icons.keyboard_arrow_down`), açıkken yukarı
/// (`Icons.keyboard_arrow_up`) bakar. Genişletme durumu tıklamayla değişir;
/// başlangıçta kapalı gelir (bir disclosure kontrolü olarak, ana sayfanın asıl
/// içeriği — hero, devam et, yeni seriler/bölümler — ilk açılışta hemen
/// görünür kalır).
///
/// [genres] `discoveryResponse.genres`'ten (bkz.
/// `core/contracts/generated/discovery_response.dart`) doğrudan gelir;
/// istemci türetmez/sıralamaz — sunucu zaten `tr` locale'e göre sıralı
/// döner (bkz. web `listPublishedGenres` -> `localeCompare(a,b,"tr")`).
/// Bir tür seçilince `/catalog` rotasına [CatalogRouteArgs.initialGenre] ile
/// o tür seçili şekilde gidilir.
class GenreDisclosure extends StatefulWidget {
  const GenreDisclosure({super.key, required this.genres});

  final List<String> genres;

  @override
  State<GenreDisclosure> createState() => _GenreDisclosureState();
}

class _GenreDisclosureState extends State<GenreDisclosure> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    // API `genres` boş dönerse (örn. henüz hiç yayınlanmış seri yok)
    // gösterilecek bir tür yoktur; çalışmayan/boş bir disclosure kontrolü
    // göstermek yerine widget'ın kendisi hiç render edilmez (ADR-010).
    if (widget.genres.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          expanded: _expanded,
          label: 'Türler',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const ValueKey('genre-disclosure-toggle'),
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(tokens.radii.md),
              child: Container(
                constraints: BoxConstraints(
                  minHeight: tokens.sizes.minTouchTarget,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.md,
                  vertical: tokens.spacing.sm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Türler', style: tokens.typography.titleMedium),
                    SizedBox(width: tokens.spacing.xs),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: tokens.colors.ink,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.md,
              0,
              tokens.spacing.md,
              tokens.spacing.sm,
            ),
            child: Wrap(
              spacing: tokens.spacing.sm,
              runSpacing: tokens.spacing.sm,
              children: widget.genres
                  .map(
                    (genre) => _GenreDisclosureChip(
                      key: ValueKey('genre-disclosure-chip-$genre'),
                      genre: genre,
                      onTap: () => context.push(
                        '/catalog',
                        extra: CatalogRouteArgs(initialGenre: genre),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _GenreDisclosureChip extends StatelessWidget {
  const _GenreDisclosureChip({
    super.key,
    required this.genre,
    required this.onTap,
  });

  final String genre;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Semantics(
      button: true,
      label: '$genre türünü katalogda göster',
      child: Material(
        color: tokens.colors.surface2,
        borderRadius: BorderRadius.circular(tokens.radii.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.radii.pill),
          child: Container(
            constraints: BoxConstraints(minHeight: tokens.sizes.minTouchTarget),
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.md),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(tokens.radii.pill),
              border: Border.all(color: tokens.colors.line),
            ),
            child: Text(
              genre,
              style: tokens.typography.label.copyWith(color: tokens.colors.ink),
            ),
          ),
        ),
      ),
    );
  }
}
