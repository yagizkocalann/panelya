// Dev-only canlı sözleşme doğrulama scripti (Faz 2, Görev 1).
//
// Amaç: `apps/mobile/lib/core/contracts/` altındaki GEÇİCİ adapter
// modellerinin, web tarafının canlı `/api/*` uçlarının BUGÜN döndürdüğü
// gerçek JSON şekliyle hâlâ eşleştiğini doğrulamak. Katalogdaki tüm
// serileri ve her serinin tüm bölüm manifestlerini gezer.
//
// ÇALIŞTIRMA:
//   Bu dosya `package:flutter/foundation.dart` (dolayısıyla `dart:ui`)
//   içeren contract sınıflarını kullandığı için düz `dart run` ile
//   ÇALIŞMAZ ("dart:ui is not available on this platform" hatası verir).
//   Flutter'ın `dart:ui` şimini sağlayan tek yerel yürütücü `flutter test`
//   test motorudur (flutter_tester); bu yüzden script `test()` bloğu
//   içermese de aşağıdaki komutla çalıştırılır:
//
//     flutter test tool/live_contract_check.dart
//
//   İsteğe bağlı: farklı bir API origin'i denemek için
//     flutter test tool/live_contract_check.dart --dart-define=API_ORIGIN=http://localhost:3000
//   (`AppConfig.fromDartDefines()` üzerinden okunur; origin kaynak koda
//   gömülmez.)
//
// KURALLAR (PLAN'dan):
//   - Uyuşmazlık bulunursa contracts dosyaları TAHMİN EDİLEREK değiştirilmez;
//     bu script yalnız (endpoint, alan, gelen değer) üçlüsüyle raporlar.
//   - API JSON alanları veya `schemaVersion` davranışı burada değiştirilmez;
//     web tarafı dosyalarına bu script dokunmaz, yalnız okur (HTTP GET).
//
// Bu dosya `apps/mobile/lib/` altında değildir; uygulamanın çalışma zamanı
// kodunun bir parçası değildir, yalnız geliştirme/QA aracıdır.
//
// Not (Görev 4 — ortak sözleşme merge'i sonrası): repo kökündeki
// `packages/contracts/schema.json` artık web+mobil için dil bağımsız
// kaynak sözleşmedir. Aşağıdaki alan kontrolleri (`_checkSeriesMetadataFields`
// vb.) o şemadaki `SeriesMetadataFields`/`Episode`/`StoryPanel`
// tanımlarıyla birebir örtüşecek şekilde elle yazılmıştır (otomatik şema
// doğrulayıcı yeni bir bağımlılık gerektireceği için eklenmedi — bkz. teslim
// raporu "Kalan risk/varsayım"). `packages/contracts/fixtures/*.json`
// karşısında ayrı, dosya-tabanlı parser testleri
// `test/core/contracts/fixture_contracts_test.dart` içindedir.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:panelya_mobile/core/config/app_config.dart';
import 'package:panelya_mobile/core/contracts/catalog_response.dart';
import 'package:panelya_mobile/core/contracts/episode_manifest_response.dart';
import 'package:panelya_mobile/core/contracts/schema_version.dart';
import 'package:panelya_mobile/core/contracts/series_detail_response.dart';

/// Bilinen kapalı kümeler (yalnız BİLGİLENDİRME amaçlı gözlem için;
/// `StoryPanel.tone` sunucudan bilinmeyen bir değer gelirse sessizce
/// `PanelTone.unknown` üretir ve istemci ÇÖKMEZ — bu tasarım gereği
/// öyledir, bkz. `core/contracts/story_panel.dart`. Yine de raporda görünür
/// olması için burada ayrı bir "gözlem" listesine yazılır, "uyuşmazlık"
/// listesine değil).
const _knownPanelTones = {
  'coral',
  'mint',
  'violet',
  'blue',
  'amber',
  'rose',
};
const _knownStatuses = {'Devam Ediyor', 'Tamamlandı'};

/// Bir (endpoint, alan, beklenen, gelen) uyuşmazlık kaydı.
class Mismatch {
  Mismatch({
    required this.endpoint,
    required this.field,
    required this.expected,
    required this.actual,
  });

