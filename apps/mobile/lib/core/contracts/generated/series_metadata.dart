// GENERATED — elle düzenleme; kaynak: packages/contracts/schema.json, üretici: tool/generate_contracts.dart
// Bu dosyayı elle düzenlemeyin; değişiklik gerekiyorsa
// packages/contracts/schema.json güncellenip codegen yeniden
// çalıştırılmalıdır (dart run tool/generate_contracts.dart).

import 'panel_tone.dart';
import 'public_media_variant.dart';

/// Kaynak: `packages/contracts/schema.json` -> `$defs/SeriesMetadata`.
class SeriesMetadata {
  const SeriesMetadata({
    required this.slug,
    required this.title,
    required this.eyebrow,
    required this.creator,
    required this.description,
    required this.longDescription,
    required this.status,
    required this.genres,
    required this.tone,
    required this.updatedAt,
    required this.rating,
    required this.followers,
    this.isNew,
    this.coverImage,
    this.coverImageVariants,
    this.coverPosition,
  });

  factory SeriesMetadata.fromJson(Map<String, dynamic> json) {
    final slug = json['slug'] as String;
    final title = json['title'] as String;
    final eyebrow = json['eyebrow'] as String;
    final creator = json['creator'] as String;
    final description = json['description'] as String;
    final longDescription = json['longDescription'] as String;
    final status = json['status'] as String;
    final genres = (json['genres'] as List<dynamic>).cast<String>();
    final tone = PanelTone.fromJson(json['tone'] as String);
    final updatedAt = json['updatedAt'] as String;
    final rating = (json['rating'] as num).toDouble();
    final followers = json['followers'] as String;
    final isNew = json['isNew'] as bool?;
    final coverImage = json['coverImage'] as String?;
    final coverImageVariantsRaw = json['coverImageVariants'];
    final coverImageVariants = coverImageVariantsRaw == null ? null : (coverImageVariantsRaw as List<dynamic>)
        .map(
          (item) => PublicMediaVariant.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList(growable: false);
    final coverPosition = json['coverPosition'] as String?;
    return SeriesMetadata(
      slug: slug,
      title: title,
      eyebrow: eyebrow,
      creator: creator,
      description: description,
      longDescription: longDescription,
      status: status,
      genres: genres,
      tone: tone,
      updatedAt: updatedAt,
      rating: rating,
      followers: followers,
      isNew: isNew,
      coverImage: coverImage,
      coverImageVariants: coverImageVariants,
      coverPosition: coverPosition,
    );
  }

  final String slug;
  final String title;
  final String eyebrow;
  final String creator;
  final String description;
  final String longDescription;
  /// Bilinen değer kümesi: "Devam Ediyor" | "Tamamlandı".
  final String status;
  final List<String> genres;
  final PanelTone tone;
  /// Current v1 API returns a localized display label, not an ISO timestamp.
  final String updatedAt;
  final double rating;
  /// Current v1 API returns a localized display label.
  final String followers;
  final bool? isNew;
  final String? coverImage;
  /// Ready responsive cover derivatives sorted by ascending width.
  final List<PublicMediaVariant>? coverImageVariants;
  final String? coverPosition;

  Map<String, dynamic> toJson() {
    return {
      'slug': slug,
      'title': title,
      'eyebrow': eyebrow,
      'creator': creator,
      'description': description,
      'longDescription': longDescription,
      'status': status,
      'genres': genres,
      'tone': tone.toJson(),
      'updatedAt': updatedAt,
      'rating': rating,
      'followers': followers,
      'isNew': isNew,
      'coverImage': coverImage,
      'coverImageVariants': coverImageVariants?.map((e) => e.toJson()).toList(),
      'coverPosition': coverPosition,
    };
  }
}
