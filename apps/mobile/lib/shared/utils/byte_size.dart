/// Bayt sayısını okunabilir bir "İndirilenler" ekranı etiketine çevirir
/// (bkz. `features/offline/presentation/downloads_screen.dart`). Yalnız
/// KB/MB kullanır — indirilen bölümlerin gerçekçi boyut aralığı (birkaç
/// yüz KB - birkaç MB) GB'a hiç ulaşmaz, bu yüzden o birim eklenmedi.
String formatByteSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(1)} MB';
}
