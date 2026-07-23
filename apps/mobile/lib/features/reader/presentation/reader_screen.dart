import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/theme/tone_gradients.dart';
import '../../../core/api/api_error_presenter.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/media_url.dart';
import '../../../core/api/media_variant_selector.dart';
import '../../../core/config/app_config.dart';
import '../../../core/contracts/generated/generated.dart';
import '../../../features/progress/presentation/reading_progress_providers.dart';
import '../../../shared/layout/content_max_width.dart';
import '../../../shared/widgets/home_button.dart';
import '../../../shared/widgets/state_views.dart';
import 'reader_providers.dart';

/// Okuyucu ekranı (`/series/:slug/read/:episodeSlug`): kesintisiz dikey
/// panel scroll'u (ADR-019 — video pager değil). Panel görselleri
/// boşluksuz art arda dizilir; metin (caption/dialogue) görselden ayrı,
/// okunabilir bir katman olarak görselin hemen altında yer alır (ADR-016).
/// Bölüm geçişleri (önceki/sonraki/seriye dönüş) hem üst chrome'da (AppBar)
/// hem de bölüm sonunda (bkz. [_ReaderEndNav]) erişilebilirdir.
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

    return manifest.when(
      loading: () => _ReaderChromeScaffold(
        seriesSlug: seriesSlug,
        body: const AppLoadingView(label: 'Bölüm yükleniyor'),
      ),
      error: (error, stackTrace) => _ReaderChromeScaffold(
        seriesSlug: seriesSlug,
        body: AppErrorView(
          message: error is ApiException
              ? describeApiException(error)
              : 'Beklenmeyen bir hata oluştu.',
          onRetry: () => ref.invalidate(episodeManifestProvider(key)),
        ),
      ),
      data: (response) =>
          _ReaderSuccessScaffold(seriesSlug: seriesSlug, response: response),
    );
  }
}

/// Yükleniyor/hata durumlarında kullanılan minimal chrome. Manifest henüz
/// (veya hiç) gelmediği için önceki/sonraki bölüm bilgisi yoktur; ADR-010
/// gereği olmayan bir aksiyon buton olarak gösterilmez, yalnız seriye dönüş
/// sunulur (her zaman çalışan tek aksiyon).
class _ReaderChromeScaffold extends StatelessWidget {
  const _ReaderChromeScaffold({required this.seriesSlug, required this.body});

  final String seriesSlug;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        leading: _SeriesReturnButton(seriesSlug: seriesSlug),
        title: const Text('Bölüm'),
        actions: const [HomeButton()],
      ),
      body: SafeArea(child: body),
    );
  }
}

class _SeriesReturnButton extends StatelessWidget {
  const _SeriesReturnButton({required this.seriesSlug});

  final String seriesSlug;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      tooltip: 'Seriye dön',
      onPressed: () => _returnToSeries(context, seriesSlug),
    );
  }
}

/// Okuyucudan seriye dönüş: yığında gerçekten önceki bir sayfa varsa (normal
/// akış — seri ekranından `push()` ile buraya girildi) gerçek bir `pop()`
/// yapılır; bu, sistem geri tuşu/kaydırmasıyla BİREBİR aynı sonucu verir ve
/// altındaki yığını (seri, keşif, katalog — nereden gelindiyse) korur.
/// `context.go(...)` (eski davranış) bunun yerine yığını yeniden kurar ve
/// altındaki geçmişi kaybettirirdi — kullanıcı şikayetinin kök nedeni buydu.
///
/// Yığında hiçbir şey yoksa (`canPop()` false — örn.
/// `panelya://series/x/read/y` deep-link ile doğrudan buraya girildi, bkz.
/// `app/router/deep_link.dart`) `pop()` çağrılamaz; bu durumda mevcut
/// güvenli düşüş korunur ve seri sayfasına `go()` ile gidilir (ADR-010 —
/// gidecek "geri" yoksa en azından seriye götür, boş bir davranış
/// bırakılmaz).
void _returnToSeries(BuildContext context, String seriesSlug) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/series/$seriesSlug');
  }
}

/// Bölüm manifesti başarıyla geldikten sonraki okuyucu kabuğu. Scroll
/// konumunu izleyip ince ilerleme çizgisini besleyen [ScrollController] ve
/// [ValueNotifier] burada (state'te) yaşar; bu yüzden `ConsumerStatefulWidget`
/// olarak kurulur (AppBar'ın altındaki ilerleme çizgisi ve gövde scroll'u
/// aynı controller'ı paylaşır).
class _ReaderSuccessScaffold extends ConsumerStatefulWidget {
  const _ReaderSuccessScaffold({
    required this.seriesSlug,
    required this.response,
  });

