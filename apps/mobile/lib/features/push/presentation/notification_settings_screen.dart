import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../shared/widgets/home_button.dart';
import '../../../shared/widgets/state_views.dart';
import '../domain/push_exceptions.dart';
import 'push_providers.dart';

/// Bildirim ayarları ekranı (`/notifications`, bkz.
/// docs/mobile-handoff.md "FCM topic sınırı"). Hesap/giriş GEREKMEZ —
/// `AccountScreen`in aksine `AuthFeatureConfig.enabled` bayrağından
/// bağımsız her zaman erişilebilir (bkz. `discover_screen.dart`daki her
/// zaman görünen giriş noktası).
///
/// Anahtar açıkken sabit `panelya-new-episodes` FCM konusuna abone
/// olunur, kapatılınca abonelik kaldırılır (bkz.
/// `PushNotificationRepository`). Anahtarın gösterdiği durum yalnız
/// cihaz-yerel tercihe değil, GERÇEK OS bildirim izin durumuna da bağlıdır
/// (`pushPermissionStatusProvider`) — kullanıcı izni sistem ayarlarından
/// geri almışsa anahtar dürüstçe kapalı görünür.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  Future<void> _setEnabled(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(pushNotificationRepositoryProvider);
    if (value) {
      final granted = await repository.requestPermission();
      if (!granted) return;
      try {
        await repository.subscribeToNewEpisodes();
      } on PushSubscriptionUnavailableException catch (error) {
        // Abonelik olmadan tercihi AÇIK yazmayız — anahtar kapalı kalır ve
        // kullanıcı neden olduğunu öğrenir (bkz. ADR-010).
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
        return;
      }
      await ref.read(notificationPreferenceProvider.notifier).setEnabled(true);
    } else {
      try {
        await repository.unsubscribeFromNewEpisodes();
      } on PushSubscriptionUnavailableException catch (error) {
        // Abonelik gerçekten kaldırılamadıysa tercihi KAPALI yazmayız —
        // aksi hâlde kullanıcı bildirim almaya devam ederken anahtarı
        // kapalı görürdü.
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
        return;
      }
      await ref.read(notificationPreferenceProvider.notifier).setEnabled(false);
    }
    ref.invalidate(pushPermissionStatusProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final preference = ref.watch(notificationPreferenceProvider);
    final permission = ref.watch(pushPermissionStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: const [HomeButton()],
      ),
      body: SafeArea(
        child: permission.when(
          loading: () =>
              const AppLoadingView(label: 'Bildirim izni kontrol ediliyor'),
          error: (error, stackTrace) => AppErrorView(
            message: 'Beklenmeyen bir hata oluştu.',
            onRetry: () => ref.invalidate(pushPermissionStatusProvider),
          ),
          data: (hasPermission) {
            final effectiveEnabled = hasPermission && preference;
            return Padding(
              padding: EdgeInsets.all(tokens.spacing.md),
              child: SwitchListTile(
                value: effectiveEnabled,
                onChanged: (value) => _setEnabled(context, ref, value),
                title: const Text('Yeni bölüm bildirimleri'),
                subtitle: Text(
                  !hasPermission && preference
                      ? 'Bildirim izni kapalı — açmak için dokun.'
                      : 'Yayınlanan her yeni bölüm için bildirim al (yalnız '
                            'takip ettiklerin değil, tüm seriler).',
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