  final String endpoint;
  final String field;
  final String expected;
  final String actual;

  @override
  String toString() =>
      'UYUŞMAZLIK  endpoint=$endpoint  alan=$field  beklenen=$expected  gelen=$actual';
}

/// Bilgilendirme amaçlı, kritik olmayan gözlem (örn. bilinmeyen ama
/// zararsız şekilde ele alınan bir enum değeri).
class Observation {
  Observation({required this.endpoint, required this.note});

  final String endpoint;
  final String note;

  @override
  String toString() => 'GÖZLEM      endpoint=$endpoint  $note';
}

/// Tek bir endpoint cevabının ham JSON'ını, sözleşmenin beklediği alan
/// kümesiyle karşılaştıran yardımcı. Contract dosyalarını DEĞİŞTİRMEZ;
/// yalnız o dosyalardaki `fromJson` beklentilerini burada ayrıca (read-only)
/// listeler ve gelen veriyle karşılaştırır.
class FieldChecker {
  FieldChecker(this.endpoint, this.mismatches, this.observations);

  final String endpoint;
  final List<Mismatch> mismatches;
  final List<Observation> observations;

  void requireString(Map<String, dynamic> json, String field) =>
      _requireType<String>(json, field);

  void requireNum(Map<String, dynamic> json, String field) =>
      _requireType<num>(json, field);

  void requireBool(Map<String, dynamic> json, String field) =>
      _requireType<bool>(json, field);

  void optionalString(Map<String, dynamic> json, String field) =>
      _optionalType<String>(json, field);

  void optionalBool(Map<String, dynamic> json, String field) =>
      _optionalType<bool>(json, field);

  void requireStringList(Map<String, dynamic> json, String field) {
    if (!json.containsKey(field)) {
      _record(field, 'List<String> (zorunlu)', 'alan eksik');
      return;
    }
    final value = json[field];
    if (value is! List) {
      _record(field, 'List<String>', '${value.runtimeType}: $value');
      return;
    }
    for (final item in value) {
      if (item is! String) {
        _record(field, 'List<String> (her öge String)', '${item.runtimeType}: $item');
      }
    }
  }

  void requireMap(Map<String, dynamic> json, String field) {
    if (!json.containsKey(field)) {
      _record(field, 'object (zorunlu)', 'alan eksik');
      return;
    }
    if (json[field] is! Map<String, dynamic> && json[field] is! Map) {
      _record(field, 'object', '${json[field].runtimeType}: ${json[field]}');
    }
  }

  void requireList(Map<String, dynamic> json, String field) {
    if (!json.containsKey(field)) {
      _record(field, 'List (zorunlu)', 'alan eksik');
      return;
    }
    if (json[field] is! List) {
      _record(field, 'List', '${json[field].runtimeType}: ${json[field]}');
    }
  }

  void checkKnownSet(
    Map<String, dynamic> json,
    String field,
    Set<String> knownValues, {
    required bool required,
  }) {
    if (!json.containsKey(field) || json[field] == null) {
      if (required) _record(field, 'string (zorunlu)', 'alan eksik');
      return;
    }
    final value = json[field];
    if (value is! String) {
      _record(field, 'string', '${value.runtimeType}: $value');
      return;
    }
    if (!knownValues.contains(value)) {
      observations.add(
        Observation(
          endpoint: endpoint,
          note:
              '"$field" bilinen kümenin ($knownValues) dışında bir değer taşıyor: "$value" '
              '(istemci çökmez, ancak yeni bir sunucu değeri olabilir; kontrol edin).',
        ),
      );
    }
  }

  void _requireType<T>(Map<String, dynamic> json, String field) {
    if (!json.containsKey(field)) {
      _record(field, '$T (zorunlu)', 'alan eksik');
      return;
    }
    final value = json[field];
    if (value is! T) {
      _record(field, '$T', '${value.runtimeType}: $value');
    }
  }

  void _optionalType<T>(Map<String, dynamic> json, String field) {
    if (!json.containsKey(field) || json[field] == null) return;
    final value = json[field];
    if (value is! T) {
      _record(field, '$T (opsiyonel)', '${value.runtimeType}: $value');
    }
  }