  final String seriesSlug;
  final EpisodeManifestResponse response;

  @override
  ConsumerState<_ReaderSuccessScaffold> createState() =>
      _ReaderSuccessScaffoldState();
}

class _ReaderSuccessScaffoldState
    extends ConsumerState<_ReaderSuccessScaffold> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);

  /// Bu bölüm için "bitti" kaydı en fazla bir kez yazılır (bkz.
  /// [_maybeRecordCompletion]) — tekrar tekrar scroll edip sonuna gelmek
  /// depolamaya gereksiz yazma yapmamalı.
  bool _completionRecorded = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    // Bölüm açıldığında cihaz-yerel ilerleme kaydı yazılır (bkz. PLAN
    // "kaldığın yerden devam et" madde 1). `ReaderScreen` bölüm
    // değiştiğinde (`context.go`) yeniden oluşturulan bir rota olduğundan
    // bu `initState` her bölüm geçişinde tazelenir.
    //
    // Bu, bir kare sonrası `addPostFrameCallback` içinde yapılır: hem yazma
    // hem de aşağıdaki `ref.invalidate` çağrıları henüz build aşamasında
    // olan `ReaderScreen`/üst widget ağacını hemen etkileyebilir; build
    // sürerken senkron `ref.invalidate` "setState()/markNeedsBuild() called
    // during build" hatası fırlatır (Flutter/Riverpod, bir descendant'ın
    // build'i sürerken başka provider'ları kirli işaretlemeyi build
    // AŞAMASI bittikten sonraya erteler).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final response = widget.response;
      ref
          .read(readingProgressRepositoryProvider)
          .recordEpisodeOpened(
            seriesSlug: widget.seriesSlug,
            seriesTitle: response.series.title,
            episodeSlug: response.episode.slug,
            episodeNumber: response.episode.number,
          );
      _invalidateProgressProviders();

      // İçerik zaten viewport'a sığıyorsa (kısa bölüm) hiçbir scroll olayı
      // hiç tetiklenmeyebilir; bu yüzden aynı ilk karede bir kez de
      // "sonuna kadar okundu" kontrolü yapılır.
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      _maybeRecordCompletion(
        maxExtent: position.maxScrollExtent,
        pixels: position.pixels,
      );
    });
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final maxExtent = position.maxScrollExtent;
    final value = maxExtent <= 0
        ? 0.0
        : (position.pixels / maxExtent).clamp(0.0, 1.0);
    _progress.value = value;
    _maybeRecordCompletion(maxExtent: maxExtent, pixels: position.pixels);
  }

  /// Bölüm sonuna scroll edilince (veya içerik zaten tamamı görünür
  /// olduğundan hiç scroll gerekmiyorsa) "bitti" kaydını yazar; varsa
  /// sonraki bölüm devam hedefi olur (bkz.
  /// `LocalReadingProgressRepository.recordEpisodeCompleted`).
  void _maybeRecordCompletion({
    required double maxExtent,
    required double pixels,
  }) {
    if (_completionRecorded) return;
    final reachedEnd = maxExtent <= 0 || pixels >= maxExtent - 1;
    if (!reachedEnd) return;
    _completionRecorded = true;

    final response = widget.response;
    final next = response.navigation.next;
    ref
        .read(readingProgressRepositoryProvider)
        .recordEpisodeCompleted(
          seriesSlug: widget.seriesSlug,
          seriesTitle: response.series.title,
          episodeSlug: response.episode.slug,
          episodeNumber: response.episode.number,
          nextEpisodeSlug: next?.slug,
          nextEpisodeNumber: next?.number,
        );
    _invalidateProgressProviders();
  }

  /// Seri detay ve keşif ekranları ilerleme provider'larını yalnız
  /// `ref.watch` ile okur (bkz. `reading_progress_providers.dart`); bu
  /// provider'lar senkron olduğu için bir yazımdan sonra elle
  /// `invalidate` edilmezlerse, o ekranlara geri dönüldüğünde (aynı widget
  /// örneği korunuyorsa) bayat değer görünmeye devam eder.
  void _invalidateProgressProviders() {
    ref.invalidate(readingProgressForSeriesProvider(widget.seriesSlug));
    ref.invalidate(mostRecentReadingProgressProvider);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final episode = widget.response.episode;
    final navigation = widget.response.navigation;

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: _ReaderAppBar(
        seriesSlug: widget.seriesSlug,
        episodeNumber: episode.number,
        previous: navigation.previous,
        next: navigation.next,
        progress: _progress,
      ),
      body: SafeArea(
        child: episode.panels.isEmpty
            ? const AppEmptyView(
                message: 'Bu bölümde henüz gösterilecek panel yok.',
              )
            : _ReaderPanelList(
                seriesSlug: widget.seriesSlug,
                seriesTitle: widget.response.series.title,
                episode: episode,
                navigation: navigation,
                scrollController: _scrollController,
              ),
      ),
    );
  }
}

