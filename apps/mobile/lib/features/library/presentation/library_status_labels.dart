import '../../../core/contracts/generated/generated.dart';

/// [LibraryStatus] için Türkçe gösterim etiketleri.
///
/// Bu etiketler YALNIZ gösterim içindir; sıralama, karşılaştırma veya
/// sunucuya gönderilecek değer bunlardan TÜRETİLMEZ (bkz. ADR-048 —
/// sunucunun sırası korunur, gövdeye enum'un kendi `toJson()` değeri
/// gider).
const libraryStatusLabels = <LibraryStatus, String>{
  LibraryStatus.plan: 'Okuyacağım',
  LibraryStatus.reading: 'Okuyorum',
  LibraryStatus.completed: 'Bitirdim',
  LibraryStatus.paused: 'Ara verdim',
  LibraryStatus.dropped: 'Bıraktım',
};

/// Kullanıcının SEÇEBİLECEĞİ durumlar.
///
/// [LibraryStatus.unknown] KASITLI OLARAK dışarıdadır: o, sunucudan gelen
/// tanınmayan bir değer için ileri-uyumluluk fallback'idir; kullanıcıya
/// seçenek olarak sunulamaz ve sunucuya gönderilemez.
final librarySelectableStatuses = List<LibraryStatus>.unmodifiable(
  LibraryStatus.values.where((status) => status != LibraryStatus.unknown),
);

/// Bilinmeyen bir durum için dürüst etiket — yanlış bir durum UYDURULMAZ.
String libraryStatusLabel(LibraryStatus status) =>
    libraryStatusLabels[status] ?? 'Bilinmeyen durum';