  void _record(String field, String expected, String actual) {
    mismatches.add(
      Mismatch(endpoint: endpoint, field: field, expected: expected, actual: actual),
    );
  }
}

void _checkSeriesMetadataFields(
  Map<String, dynamic> json,
  String endpoint,
  List<Mismatch> mismatches,
  List<Observation> observations,
) {
  final checker = FieldChecker(endpoint, mismatches, observations);
  checker.requireString(json, 'slug');
  checker.requireString(json, 'title');
  checker.requireString(json, 'eyebrow');
  checker.requireString(json, 'creator');
  checker.requireString(json, 'description');
  checker.requireString(json, 'longDescription');
  checker.checkKnownSet(json, 'status', _knownStatuses, required: true);
  checker.requireStringList(json, 'genres');
  checker.requireString(json, 'tone');
  checker.requireString(json, 'updatedAt');
  checker.requireNum(json, 'rating');
  checker.requireString(json, 'followers');
  checker.optionalBool(json, 'isNew');
  checker.optionalString(json, 'coverImage');
  checker.optionalString(json, 'coverPosition');
}

void _checkPanelFields(
  Map<String, dynamic> json,
  String endpoint,
  List<Mismatch> mismatches,
  List<Observation> observations,
) {
  final checker = FieldChecker(endpoint, mismatches, observations);
  checker.requireString(json, 'id');
  checker.requireString(json, 'scene');
  checker.checkKnownSet(json, 'tone', _knownPanelTones, required: true);
  checker.optionalString(json, 'caption');
  checker.optionalString(json, 'dialogue');
  checker.optionalString(json, 'align');
  if (json['image'] != null) {
    final image = json['image'];
    if (image is Map<String, dynamic>) {
      final imageChecker = FieldChecker(endpoint, mismatches, observations);
      imageChecker.requireString(image, 'src');
      imageChecker.requireString(image, 'alt');
      imageChecker.requireNum(image, 'width');
      imageChecker.requireNum(image, 'height');
    } else {
      mismatches.add(
        Mismatch(
          endpoint: endpoint,
          field: 'image',
          expected: 'object',
          actual: '${image.runtimeType}: $image',
        ),
      );
    }
  }
}

void _checkEpisodeFields(
  Map<String, dynamic> json,
  String endpoint,
  List<Mismatch> mismatches,
  List<Observation> observations, {
  required bool expectPanels,
  required bool expectPanelCount,
}) {
  final checker = FieldChecker(endpoint, mismatches, observations);
  checker.requireString(json, 'slug');
  checker.requireNum(json, 'number');
  checker.requireString(json, 'title');
  checker.requireString(json, 'publishedAt');
  checker.requireString(json, 'readTime');
  if (expectPanels) {
    checker.requireList(json, 'panels');
    if (json['panels'] is List) {
      for (final panel in json['panels'] as List) {
        if (panel is Map<String, dynamic>) {
          _checkPanelFields(panel, endpoint, mismatches, observations);
        }
      }
    }
  }
  if (expectPanelCount) {
    checker.requireNum(json, 'panelCount');
  }
}

class LiveContractCheckReport {
  final List<Mismatch> mismatches = [];
  final List<Observation> observations = [];
  final List<String> checkedEndpoints = [];
  final List<String> parseFailures = [];

  void logChecked(String endpoint) => checkedEndpoints.add(endpoint);

  void logParseFailure(String endpoint, Object error) {
    parseFailures.add('$endpoint => $error');
  }
}