/// Üst chrome: sade bir AppBar (seriye dönüş + bölüm no'su) ve varsa
/// önceki/sonraki bölüm ikon butonları — olmayan yön hiç render edilmez
/// (ADR-010). Hemen altında ince, token renkli bir ilerleme çizgisi
/// (bkz. [_ReaderProgressBar]) yer alır.
class _ReaderAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ReaderAppBar({
    required this.seriesSlug,
    required this.episodeNumber,
    required this.previous,
    required this.next,
    required this.progress,
  });

  final String seriesSlug;
  final int episodeNumber;
  final EpisodeNavigationRef? previous;
  final EpisodeNavigationRef? next;
  final ValueListenable<double> progress;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 3);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: _SeriesReturnButton(seriesSlug: seriesSlug),
      title: Text('Bölüm $episodeNumber'),
      actions: [
        if (previous != null)
          IconButton(
            icon: const Icon(Icons.skip_previous_rounded),
            tooltip: 'Önceki bölüm: Bölüm ${previous!.number}',
            onPressed: () => context.pushReplacement(
              '/series/$seriesSlug/read/${previous!.slug}',
            ),
          ),
        if (next != null)
          IconButton(
            icon: const Icon(Icons.skip_next_rounded),
            tooltip: 'Sonraki bölüm: Bölüm ${next!.number}',
            onPressed: () => context.pushReplacement(
              '/series/$seriesSlug/read/${next!.slug}',
            ),
          ),
        const HomeButton(),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(3),
        child: _ReaderProgressBar(progress: progress),
      ),
    );
  }
}

/// Scroll konumuna bağlı ince ilerleme çizgisi. Salt dekoratif olduğu için
/// (bkz. web tarafındaki `aria-hidden="true"` eşdeğeri) erişilebilirlik
/// ağacından hariç tutulur; ekran okuyucu kullanıcıları için bilgi taşımaz.
class _ReaderProgressBar extends StatelessWidget {
  const _ReaderProgressBar({required this.progress});

