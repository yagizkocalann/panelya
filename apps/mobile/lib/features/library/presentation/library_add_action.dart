import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/auth_feature_config.dart';
import '../../../core/contracts/generated/generated.dart';
import '../../auth/domain/auth_session_state.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/library_exceptions.dart';
import 'library_providers.dart';

/// Seri detayındaki "Kütüphaneye ekle" / "Kütüphanemde" aksiyonu
/// (bkz. ADR-048).
///
/// ÜÇ AYRI DURUM, hiçbirinde sahte davranış yok (ADR-010):
///
/// 1. `AUTH_ENABLED` KAPALI -> widget HİÇ render edilmez. Ulaşılamayan
///    bir aksiyon gösterilmez.
/// 2. Bayrak açık ama kullanıcı ANONİM -> "Kütüphaneye ekle" görünür ve
///    mevcut GERÇEK Auth0 akışına (`/account`) götürür. Sahte başarı
///    gösterilmez, API isteği de YAPILMAZ.
/// 3. Giriş yapılmış -> seri, mevcut [libraryProvider] sonucunda slug ile
///    aranır.
///    * Kütüphanede DEĞİLSE: çalışan aksiyon `POST /api/library/{slug}`
///      ile TAM hedef durumu (`status: plan`, `favorite: false`) gönderir
///      ve başarıdan sonra [libraryProvider] tazelenir.
///    * ZATEN kütüphanedeyse: "Kütüphanemde" durumu gösterilir ve
///      `/library` ekranına götürür. TOGGLE veya sessiz silme davranışı
///      ÜRETİLMEZ — çıkarma yalnız kütüphane ekranındaki açık aksiyonla
///      ve onayla yapılır.
class LibraryAddAction extends ConsumerStatefulWidget {
  const LibraryAddAction({super.key, required this.seriesSlug});

  final String seriesSlug;

  @override
  ConsumerState<LibraryAddAction> createState() => _LibraryAddActionState();
}

class _LibraryAddActionState extends ConsumerState<LibraryAddAction> {
  /// Tekrar dokunma koruması: istek sürerken ikinci bir `POST` gönderilmez.
  bool _busy = false;

  Future<void> _add() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(libraryRepositoryProvider)
          .upsertEntry(
            slug: widget.seriesSlug,
            // Hedef durumun TAMAMI — toggle değil.
            status: LibraryStatus.plan,
            favorite: false,
          );
      ref.invalidate(libraryProvider);
    } on LibraryRepositoryException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1) Bayrak kapalı: hiç render edilmez.
    if (!ref.watch(authFeatureConfigProvider).enabled) {
      return const SizedBox.shrink();
    }

    final session = ref.watch(authSessionProvider);
    if (session is AuthAnonymous) {
      // 2) Anonim: gerçek giriş akışına götürür, API isteği YOK.
      return OutlinedButton.icon(
        onPressed: () => context.push('/account'),
        icon: const Icon(Icons.bookmark_add_outlined),
        label: const Text('Kütüphaneye ekle'),
      );
    }

    // 3) Giriş yapılmış: mevcut kütüphane sonucunda slug aranır.
    final library = ref.watch(libraryProvider);

    return library.when(
      loading: () => const OutlinedButton(
        onPressed: null,
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      // Kütüphane okunamadıysa "ekle" göstermek yanlış olurdu (seri zaten
      // ekli olabilir); dürüst bir tekrar-dene sunulur.
      error: (error, stackTrace) => OutlinedButton.icon(
        onPressed: () => ref.invalidate(libraryProvider),
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Kütüphane durumu alınamadı'),
      ),
      data: (response) {
        final inLibrary = response.items.any(
          (item) => item.series.slug == widget.seriesSlug,
        );

        if (inLibrary) {
          return OutlinedButton.icon(
            onPressed: () => context.push('/library'),
            icon: const Icon(Icons.bookmark_added_rounded),
            label: const Text('Kütüphanemde'),
          );
        }

        if (_busy) {
          return const OutlinedButton(
            onPressed: null,
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        return OutlinedButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.bookmark_add_outlined),
          label: const Text('Kütüphaneye ekle'),
        );
      },
    );
  }
}
