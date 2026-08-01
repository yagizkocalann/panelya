import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/contracts/generated/generated.dart';
import '../../../shared/widgets/home_button.dart';
import '../../../shared/widgets/series_card.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/domain/auth_session_state.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/library_exceptions.dart';
import 'library_providers.dart';
import 'library_status_labels.dart';

/// "Kütüphanem" ekranı (`/library`, bkz. ADR-048).
///
/// ANONİM KULLANICI: sahte bir kütüphane veya sahte başarı GÖSTERİLMEZ
/// (ADR-010). Giriş gerektiren bir ekran olduğu için kullanıcı mevcut
/// GERÇEK Auth0 akışına (`/account`) yönlendirilir.
///
/// SIRALAMA: sunucunun verdiği sıra olduğu gibi render edilir; `updatedAt`
/// damgasından ya da Türkçe gösterim metninden yeniden sıralama
/// ÜRETİLMEZ.
///
/// Kart görseli mevcut [SeriesCard]'ı yeniden kullanır — responsive medya
/// varyantı seçimi (`coverImageVariants`) böylece kütüphane kartlarında da
/// aynı şekilde çalışır, kopyalanmaz.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  /// Aynı anda tek bir satırın mutation'ı sürsün diye; hangi slug'ın
  /// meşgul olduğunu tutar.
  String? _busySlug;

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Hedef durumun TAMAMINI gönderir — toggle değil (bkz.
  /// `LibraryRepository.upsertEntry`).
  Future<void> _upsert(
    LibraryItem item, {
    LibraryStatus? status,
    bool? favorite,
  }) async {
    setState(() => _busySlug = item.series.slug);
    try {
      await ref
          .read(libraryRepositoryProvider)
          .upsertEntry(
            slug: item.series.slug,
            status: status ?? item.status,
            favorite: favorite ?? item.favorite,
          );
      ref.invalidate(libraryProvider);
    } on LibraryRepositoryException catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _busySlug = null);
    }
  }

  Future<void> _remove(LibraryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kütüphaneden çıkar'),
        content: Text('"${item.series.title}" kütüphanenden çıkarılsın mı?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Çıkar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busySlug = item.series.slug);
    try {
      // `removed: false` (kayıt zaten yoktu) başarılı bir IDEMPOTENT
      // sonuçtur — hata olarak gösterilmez. Her iki durumda da liste
      // tazelenir.
      await ref.read(libraryRepositoryProvider).removeEntry(item.series.slug);
      ref.invalidate(libraryProvider);
    } on LibraryRepositoryException catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _busySlug = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kütüphanem'),
        actions: const [HomeButton()],
      ),
      body: SafeArea(
        child: switch (session) {
          // Anonim: sahte içerik YOK, gerçek giriş akışına yönlendirme.
          AuthAnonymous() => _SignInPrompt(
            onSignIn: () => context.push('/account'),
          ),
          AuthAuthenticated() => _LibraryBody(
            busySlug: _busySlug,
            onUpsert: _upsert,
            onRemove: _remove,
          ),
        },
      ),
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Kütüphaneni görmek için giriş yap.',
              textAlign: TextAlign.center,
              style: tokens.typography.bodyMedium,
            ),
            SizedBox(height: tokens.spacing.lg),
            FilledButton(onPressed: onSignIn, child: const Text('Giriş yap')),
          ],
        ),
      ),
    );
  }
}

class _LibraryBody extends ConsumerWidget {
  const _LibraryBody({
    required this.busySlug,
    required this.onUpsert,
    required this.onRemove,
  });

  final String? busySlug;
  final void Function(LibraryItem item, {LibraryStatus? status, bool? favorite})
  onUpsert;
  final void Function(LibraryItem item) onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final library = ref.watch(libraryProvider);

    return library.when(
      loading: () => const AppLoadingView(label: 'Kütüphanen yükleniyor'),
      error: (error, stackTrace) => AppErrorView(
        // Sunucunun kendi açıklaması varsa o gösterilir.
        message: error is LibraryRepositoryException
            ? error.message
            : 'Beklenmeyen bir hata oluştu.',
        onRetry: () => ref.invalidate(libraryProvider),
      ),
      data: (response) {
        if (response.items.isEmpty) {
          return const AppEmptyView(message: 'Kütüphanende henüz seri yok.');
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(libraryProvider.future),
          child: ListView.separated(
            padding: EdgeInsets.all(tokens.spacing.md),
            // SUNUCU SIRASI: liste olduğu gibi render edilir.
            itemCount: response.items.length,
            separatorBuilder: (_, _) => SizedBox(height: tokens.spacing.md),
            itemBuilder: (context, index) {
              final item = response.items[index];
              return _LibraryRow(
                item: item,
                busy: busySlug == item.series.slug,
                onUpsert: onUpsert,
                onRemove: onRemove,
              );
            },
          ),
        );
      },
    );
  }
}

class _LibraryRow extends StatelessWidget {
  const _LibraryRow({
    required this.item,
    required this.busy,
    required this.onUpsert,
    required this.onRemove,
  });

  final LibraryItem item;
  final bool busy;
  final void Function(LibraryItem item, {LibraryStatus? status, bool? favorite})
  onUpsert;
  final void Function(LibraryItem item) onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SeriesCard(
          // Responsive varyant seçimi dahil mevcut kart yeniden kullanılır.
          series: SeriesCardData.fromDiscoverySeriesSummary(item.series),
          onTap: () => context.push('/series/${item.series.slug}'),
        ),
        SizedBox(height: tokens.spacing.sm),
        if (busy)
          const Center(child: CircularProgressIndicator())
        else
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: tokens.spacing.sm,
            runSpacing: tokens.spacing.xs,
            children: [
              // Okuma durumu. `unknown` (sunucudan gelen tanınmayan bir
              // değer) seçenek olarak SUNULMAZ ama mevcut durum olarak
              // dürüstçe gösterilir.
              PopupMenuButton<LibraryStatus>(
                tooltip: 'Okuma durumu',
                onSelected: (status) => onUpsert(item, status: status),
                itemBuilder: (context) => [
                  for (final status in librarySelectableStatuses)
                    PopupMenuItem(
                      value: status,
                      child: Text(libraryStatusLabel(status)),
                    ),
                ],
                child: Chip(label: Text(libraryStatusLabel(item.status))),
              ),
              IconButton(
                tooltip: item.favorite
                    ? 'Favorilerden çıkar'
                    : 'Favorilere ekle',
                onPressed: () => onUpsert(item, favorite: !item.favorite),
                icon: Icon(
                  item.favorite ? Icons.favorite : Icons.favorite_border,
                  color: item.favorite ? tokens.colors.coral : null,
                ),
              ),
              TextButton(
                onPressed: () => onRemove(item),
                child: const Text('Kütüphaneden çıkar'),
              ),
            ],
          ),
      ],
    );
  }
}