  final ValueListenable<double> progress;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ExcludeSemantics(
      child: SizedBox(
        height: 3,
        child: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (context, value, _) {
            return Container(
              color: tokens.colors.line,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: value,
                heightFactor: 1,
                child: Container(color: tokens.colors.mint),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Panel listesi: boşluksuz dikey akış (production-bible.md §1). Her öğe
/// tam genişlik ve bitişiktir; aralarında `ListView.separated` gibi bir
/// ayırıcı boşluk YOKTUR. `ListView.builder` görünür/ön-belleğe yakın
/// öğeleri tembel biçimde inşa eder; bu, ilk panelin hemen, sonraki
/// panellerin ise yalnız viewport'a yaklaşınca inşa edilip görseli talep
/// etmesini doğal olarak sağlar (ayrı bir `precacheImage` çağrısı — ekstra
/// bir ağ isteği riski taşıyacağı için — eklenmedi).
class _ReaderPanelList extends ConsumerWidget {
  const _ReaderPanelList({
    required this.seriesSlug,
    required this.seriesTitle,
    required this.episode,
    required this.navigation,
    required this.scrollController,
  });

  final String seriesSlug;
  final String seriesTitle;
  final Episode episode;
  final EpisodeNavigation navigation;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiOrigin = ref.watch(appConfigProvider).apiOrigin;
    final panels = episode.panels;

    return CenteredMaxWidth(
      child: ListView.builder(
        controller: scrollController,
        padding: EdgeInsets.zero,
        itemCount: panels.length + 1,
        itemBuilder: (context, index) {
          if (index == panels.length) {
            return _ReaderEndNav(
              seriesSlug: seriesSlug,
              seriesTitle: seriesTitle,
              previous: navigation.previous,
              next: navigation.next,
            );
          }
          return _PanelBlock(panel: panels[index], apiOrigin: apiOrigin);
        },
      ),
    );
  }
}

/// Tek bir panel: görsel + hemen altında (boşluksuz) ayrı bir metin katmanı
/// (ADR-016 — metin görsele gömülmez). Görseli olmayan paneller (yalnız
/// eksik/legacy veri için bir geri düşüş; production bölümlerinde her
/// panelin görseli olur) yalnız sahne metniyle tam genişlik bir blok olarak
/// gösterilir.
class _PanelBlock extends StatelessWidget {
  const _PanelBlock({required this.panel, required this.apiOrigin});

  final StoryPanel panel;
  final String apiOrigin;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final image = panel.image;

    if (image == null) {
      // Görselsiz geri düşüş: panelin `tone`'una göre web'deki
      // `.story-panel--<tone>` gradyanı (bkz. tone_gradients.dart).
      // `PanelTone.unknown` için `storyPanelGradientForTone` `null` döner ve
      // `_TextLayer` mevcut düz `surface2` zeminine düşer.
      return _TextLayer(
        tokens: tokens,
        semanticLabel: panel.scene,
        sceneText: panel.scene,
        caption: panel.caption,
        dialogue: panel.dialogue,
        backgroundGradient: storyPanelGradientForTone(panel.tone),
      );
    }

    final semanticLabel = image.alt.isNotEmpty ? image.alt : panel.scene;
    final hasText = panel.caption != null || panel.dialogue != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          image: true,
          label: semanticLabel,
          // `AspectRatio`'nun (aşağıda) oranı her zaman ana `image.width`/
          // `image.height`'tan gelir — seçilen varyantın kendi oranı farklı
          // olsa bile (yuvarlama nedeniyle olabilir, bkz. fixture'lardaki
          // varyantlar) düzen zıplamaz; yalnız hangi `src`'in yükleneceği
          // varyant seçimine göre değişir.
          child: LayoutBuilder(
            builder: (context, constraints) {
              final imageUrl = resolveMediaUrl(
                apiOrigin,
                _resolvePanelImageSrc(context, image, constraints),
              );
              return AspectRatio(
                aspectRatio: image.width / image.height,
                child: _PanelImage(url: imageUrl),
              );
            },
          ),
        ),
        if (hasText)
          _TextLayer(
            tokens: tokens,
            semanticLabel: null,
            sceneText: null,
            caption: panel.caption,
            dialogue: panel.dialogue,
          ),
      ],
    );
  }
}

/// `image.variants` varsa (bkz. üretilen `StoryPanelImage.variants`,
/// `lib/core/contracts/generated/story_panel_image.dart`) okuyucu kolonu
/// genişliğini (`constraints.maxWidth` — `CenteredMaxWidth` ile ≤760px,
/// bkz. `shared/layout/content_max_width.dart`) ve cihaz piksel oranını
/// (`MediaQuery.devicePixelRatioOf`) kullanarak `selectMediaVariant` (bkz.
/// `core/api/media_variant_selector.dart`) ile ihtiyacı GEREKSİZ AŞMAYAN en
/// uygun varyantı seçer. `variants` `null`/boşsa, düzen kısıtı henüz
/// sınırsızsa ya da seçici `null` dönerse mevcut `image.src` davranışı
/// birebir korunur — canlı yerel API şu an varyant DÖNDÜRMEDİĞİ için bu
/// geri-düşüş yolu tüm gerçek çalıştırmalarda kullanılan tek yoldur.
String _resolvePanelImageSrc(
  BuildContext context,
  StoryPanelImage image,
  BoxConstraints constraints,
) {
  final variants = image.variants;
  if (variants == null ||
      variants.isEmpty ||
      !constraints.maxWidth.isFinite ||
      constraints.maxWidth <= 0) {
    return image.src;
  }
  final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
  final targetWidthPx = constraints.maxWidth * devicePixelRatio;
  final selected = selectMediaVariant(variants, targetWidthPx);
  return selected?.src ?? image.src;
}

/// Panel görselinden ayrı, okunabilir metin katmanı (ADR-016). Görseli olan
/// panellerde yalnız caption/dialogue gösterilir (sahne açıklaması yalnız
/// erişilebilirlik etiketi olarak kalır — web tarafıyla aynı davranış,
/// bkz. `app/[slug]/[episode]/ReaderExperience.tsx`); görseli olmayan geri
/// düşüş durumunda sahne metni de görünür yazılır.
class _TextLayer extends StatelessWidget {
  const _TextLayer({
    required this.tokens,
    required this.semanticLabel,
    required this.sceneText,
    required this.caption,
    required this.dialogue,
    this.backgroundGradient,
  });

  final AppTokens tokens;
  final String? semanticLabel;
  final String? sceneText;
  final String? caption;
  final String? dialogue;