Future<void> main() async {
  final apiOrigin = AppConfig.fromDartDefines().apiOrigin;
  final client = http.Client();
  final report = LiveContractCheckReport();

  stdout.writeln('== Panelya canlı sözleşme doğrulaması ==');
  stdout.writeln('API origin: $apiOrigin');
  stdout.writeln('');

  try {
    // 1) GET /api/catalog
    const catalogPath = '/api/catalog';
    final catalogJson = await _getJson(client, apiOrigin, catalogPath, report);
    if (catalogJson == null) {
      _printReportAndExit(report);
      return;
    }
    report.logChecked(catalogPath);

    _checkCatalogFields(catalogJson, catalogPath, report);
    List<Map<String, dynamic>> seriesEntries = const [];
    try {
      final parsed = CatalogResponse.fromJson(catalogJson);
      stdout.writeln(
        'Katalog ayrıştırıldı: ${parsed.series.length} seri, featuredSlug=${parsed.featuredSlug}',
      );
      seriesEntries = (catalogJson['series'] as List)
          .cast<Map<String, dynamic>>();
    } on Object catch (error) {
      report.logParseFailure(catalogPath, error);
      // Ham JSON'dan slug listesini yine de çıkarmayı dene ki tur devam
      // edebilsin (parse hatası olsa bile kalan uçları da doğrulamak
      // isteriz).
      final rawSeries = catalogJson['series'];
      if (rawSeries is List) {
        seriesEntries = rawSeries.whereType<Map<String, dynamic>>().toList();
      }
    }

    stdout.writeln('Katalogdaki seri sayısı: ${seriesEntries.length}');

    // 2) Her seri için GET /api/series/:slug
    for (final entry in seriesEntries) {
      final slug = entry['slug'];
      if (slug is! String) {
        report.mismatches.add(
          Mismatch(
            endpoint: catalogPath,
            field: 'series[].slug',
            expected: 'String',
            actual: '${slug.runtimeType}: $slug',
          ),
        );
        continue;
      }

      final seriesPath = '/api/series/${Uri.encodeComponent(slug)}';
      final seriesJson = await _getJson(client, apiOrigin, seriesPath, report);
      if (seriesJson == null) continue;
      report.logChecked(seriesPath);
      _checkSeriesDetailFields(seriesJson, seriesPath, report);

      List<Map<String, dynamic>> episodeEntries = const [];
      try {
        final parsed = SeriesDetailResponse.fromJson(seriesJson);
        stdout.writeln(
          '  Seri "$slug" ayrıştırıldı: ${parsed.episodes.length} bölüm.',
        );
        episodeEntries =
            (seriesJson['episodes'] as List).cast<Map<String, dynamic>>();
      } on Object catch (error) {
        report.logParseFailure(seriesPath, error);
        final rawEpisodes = seriesJson['episodes'];
        if (rawEpisodes is List) {
          episodeEntries =
              rawEpisodes.whereType<Map<String, dynamic>>().toList();
        }
      }

      // 3) Her bölüm için GET /api/series/:slug/episodes/:episodeSlug
      for (final episodeEntry in episodeEntries) {
        final episodeSlug = episodeEntry['slug'];
        if (episodeSlug is! String) {
          report.mismatches.add(
            Mismatch(
              endpoint: seriesPath,
              field: 'episodes[].slug',
              expected: 'String',
              actual: '${episodeSlug.runtimeType}: $episodeSlug',
            ),
          );
          continue;
        }

        final episodePath =
            '/api/series/${Uri.encodeComponent(slug)}/episodes/${Uri.encodeComponent(episodeSlug)}';
        final episodeJson =
            await _getJson(client, apiOrigin, episodePath, report);
        if (episodeJson == null) continue;
        report.logChecked(episodePath);
        _checkEpisodeManifestFields(episodeJson, episodePath, report);

        try {
          EpisodeManifestResponse.fromJson(episodeJson);
        } on Object catch (error) {
          report.logParseFailure(episodePath, error);
        }
      }
    }

    // 4) Bilinmeyen seri 404 davranışı (dokümante edilen kural, PLAN'da
    // belirtildiği gibi).
    const unknownPath = '/api/series/bu-seri-hicbir-zaman-var-olmadi-qa';
    final unknownUri = Uri.parse('$apiOrigin$unknownPath');
    final unknownResponse = await client.get(unknownUri);
    report.logChecked('$unknownPath (bilinmeyen seri 404 kontrolü)');
    if (unknownResponse.statusCode != 404) {
      report.mismatches.add(
        Mismatch(
          endpoint: unknownPath,
          field: 'HTTP status',
          expected: '404',
          actual: '${unknownResponse.statusCode}',
        ),
      );
    } else {
      try {
        final body = jsonDecode(unknownResponse.body);
        if (body is Map && body['error'] != 'series_not_found') {
          report.observations.add(
            Observation(
              endpoint: unknownPath,
              note:
                  '404 gövdesindeki "error" alanı "series_not_found" değil: ${body['error']}',
            ),
          );
        }
      } on FormatException {
        report.observations.add(
          Observation(endpoint: unknownPath, note: '404 gövdesi JSON değil.'),
        );
      }
    }
  } finally {
    client.close();
  }

  _printReportAndExit(report);
}

