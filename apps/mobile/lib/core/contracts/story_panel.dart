// GEÇİCİ ADAPTER: packages/contracts main'e gelince bu dosya ortak sözleşmeyle
// değiştirilecek (bkz. docs/mobile-handoff.md Ortaklık kuralları #3).
//
// Bu dosyadaki alanlar `app/data/catalog.ts` içindeki `StoryPanel` ve
// `PanelTone` tiplerinin JSON üzerinden birebir yansımasıdır.

import 'package:flutter/foundation.dart';

/// `app/data/catalog.ts` -> `PanelTone`. Kapalı bir küme olsa da sunucu ileride
/// yeni bir ton eklerse istemci çökmesin diye bilinmeyen değerler
/// [PanelTone.unknown] altında tutulur ve orijinal string [rawValue]'da saklanır.
enum PanelTone {
  coral,
  mint,
  violet,
  blue,
  amber,
  rose,
  unknown;

  static PanelTone fromJson(String? value) {
    switch (value) {
      case 'coral':
        return PanelTone.coral;
      case 'mint':
        return PanelTone.mint;
      case 'violet':
        return PanelTone.violet;
      case 'blue':
        return PanelTone.blue;
      case 'amber':
        return PanelTone.amber;
      case 'rose':
        return PanelTone.rose;
      default:
        return PanelTone.unknown;
    }
  }
}

/// `StoryPanel.image`.
@immutable
class StoryPanelImage {
  const StoryPanelImage({
    required this.src,
    required this.alt,
    required this.width,
    required this.height,
  });

  factory StoryPanelImage.fromJson(Map<String, dynamic> json) {
    return StoryPanelImage(
      src: json['src'] as String,
      alt: json['alt'] as String,
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
    );
  }

  final String src;
  final String alt;
  final int width;
  final int height;
}

/// `app/data/catalog.ts` -> `StoryPanel`. `caption`, `dialogue`, `align` ve
/// `image` sunucuda opsiyoneldir; burada da nullable tutulur.
@immutable
class StoryPanel {
  const StoryPanel({
    required this.id,
    required this.scene,
    required this.tone,
    this.caption,
    this.dialogue,
    this.align,
    this.image,
  });

  factory StoryPanel.fromJson(Map<String, dynamic> json) {
    return StoryPanel(
      id: json['id'] as String,
      scene: json['scene'] as String,
      tone: PanelTone.fromJson(json['tone'] as String?),
      caption: json['caption'] as String?,
      dialogue: json['dialogue'] as String?,
      align: json['align'] as String?,
      image: json['image'] == null
          ? null
          : StoryPanelImage.fromJson(json['image'] as Map<String, dynamic>),
    );
  }

  final String id;
  final String scene;
  final PanelTone tone;
  final String? caption;
  final String? dialogue;

  /// Sunucuda `"left" | "right"`.
  final String? align;
  final StoryPanelImage? image;
}