  /// Yalnız görselsiz geri düşüş panelinde (bkz. `_PanelBlock`) tona göre
  /// doldurulur; görseli olan panellerin altındaki metin katmanında `null`
  /// kalır ve mevcut düz `surface2` zemin değişmez.
  final LinearGradient? backgroundGradient;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundGradient == null ? tokens.colors.surface2 : null,
        gradient: backgroundGradient,
      ),
      padding: EdgeInsets.all(tokens.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sceneText != null)
            Text(sceneText!, style: tokens.typography.bodyLarge),
          if (caption != null) ...[
            if (sceneText != null) SizedBox(height: tokens.spacing.sm),
            Text(
              caption!,
              style: tokens.typography.bodySmall.copyWith(
                fontStyle: FontStyle.italic,
                color: tokens.colors.muted,
              ),
            ),
          ],
          if (dialogue != null) ...[
            if (sceneText != null || caption != null)
              SizedBox(height: tokens.spacing.xs),
            Text(dialogue!, style: tokens.typography.bodyLarge),
          ],
        ],
      ),
    );

    if (semanticLabel == null) return content;
    return Semantics(label: semanticLabel, child: content);
  }
}

/// Panel görseli: yükleme/hata placeholder'ları ve bir yumuşak-geçiş (fade)
/// içerir. `MediaQuery.disableAnimations` (azaltılmış hareket) açıkken hem
/// yükleme göstergesi dönen bir spinner yerine statik bir simgeye döner hem
/// de fade süresi sıfırlanır — bu ekrandaki tek otomatik animasyon burada
/// devre dışı bırakılır.
class _PanelImage extends StatelessWidget {
  const _PanelImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Image.network(
      url,
      fit: BoxFit.cover,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: reduceMotion ? Duration.zero : tokens.durations.medium,
          curve: Curves.easeOut,
          child: child,
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: tokens.colors.surface2,
          alignment: Alignment.center,
          child: reduceMotion
              ? Icon(Icons.image_outlined, color: tokens.colors.muted)
              : CircularProgressIndicator(
                  color: tokens.colors.mint,
                  strokeWidth: 2,
                ),
        );
      },
      errorBuilder: (context, error, stackTrace) => Container(
        color: tokens.colors.surface2,
        alignment: Alignment.center,
        child: Icon(Icons.broken_image_outlined, color: tokens.colors.muted),
      ),
    );
  }
}

/// Bölüm sonu gezinme bloğu: önceki bölüm / seri sayfası / sonraki bölüm.
/// Üstteki [_ReaderAppBar] ile birlikte "hem üstte hem altta" ilkesini
/// karşılar. Seriye dönüş her zaman çalışır; önceki/sonraki olmayan yönler
/// buton olarak DEĞİL, bilgi metni olarak gösterilir (ADR-010).
class _ReaderEndNav extends StatelessWidget {
  const _ReaderEndNav({
    required this.seriesSlug,
    required this.seriesTitle,
    required this.previous,
    required this.next,
  });

  final String seriesSlug;
  final String seriesTitle;
  final EpisodeNavigationRef? previous;
  final EpisodeNavigationRef? next;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Bu bölüm burada bitti.',
            textAlign: TextAlign.center,
            style: tokens.typography.titleMedium,
          ),
          SizedBox(height: tokens.spacing.md),
          _NavLink(
            label: previous == null
                ? 'Bu, serinin ilk bölümü.'
                : 'Önceki bölüm: Bölüm ${previous!.number}',
            onTap: previous == null
                ? null
                : () => context.pushReplacement(
                    '/series/$seriesSlug/read/${previous!.slug}',
                  ),
          ),
          SizedBox(height: tokens.spacing.sm),
          _NavLink(
            label: '$seriesTitle seri sayfasına dön',
            onTap: () => _returnToSeries(context, seriesSlug),
          ),
          SizedBox(height: tokens.spacing.sm),
          _NavLink(
            label: next == null
                ? 'Bu, serinin şu ana kadarki son bölümü.'
                : 'Sonraki bölüm: Bölüm ${next!.number}',
            onTap: next == null
                ? null
                : () => context.pushReplacement(
                    '/series/$seriesSlug/read/${next!.slug}',
                  ),
          ),
        ],
      ),
    );
  }
}

/// Bölüm geçiş bağlantısı. `onTap` `null` olduğunda (örn. serinin ilk/son
/// bölümü) devre dışı bir buton yerine bilgi metni gösterilir (ADR-010).
class _NavLink extends StatelessWidget {
  const _NavLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final content = Container(
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
