import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/api/api_error_presenter.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/media_url.dart';
import '../../../core/config/app_config.dart';
import '../../../core/contracts/generated/generated.dart';
import '../../../shared/widgets/state_views.dart';
import 'reader_providers.dart';

/// Okuyucu ekranı (`/series/:slug/read/:episodeSlug`): kesintisiz dikey
/// panel scroll'u (ADR-019 — video pager değil). Faz 1'de panel metni
/// (scene/caption/dialogue) ve varsa panel görseli gösterilir; ilerleme
/// göstergesi ve gelişmiş görsel dil Faz 2'nin işidir.
class ReaderScreen extends ConsumerWidget {
  const ReaderScreen({
    super.key,
    required this.seriesSlug,
    required this.episodeSlug,
  });

  final String seriesSlug;
  final String episodeSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (seriesSlug: seriesSlug, episodeSlug: episodeSlug);
    final manifest = ref.watch(episodeManifestProvider(key));

    return Scaffold(
      appBar: AppBar(
        title: manifest.asData != null
            ? Text(manifest.asData!.value.episode.title)
            : const Text('Bölüm'),
      ),
      body: SafeArea(
        child: manifest.when(
          loading: () => const AppLoadingView(label: 'Bölüm yükleniyor'),
          error: (error, stackTrace) => AppErrorView(
            message: error is ApiException
                ? describeApiException(error)
                : 'Beklenmeyen bir hata oluştu.',
            onRetry: () => ref.invalidate(episodeManifestProvider(key)),
          ),
          data: (response) {
            if (response.episode.panels.isEmpty) {
              return const AppEmptyView(
                message: 'Bu bölümde henüz gösterilecek panel yok.',
              );
            }
            return _ReaderView(seriesSlug: seriesSlug, response: response);
          },
        ),
      ),
    );
  }
}

class _ReaderView extends ConsumerWidget {
  const _ReaderView({required this.seriesSlug, required this.response});

  final String seriesSlug;
  final EpisodeManifestResponse response;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final apiOrigin = ref.watch(appConfigProvider).apiOrigin;
    final episode = response.episode;
    final panels = episode.panels;
    // Üretilen DTO wire-faithful (düz/flattened olmayan) şekli izler: gezinme
    // bilgisi `response.previous`/`response.next` yerine
    // `response.navigation.previous`/`response.navigation.next` altındadır
    // (bkz. docs/mobile-handoff.md Ortaklık kuralları #3 — geçici adapter
    // kaldırıldı, tüketici kod artık gerçek JSON şeklini birebir izler).
    final previous = response.navigation.previous;
    final next = response.navigation.next;

    return ListView.separated(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.md),
      itemCount: panels.length + 2,
      separatorBuilder: (context, index) => SizedBox(height: tokens.spacing.md),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _EpisodeNavLink(
            label: previous == null
                ? 'Bu, serinin ilk bölümü.'
                : 'Önceki bölüm: Bölüm ${previous.number}',
            onTap: previous == null
                ? null
                : () => context.pushReplacement(
                    '/series/$seriesSlug/read/${previous.slug}',
                  ),
          );
        }
        if (index == panels.length + 1) {
          return _EpisodeNavLink(
            label: next == null
                ? 'Bu, serinin şu ana kadarki son bölümü.'
                : 'Sonraki bölüm: Bölüm ${next.number}',
            onTap: next == null
                ? null
                : () => context.pushReplacement(
                    '/series/$seriesSlug/read/${next.slug}',
                  ),
          );
        }
        return _PanelView(panel: panels[index - 1], apiOrigin: apiOrigin);
      },
    );
  }
}

class _PanelView extends StatelessWidget {
  const _PanelView({required this.panel, required this.apiOrigin});

  final StoryPanel panel;
  final String apiOrigin;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final image = panel.image;
    final imageUrl = image == null ? null : resolveMediaUrl(apiOrigin, image.src);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.md),
      child: Semantics(
        label: image?.alt ?? panel.scene,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(tokens.radii.md),
                child: AspectRatio(
                  aspectRatio: image!.width / image.height,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: tokens.colors.surface2,
                        alignment: Alignment.center,
                        child: CircularProgressIndicator(color: tokens.colors.mint),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: tokens.colors.surface2,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: tokens.colors.muted,
                      ),
                    ),
                  ),
                ),
              )
            else
              Container(
                padding: EdgeInsets.all(tokens.spacing.lg),
                decoration: BoxDecoration(
                  color: tokens.colors.surface2,
                  borderRadius: BorderRadius.circular(tokens.radii.md),
                  border: Border.all(color: tokens.colors.line),
                ),
                child: Text(panel.scene, style: tokens.typography.bodyLarge),
              ),
            if (panel.caption != null) ...[
              SizedBox(height: tokens.spacing.sm),
              Text(
                panel.caption!,
                style: tokens.typography.bodySmall.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (panel.dialogue != null) ...[
              SizedBox(height: tokens.spacing.xs),
              Text(panel.dialogue!, style: tokens.typography.bodyLarge),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bölüm geçiş bağlantısı. `onTap` `null` olduğunda (örn. serinin ilk/son
/// bölümü) devre dışı bir buton yerine bilgi metni gösterilir (ADR-010).
class _EpisodeNavLink extends StatelessWidget {
  const _EpisodeNavLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final content = Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.md),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: tokens.sizes.minTouchTarget),
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(
          vertical: tokens.spacing.sm,
          horizontal: tokens.spacing.md,
        ),
        decoration: BoxDecoration(
          color: onTap == null ? Colors.transparent : tokens.colors.surface3,
          borderRadius: BorderRadius.circular(tokens.radii.pill),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: tokens.typography.bodyMedium.copyWith(
            color: onTap == null ? tokens.colors.muted : tokens.colors.ink,
          ),
        ),
      ),
    );

    if (onTap == null) {
      return Semantics(label: label, child: content);
    }
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radii.pill),
        child: content,
      ),
    );
  }
}