void _checkCatalogFields(
  Map<String, dynamic> json,
  String endpoint,
  LiveContractCheckReport report,
) {
  final checker = FieldChecker(endpoint, report.mismatches, report.observations);
  checker.requireString(json, 'schemaVersion');
  checker.optionalString(json, 'featuredSlug');
  checker.requireList(json, 'series');
  if (json['series'] is List) {
    for (final item in json['series'] as List) {
      if (item is! Map<String, dynamic>) continue;
      _checkSeriesMetadataFields(
        item,
        endpoint,
        report.mismatches,
        report.observations,
      );
      final summaryChecker = FieldChecker(
        endpoint,
        report.mismatches,
        report.observations,
      );
      summaryChecker.requireNum(item, 'episodeCount');
      // latestEpisode pratikte her zaman dolu gelir (yayınlanmış her seri en
      // az bir bölüm içerir) ama sözleşme nullable kabul eder.
      if (item['latestEpisode'] != null) {
        final latest = item['latestEpisode'];
        if (latest is Map<String, dynamic>) {
          _checkEpisodeFields(
            latest,
            endpoint,
            report.mismatches,
            report.observations,
            expectPanels: true,
            expectPanelCount: false,
          );
        } else {
          report.mismatches.add(
            Mismatch(
              endpoint: endpoint,
              field: 'series[].latestEpisode',
              expected: 'object',
              actual: '${latest.runtimeType}: $latest',
            ),
          );
        }
      }
    }
  }
}

void _checkSeriesDetailFields(
  Map<String, dynamic> json,
  String endpoint,
  LiveContractCheckReport report,
) {
  final checker = FieldChecker(endpoint, report.mismatches, report.observations);
  checker.requireString(json, 'schemaVersion');
  checker.requireMap(json, 'series');
  if (json['series'] is Map<String, dynamic>) {
    _checkSeriesMetadataFields(
      json['series'] as Map<String, dynamic>,
      endpoint,
      report.mismatches,
      report.observations,
    );
  }
  checker.requireList(json, 'episodes');
  if (json['episodes'] is List) {
    for (final item in json['episodes'] as List) {
      if (item is! Map<String, dynamic>) continue;
      _checkEpisodeFields(
        item,
        endpoint,
        report.mismatches,
        report.observations,
        expectPanels: false,
        expectPanelCount: true,
      );
    }
  }
}

void _checkEpisodeManifestFields(
  Map<String, dynamic> json,
  String endpoint,
  LiveContractCheckReport report,
) {
  final checker = FieldChecker(endpoint, report.mismatches, report.observations);
  checker.requireString(json, 'schemaVersion');
  checker.requireMap(json, 'series');
  if (json['series'] is Map<String, dynamic>) {
    final seriesRefChecker = FieldChecker(
      endpoint,
      report.mismatches,
      report.observations,
    );
    final seriesRef = json['series'] as Map<String, dynamic>;
    seriesRefChecker.requireString(seriesRef, 'slug');
    seriesRefChecker.requireString(seriesRef, 'title');
  }
  checker.requireMap(json, 'episode');
  if (json['episode'] is Map<String, dynamic>) {
    _checkEpisodeFields(
      json['episode'] as Map<String, dynamic>,
      endpoint,
      report.mismatches,
      report.observations,
      expectPanels: true,
      expectPanelCount: false,
    );
  }
  checker.requireMap(json, 'navigation');
  if (json['navigation'] is Map<String, dynamic>) {
    final navigation = json['navigation'] as Map<String, dynamic>;
    for (final navKey in ['previous', 'next']) {
      if (navigation[navKey] == null) continue;
      final navValue = navigation[navKey];
      if (navValue is Map<String, dynamic>) {
        final navChecker = FieldChecker(
          endpoint,
          report.mismatches,
          report.observations,
        );
        navChecker.requireString(navValue, 'slug');
        navChecker.requireNum(navValue, 'number');
      } else {
        report.mismatches.add(
          Mismatch(
            endpoint: endpoint,
            field: 'navigation.$navKey',
            expected: 'object|null',
            actual: '${navValue.runtimeType}: $navValue',
          ),
        );
      }
    }
  }
}

