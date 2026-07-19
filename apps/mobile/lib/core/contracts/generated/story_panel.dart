// GENERATED — elle düzenleme; kaynak: packages/contracts/schema.json, üretici: tool/generate_contracts.dart
// Bu dosyayı elle düzenlemeyin; değişiklik gerekiyorsa
// packages/contracts/schema.json güncellenip codegen yeniden
// çalıştırılmalıdır (dart run tool/generate_contracts.dart).

import 'panel_tone.dart';
import 'story_panel_image.dart';

/// Kaynak: `packages/contracts/schema.json` -> `$defs/StoryPanel`.
class StoryPanel {
  const StoryPanel({
    required this.id,
    required this.scene,
    this.caption,
    this.dialogue,
    required this.tone,
    this.align,
    this.image,
  });

  factory StoryPanel.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final scene = json['scene'] as String;
    final caption = json['caption'] as String?;
    final dialogue = json['dialogue'] as String?;
    final tone = PanelTone.fromJson(json['tone'] as String);
    final align = json['align'] as String?;
    final imageRaw = json['image'];
    final image = imageRaw == null
        ? null
        : StoryPanelImage.fromJson(
            imageRaw as Map<String, dynamic>,
          );
    return StoryPanel(
      id: id,
      scene: scene,
      caption: caption,
      dialogue: dialogue,
      tone: tone,
      align: align,
      image: image,
    );
  }

  final String id;
  final String scene;
  final String? caption;
  final String? dialogue;
  final PanelTone tone;
  /// Bilinen değer kümesi: "left" | "right".
  final String? align;
  final StoryPanelImage? image;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scene': scene,
      'caption': caption,
      'dialogue': dialogue,
      'tone': tone.toJson(),
      'align': align,
      'image': image?.toJson(),
    };
  }
}