Future<Map<String, dynamic>?> _getJson(
  http.Client client,
  String apiOrigin,
  String path,
  LiveContractCheckReport report,
) async {
  final uri = Uri.parse('$apiOrigin$path');
  http.Response response;
  try {
    response = await client.get(uri).timeout(const Duration(seconds: 10));
  } on Object catch (error) {
    report.mismatches.add(
      Mismatch(
        endpoint: path,
        field: '(ağ isteği)',
        expected: 'HTTP 200 cevabı',
        actual: 'istek başarısız: $error',
      ),
    );
    return null;
  }

  if (response.statusCode != 200) {
    report.mismatches.add(
      Mismatch(
        endpoint: path,
        field: 'HTTP status',
        expected: '200',
        actual: '${response.statusCode}: ${response.body}',
      ),
    );
    return null;
  }

  try {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      report.mismatches.add(
        Mismatch(
          endpoint: path,
          field: '(gövde şekli)',
          expected: 'JSON object',
          actual: '${decoded.runtimeType}',
        ),
      );
      return null;
    }
    if (decoded['schemaVersion'] != kSupportedSchemaVersion) {
      report.mismatches.add(
        Mismatch(
          endpoint: path,
          field: 'schemaVersion',
          expected: kSupportedSchemaVersion,
          actual: '${decoded['schemaVersion']}',
        ),
      );
    }
    return decoded;
  } on FormatException catch (error) {
    report.mismatches.add(
      Mismatch(
        endpoint: path,
        field: '(gövde)',
        expected: 'geçerli JSON',
        actual: 'FormatException: $error',
      ),
    );
    return null;
  }
}

void _printReportAndExit(LiveContractCheckReport report) {
  stdout.writeln('');
  stdout.writeln('== Sonuç ==');
  stdout.writeln('Kontrol edilen uç sayısı: ${report.checkedEndpoints.length}');
  for (final endpoint in report.checkedEndpoints) {
    stdout.writeln('  - $endpoint');
  }
  stdout.writeln('');

  if (report.parseFailures.isEmpty) {
    stdout.writeln(
      'Contract fromJson() ayrıştırması: tüm cevaplar mevcut '
      'lib/core/contracts modelleriyle hatasız ayrıştırıldı.',
    );
  } else {
    stdout.writeln('Contract fromJson() ayrıştırma HATALARI:');
    for (final failure in report.parseFailures) {
      stdout.writeln('  - $failure');
    }
  }
  stdout.writeln('');

  if (report.mismatches.isEmpty) {
    stdout.writeln('Alan düzeyinde uyuşmazlık bulunmadı.');
  } else {
    stdout.writeln('Alan düzeyinde UYUŞMAZLIKLAR (${report.mismatches.length}):');
    for (final mismatch in report.mismatches) {
      stdout.writeln('  - $mismatch');
    }
  }
  stdout.writeln('');

  if (report.observations.isNotEmpty) {
    stdout.writeln('Bilgilendirme amaçlı gözlemler (${report.observations.length}):');
    for (final observation in report.observations) {
      stdout.writeln('  - $observation');
    }
    stdout.writeln('');
  }

  final hasProblems =
      report.mismatches.isNotEmpty || report.parseFailures.isNotEmpty;
  stdout.writeln(
    hasProblems
        ? 'DURUM: UYUŞMAZLIK BULUNDU — contracts dosyaları DEĞİŞTİRİLMEDİ, yukarıdaki '
              'üçlüler rapora yazıldı (bkz. PLAN kuralları).'
        : 'DURUM: BAŞARILI — canlı API, mevcut contracts modelleriyle tam eşleşiyor.',
  );

  if (hasProblems) {
    exitCode = 1;
  }
}
