// Panelya ortak sözleşme -> Dart DTO codegen'i.
//
// AMAÇ: `packages/contracts/schema.json` (JSON Schema 2020-12) dosyasını
// TEK kaynak kabul edip, ondan deterministik olarak Dart DTO (model)
// sınıfları üretmek. Üretilen dosyalar
// `apps/mobile/lib/core/contracts/generated/` altına yazılır.
//
// KAPSAM / SINIRLAR:
//   - Bu script YALNIZ DTO/model üretir (alanlar + fromJson + toJson).
//     `PanelyaApiClient`, repository katmanı ve elle yazılmış
//     `lib/core/contracts/*.dart` GEÇİCİ adapter'larına dokunmaz.
//   - `packages/contracts/` SALT OKUNUR kaynaktır; bu script oraya hiçbir
//     şey yazmaz, yalnız `schema.json`'ı okur.
//   - Yeni bir pub paketi (json_serializable/build_runner vb.) eklenmez;
//     script yalnız `dart:core`, `dart:convert` ve `dart:io` kullanır, bu
//     yüzden düz `dart run` ile (Flutter'sız) çalışır.
//   - Üretim DETERMİNİSTİKTİR: aynı `schema.json` girdisinden bayt bayt
//     aynı çıktı üretilir. Rastgelelik veya timestamp yoktur; alan/dosya
//     sırası şemadaki (JSON) sıraya bağlıdır — Dart'ın `dart:convert`
//     JSON decoder'ı nesne anahtarlarını sıralı (`LinkedHashMap`) olarak
//     korur, bu da şema dosyası değişmediği sürece iterasyon sırasının
//     sabit kalmasını garanti eder.
//
// ÇALIŞTIRMA:
//   cd apps/mobile
//   dart run tool/generate_contracts.dart
//
// BELİRSİZLİK KURALI (PLAN'dan):
//   Şemada Dart'a birebir, tahminsiz çevrilemeyen bir yapı bulunursa
//   (ör. gerçek union/oneOf >2 varyant, ek alanlara açık nesne, tanınamayan
//   şema düğümü) script o yapı için ÜRETİM YAPMAZ; tüm şema için üretimi
//   iptal eder ve aşağıya (stdout) `$defs adı / alan adı / önerilen Dart
//   tipi` üçlüsünü basar, exit code 1 ile çıkar. Üretici bu durumda hiçbir
//   dosya YAZMAZ (var olan `generated/` klasörüne de dokunmaz).
//
// TASARIM KARARLARI (tahmin değil, sabit kurallar):
//   1. `oneOf: [<tip>, {"type":"null"}]` veya `type: [<tip>, "null"]` kalıbı
//      "nullable <tip>" olarak çevrilir (JSON Schema'nın yaygın nullable
//      idiomu). Başka hiçbir oneOf/anyOf kalıbı desteklenmez —
//      desteklenmeyeni script REDDEDER.
//   2. Adlandırılmış (`$defs` altında, `$ref` ile erişilen) `type: string`
//      + `enum` şeması bir Dart `enum`'a çevrilir (örn. `PanelTone`).
//      Enum değerleri sözleşmede geçerli Dart tanımlayıcısı olmalıdır;
//      değilse script REDDEDER (transliterasyon TAHMİN ETMEZ).
//   3. `$defs` içinde ADI OLMAYAN / doğrudan bir özelliğe GÖMÜLÜ (inline)
//      `enum` (ör. `status`, `align`, `error` alanları) kapalı bir isim
//      icat etmek yerine düz `String` olarak üretilir; izin verilen
//      değerler dartdoc yorumunda listelenir. Bu, mevcut elle yazılmış
//      adapter'ların (`lib/core/contracts/*.dart`) da izlediği kuraldır.
//   4. `allOf` ile birleşen ve yalnızca birleşim içinde referans edilen
//      (hiçbir yerde çıplak `$ref` ile kullanılmayan) bir `$defs` girdisi
//      ("alan paketi", örn. `SeriesMetadataFields`) tek başına bağımsız
//      bir dosya olarak üretilmez; yalnızca onu birleştiren tipin
//      (`SeriesMetadata`, `SeriesSummary`) alanlarına dahil edilir. Bu
//      güvenlidir çünkü birleştiren şema `unevaluatedProperties:false` ile
//      kapalıdır (aksi halde REDDEDİLİR — "ek alanlara açık nesne").
//   5. `additionalProperties:false` (düz nesne) veya
//      `unevaluatedProperties:false` (allOf birleşimi) taşımayan bir nesne
//      şeması -- 4. maddedeki alan paketi istisnası dışında -- ek alanlara
//      açık kabul edilir ve REDDEDİLİR.
//   6. ENUM POLİTİKASI = LENIENT (orkestratör kararı): Adlandırılmış her
//      Dart enum'una örtük bir `unknown` fallback üyesi eklenir. `fromJson`
//      tanınmayan bir string değeri için exception FIRLATMAZ, sessizce
//      `unknown`'a düşer. Gerekçe: mobil istemci production'da web'den
//      önce/sonra dağıtılabilir; sunucu ileride kapalı kümeye yeni bir
//      değer eklerse (ör. yeni bir `PanelTone`), eski bir mobil sürüm
//      tam bir cevabı parse edemeyip çökmek yerine bilinmeyen değeri
//      zararsızca yutabilmelidir (bkz. eski elle yazılmış
//      `lib/core/contracts/story_panel.dart`'ın izlediği aynı ilke).
//      `toJson()` ise `unknown` için TANIMSIZDIR ve `UnsupportedError`
//      fırlatır: ham sunucu string'i saklanmadığı için `unknown`'ı geri
//      sunucuya güvenle serialize etmenin bir yolu yoktur; bu istemci
//      hiçbir zaman `unknown` bir değeri sunucuya geri yazmaz (yalnız
//      okur), bu yüzden pratikte tetiklenmez. Şemada zaten `"unknown"`
//      adında bir değer TANIMLIYSA bu çakışma TAHMİN EDİLEREK
//      çözülmez; generator REDDEDER ve \$defs/alan/önerilen tip
//      üçlüsünü raporlar.

import 'dart:convert';
import 'dart:io';

// ---------------------------------------------------------------------------
// Ambiguity (belirsizlik) raporlama
// ---------------------------------------------------------------------------

/// Şemadan Dart'a tahminsiz çevrilemeyen bir yapı bulunduğunda kaydedilir.
class Ambiguity {
  Ambiguity({
    required this.defName,
    required this.field,
    required this.issue,
    required this.suggestedType,
  });

  /// İlgili `$defs` adı (üst seviye şema tanımı).
  final String defName;

  /// İlgili alan adı (üst seviye tanımın kendisiyse `"(tanımın kendisi)"`).
  final String field;

  /// Neden çevrilemediğinin kısa açıklaması.
  final String issue;

  /// Web tarafına iletilecek önerilen/beklenen Dart tipi.
  final String suggestedType;

  @override
  String toString() =>
      '\$defs=$defName  alan=$field  sorun=$issue  onerilen_dart_tipi=$suggestedType';
}

/// Tek bir generatör çalışması boyunca toplanan belirsizlikler.
final List<Ambiguity> _ambiguities = [];

void _reportAmbiguity({
  required String defName,
  required String field,
  required String issue,
  required String suggestedType,
}) {
  _ambiguities.add(
    Ambiguity(
      defName: defName,
      field: field,
      issue: issue,
      suggestedType: suggestedType,
    ),
  );
}

// ---------------------------------------------------------------------------
// Dart tanımlayıcı yardımcıları
// ---------------------------------------------------------------------------

const _dartReservedWords = {
  'assert', 'break', 'case', 'catch', 'class', 'const', 'continue', 'default',
  'do', 'else', 'enum', 'extends', 'false', 'final', 'finally', 'for', 'if',
  'in', 'is', 'new', 'null', 'rethrow', 'return', 'super', 'switch', 'this',
  'throw', 'true', 'try', 'var', 'void', 'while', 'with',
};

bool _isValidDartIdentifier(String value) {
  if (value.isEmpty) return false;
  if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(value)) return false;
  if (_dartReservedWords.contains(value)) return false;
  return true;
}

/// Bir şema enum değer listesinin geçerli, tahminsiz üretilebilir bir Dart
/// enum'a çevrilip çevrilemeyeceğini doğrular. Hem "her değer geçerli bir
/// Dart tanımlayıcısı mı" hem de LENIENT enum politikasının (bkz. dosya
/// başlığı, tasarım kararı #6) örtük olarak eklediği `unknown` fallback
/// üyesiyle bir isim çakışması olup olmadığını kontrol eder. Herhangi bir
/// sorun bulunursa `_ambiguities`'e kaydeder ve `false` döner; üretim o
/// yapı için durur (tahminle devam edilmez).
bool _validateEnumValues({
  required String defName,
  required String field,
  required List<dynamic> values,
}) {
  var ok = true;
  for (final value in values) {
    if (value is! String || !_isValidDartIdentifier(value)) {
      _reportAmbiguity(
        defName: defName,
        field: field,
        issue:
            'enum değeri "$value" geçerli bir Dart tanımlayıcısı değil; '
            'otomatik transliterasyon tahmin gerektirir',
        suggestedType: 'enum $defName { /* elle isimlendirme */ }',
      );
      ok = false;
      continue;
    }
    if (value == 'unknown') {
      _reportAmbiguity(
        defName: defName,
        field: field,
        issue:
            'şema zaten "unknown" adında bir enum değeri tanımlıyor; bu, '
            'LENIENT enum politikasının (bkz. dosya başlığı, tasarım '
            'kararı #6) her üretilen enum\'a örtük olarak eklediği '
            'ileri-uyumluluk fallback üyesiyle çakışıyor; otomatik yeniden '
            'adlandırma TAHMİN gerektirir',
        suggestedType:
            'enum $defName { ..., <mevcut "unknown" değeri için elle '
            'seçilmiş farklı bir Dart adı> }',
      );
      ok = false;
    }
  }
  return ok;
}

/// `SeriesMetadataFields` -> `series_metadata_fields`.
String _toSnakeCase(String pascal) {
  final buffer = StringBuffer();
  for (var i = 0; i < pascal.length; i++) {
    final char = pascal[i];
    final isUpper = char.toUpperCase() == char && char.toLowerCase() != char;
    if (isUpper && i > 0) {
      buffer.write('_');
    }
    buffer.write(char.toLowerCase());
  }
  return buffer.toString();
}

String _refName(String ref) {
  final match = RegExp(r'^#/\$defs/(.+)$').firstMatch(ref);
  if (match == null) {
    throw StateError('Beklenmeyen \$ref biçimi: $ref');
  }
  return match.group(1)!;
}

bool _isBareRef(Object? node) =>
    node is Map && node.length == 1 && node.containsKey(r'$ref');

// ---------------------------------------------------------------------------
// Çözümlenmiş Dart tip modeli
// ---------------------------------------------------------------------------

enum Kind { string, integer, doubleType, boolean, enumRef, objectRef, list }

class FieldType {
  FieldType.scalarString() : kind = Kind.string, dartType = 'String';
  FieldType.scalarInt() : kind = Kind.integer, dartType = 'int';
  FieldType.scalarDouble() : kind = Kind.doubleType, dartType = 'double';
  FieldType.scalarBool() : kind = Kind.boolean, dartType = 'bool';
  FieldType.constString() : kind = Kind.string, dartType = 'String';
  FieldType.enumRef(String name)
    : kind = Kind.enumRef,
      dartType = name,
      refName = name;
  FieldType.objectRef(String name)
    : kind = Kind.objectRef,
      dartType = name,
      refName = name;
  FieldType.list(FieldType item)
    : kind = Kind.list,
      dartType = 'List<${item.dartType}>',
      itemType = item;

  final Kind kind;
  final String dartType;
  String? refName;
  FieldType? itemType;
}

/// Bir özelliğin (property) çözümlenmiş sonucu: Dart tipi + null olabilirlik.
class Resolved {
  Resolved(this.type, this.nullable, {this.isSchemaVersionConst = false});
  final FieldType type;
  final bool nullable;

  /// `SchemaVersion` (`const`) üzerinden geldiyse `true`; fromJson üretimi
  /// `kSchemaVersion` ile karşılaştırma ekler.
  final bool isSchemaVersionConst;
}

class PropertySpec {
  PropertySpec({
    required this.name,
    required this.resolved,
    required this.requiredKey,
    this.description,
    this.inlineEnumValues,
  });

  final String name;
  final Resolved resolved;

  /// JSON'da anahtarın zorunlu olup olmadığı (`required` listesi).
  final bool requiredKey;
  final String? description;

  /// Yalnız adı olmayan (inline) enum alanları için: izin verilen değerler.
  final List<String>? inlineEnumValues;
}

class ObjectSpec {
  ObjectSpec(this.className, this.properties);
  final String className;
  final List<PropertySpec> properties;
}

// ---------------------------------------------------------------------------
// Şema çözümleyici
// ---------------------------------------------------------------------------

class SchemaResolver {
  SchemaResolver(this.defs);

  final Map<String, dynamic> defs;

  /// Bir özellik şemasını (property node) çözer. Çevrilemeyen bir yapı
  /// bulursa `null` döner ve belirsizliği `_ambiguities`'e kaydeder; çağıran
  /// taraf o alanı/tanımı üretmemelidir (yine de tarama tüm belirsizlikleri
  /// toplamak için devam eder).
  Resolved? resolveProperty(
    Map<String, dynamic> node,
    String defName,
    String field,
  ) {
    // 1) $ref
    if (node.containsKey(r'$ref')) {
      final refName = _refName(node[r'$ref'] as String);
      final target = defs[refName];
      if (target is! Map<String, dynamic>) {
        _reportAmbiguity(
          defName: defName,
          field: field,
          issue: 'bilinmeyen \$ref hedefi: $refName',
          suggestedType: 'elle inceleme gerekli',
        );
        return null;
      }
      if (target.containsKey('const')) {
        final constValue = target['const'];
        if (target['type'] != 'string' || constValue is! String) {
          _reportAmbiguity(
            defName: defName,
            field: field,
            issue: 'string olmayan bir "const" şeması ($refName)',
            suggestedType: 'elle inceleme gerekli',
          );
          return null;
        }
        return Resolved(
          FieldType.constString(),
          false,
          isSchemaVersionConst: true,
        );
      }
      if (target['type'] == 'string' && target.containsKey('enum')) {
        if (!_validateEnumValues(
          defName: refName,
          field: '(enum değeri)',
          values: target['enum'] as List,
        )) {
          return null;
        }
        return Resolved(FieldType.enumRef(refName), false);
      }
      if (target.containsKey('allOf') || target.containsKey('properties')) {
        // Nesne tipi (düz veya allOf birleşimi) — sınıf üretimi ayrı
        // (buildObjectSpec) tarafından yapılır, burada yalnız referans
        // türü döndürülür.
        return Resolved(FieldType.objectRef(refName), false);
      }
      _reportAmbiguity(
        defName: defName,
        field: field,
        issue: 'tanınamayan \$ref hedef şekli ($refName)',
        suggestedType: 'elle inceleme gerekli',
      );
      return null;
    }

    // 2) oneOf: yalnız [<tip>, {"type":"null"}] kalıbı desteklenir.
    if (node.containsKey('oneOf')) {
      final variants = node['oneOf'] as List;
      if (variants.length != 2) {
        _reportAmbiguity(
          defName: defName,
          field: field,
          issue:
              'oneOf ${variants.length} varyant içeriyor (yalnız '
              '[<tip>, null] kalıbı destekleniyor); bu gerçek bir union',
          suggestedType: 'sealed class $defName${_capitalize(field)}Variant',
        );
        return null;
      }
      Map<String, dynamic>? nullVariant;
      Map<String, dynamic>? otherVariant;
      for (final variant in variants) {
        if (variant is Map<String, dynamic> &&
            variant.length == 1 &&
            variant['type'] == 'null') {
          nullVariant = variant;
        } else if (variant is Map<String, dynamic>) {
          otherVariant = variant;
        }
      }
      if (nullVariant == null || otherVariant == null) {
        _reportAmbiguity(
          defName: defName,
          field: field,
          issue:
              'oneOf iki varyant içeriyor ama biri tam olarak '
              '{"type":"null"} değil; gerçek bir union olabilir',
          suggestedType: 'sealed class $defName${_capitalize(field)}Variant',
        );
        return null;
      }
      final inner = resolveProperty(otherVariant, defName, field);
      if (inner == null) return null;
      return Resolved(
        inner.type,
        true,
        isSchemaVersionConst: inner.isSchemaVersionConst,
      );
    }

    // 3) type: [<tip>, "null"] (dizi biçiminde nullable).
    final typeValue = node['type'];
    if (typeValue is List) {
      final types = typeValue.cast<String>();
      if (types.length != 2 || !types.contains('null')) {
        _reportAmbiguity(
          defName: defName,
          field: field,
          issue: 'çok değerli "type" dizisi desteklenmiyor: $types',
          suggestedType: 'elle inceleme gerekli',
        );
        return null;
      }
      final otherType = types.firstWhere((t) => t != 'null');
      final innerNode = Map<String, dynamic>.from(node)..['type'] = otherType;
      final inner = resolveProperty(innerNode, defName, field);
      if (inner == null) return null;
      return Resolved(inner.type, true);
    }

    // 4) array
    if (typeValue == 'array') {
      final itemsNode = node['items'];
      if (itemsNode is! Map<String, dynamic>) {
        _reportAmbiguity(
          defName: defName,
          field: field,
          issue: 'array şemasında "items" eksik veya nesne değil',
          suggestedType: 'List<dynamic>',
        );
        return null;
      }
      final item = resolveProperty(itemsNode, defName, '$field[]');
      if (item == null) return null;
      if (item.nullable) {
        _reportAmbiguity(
          defName: defName,
          field: field,
          issue: 'nullable liste öğeleri desteklenmiyor',
          suggestedType: 'List<${item.type.dartType}?>',
        );
        return null;
      }
      return Resolved(FieldType.list(item.type), false);
    }

    // 5) string (+ opsiyonel inline enum -> düz String, bkz. tasarım
    //    kararı #3 üstteki dosya başlığında).
    if (typeValue == 'string') {
      return Resolved(FieldType.scalarString(), false);
    }

    // 6) integer / number / boolean
    if (typeValue == 'integer') {
      return Resolved(FieldType.scalarInt(), false);
    }
    if (typeValue == 'number') {
      return Resolved(FieldType.scalarDouble(), false);
    }
    if (typeValue == 'boolean') {
      return Resolved(FieldType.scalarBool(), false);
    }

    _reportAmbiguity(
      defName: defName,
      field: field,
      issue:
          'tanınamayan şema düğümü (ne \$ref, ne oneOf, ne bilinen bir '
          '"type" değeri)',
      suggestedType: 'elle inceleme gerekli',
    );
    return null;
  }
}

String _capitalize(String value) {
  final cleaned = value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
  if (cleaned.isEmpty) return 'Field';
  return cleaned[0].toUpperCase() + cleaned.substring(1);
}

// ---------------------------------------------------------------------------
// Referans kullanım taraması (alan paketi tespiti için)
// ---------------------------------------------------------------------------

/// Bir `$defs` girdisinin BAĞIMSIZ dosya olarak üretilip üretilmeyeceğine
/// karar vermek için: yalnızca `allOf` birleşimleri içinde mi kullanılıyor
/// (bir "alan paketi"), yoksa en az bir yerde çıplak `$ref` ile mi
/// (özellik/liste öğesi/oneOf varyantı olarak) referans ediliyor?
class RefUsageScan {
  final Set<String> mergedOnly = {};
  final Set<String> bareRefTargets = {};

  void scan(Map<String, dynamic> defs) {
    for (final entry in defs.entries) {
      final node = entry.value;
      if (node is! Map<String, dynamic>) continue;
      if (node.containsKey('allOf')) {
        for (final member in node['allOf'] as List) {
          if (_isBareRef(member)) {
            mergedOnly.add(_refName((member as Map)[r'$ref'] as String));
          }
          if (member is Map<String, dynamic> &&
              member.containsKey('properties')) {
            _scanProperties(member['properties'] as Map<String, dynamic>);
          }
        }
      }
      if (node.containsKey('properties')) {
        _scanProperties(node['properties'] as Map<String, dynamic>);
      }
    }
  }

  void _scanProperties(Map<String, dynamic> properties) {
    for (final propSchema in properties.values) {
      if (propSchema is! Map<String, dynamic>) continue;
      _scanPropertySchema(propSchema);
    }
  }

  void _scanPropertySchema(Map<String, dynamic> propSchema) {
    if (_isBareRef(propSchema)) {
      bareRefTargets.add(_refName(propSchema[r'$ref'] as String));
      return;
    }
    if (propSchema.containsKey('oneOf')) {
      for (final variant in propSchema['oneOf'] as List) {
        if (_isBareRef(variant)) {
          bareRefTargets.add(_refName((variant as Map)[r'$ref'] as String));
        }
      }
    }
    if (propSchema['type'] == 'array' &&
        propSchema['items'] is Map<String, dynamic>) {
      _scanPropertySchema(propSchema['items'] as Map<String, dynamic>);
    }
  }
}

// ---------------------------------------------------------------------------
// Dart kod üretimi — ortak parçalar
// ---------------------------------------------------------------------------

const _generatedHeader =
    '// GENERATED — elle düzenleme; kaynak: packages/contracts/schema.json, '
    'üretici: tool/generate_contracts.dart\n'
    '// Bu dosyayı elle düzenlemeyin; değişiklik gerekiyorsa\n'
    '// packages/contracts/schema.json güncellenip codegen yeniden\n'
    '// çalıştırılmalıdır (dart run tool/generate_contracts.dart).\n';

String _fromJsonLines(String name, Resolved resolved) {
  final buffer = StringBuffer();
  if (resolved.isSchemaVersionConst) {
    buffer.writeln("    final $name = json['$name'] as String;");
    buffer.writeln('    if ($name != kSchemaVersion) {');
    buffer.writeln('      throw FormatException(');
    buffer.writeln(
      "        'Desteklenmeyen schemaVersion: \$$name '\n"
      "        '(beklenen: \$kSchemaVersion)',",
    );
    buffer.writeln('      );');
    buffer.writeln('    }');
    return buffer.toString();
  }

  final type = resolved.type;
  final nullable = resolved.nullable;

  switch (type.kind) {
    case Kind.string:
      buffer.writeln(
        "    final $name = json['$name'] as String${nullable ? '?' : ''};",
      );
    case Kind.integer:
      if (nullable) {
        buffer.writeln(
          "    final $name = (json['$name'] as num?)?.toInt();",
        );
      } else {
        buffer.writeln("    final $name = (json['$name'] as num).toInt();");
      }
    case Kind.doubleType:
      if (nullable) {
        buffer.writeln(
          "    final $name = (json['$name'] as num?)?.toDouble();",
        );
      } else {
        buffer.writeln(
          "    final $name = (json['$name'] as num).toDouble();",
        );
      }
    case Kind.boolean:
      buffer.writeln(
        "    final $name = json['$name'] as bool${nullable ? '?' : ''};",
      );
    case Kind.enumRef:
      if (nullable) {
        buffer.writeln("    final ${name}Raw = json['$name'];");
        buffer.writeln(
          '    final $name = ${name}Raw == null\n'
          '        ? null\n'
          '        : ${type.refName}.fromJson(${name}Raw as String);',
        );
      } else {
        buffer.writeln(
          "    final $name = ${type.refName}.fromJson(json['$name'] as String);",
        );
      }
    case Kind.objectRef:
      if (nullable) {
        buffer.writeln("    final ${name}Raw = json['$name'];");
        buffer.writeln(
          '    final $name = ${name}Raw == null\n'
          '        ? null\n'
          '        : ${type.refName}.fromJson(\n'
          '            ${name}Raw as Map<String, dynamic>,\n'
          '          );',
        );
      } else {
        buffer.writeln(
          '    final $name = ${type.refName}.fromJson(\n'
          "      json['$name'] as Map<String, dynamic>,\n"
          '    );',
        );
      }
    case Kind.list:
      final item = type.itemType!;
      final rawExpr = nullable ? '${name}Raw' : "json['$name']";
      if (nullable) {
        buffer.writeln("    final ${name}Raw = json['$name'];");
      }
      final String listBody;
      switch (item.kind) {
        case Kind.string:
        case Kind.integer:
        case Kind.doubleType:
        case Kind.boolean:
          listBody =
              '($rawExpr as List<dynamic>).cast<${item.dartType}>()';
        case Kind.enumRef:
          listBody =
              '($rawExpr as List<dynamic>)\n'
              '        .map((item) => ${item.refName}.fromJson(item as String))\n'
              '        .toList(growable: false)';
        case Kind.objectRef:
          listBody =
              '($rawExpr as List<dynamic>)\n'
              '        .map(\n'
              '          (item) => ${item.refName}.fromJson(\n'
              '            item as Map<String, dynamic>,\n'
              '          ),\n'
              '        )\n'
              '        .toList(growable: false)';
        case Kind.list:
          throw StateError('İç içe liste desteklenmiyor: $name');
      }
      if (nullable) {
        buffer.writeln(
          '    final $name = ${name}Raw == null ? null : $listBody;',
        );
      } else {
        buffer.writeln('    final $name = $listBody;');
      }
  }
  return buffer.toString();
}

String _toJsonExpr(String name, Resolved resolved) {
  if (resolved.isSchemaVersionConst) return name;
  final type = resolved.type;
  final nullable = resolved.nullable;
  switch (type.kind) {
    case Kind.string:
    case Kind.integer:
    case Kind.doubleType:
    case Kind.boolean:
      return name;
    case Kind.enumRef:
    case Kind.objectRef:
      return nullable ? '$name?.toJson()' : '$name.toJson()';
    case Kind.list:
      final item = type.itemType!;
      final isScalar =
          item.kind == Kind.string ||
          item.kind == Kind.integer ||
          item.kind == Kind.doubleType ||
          item.kind == Kind.boolean;
      if (isScalar) return name;
      return nullable
          ? '$name?.map((e) => e.toJson()).toList()'
          : '$name.map((e) => e.toJson()).toList()';
  }
}

String _fieldDartType(PropertySpec prop) {
  final base = prop.resolved.type.dartType;
  return prop.resolved.nullable ? '$base?' : base;
}

/// Bir ObjectSpec'ten tam bir Dart sınıf dosyası üretir.
String _renderObjectClass(ObjectSpec spec, {List<String> extraImports = const []}) {
  final buffer = StringBuffer();
  buffer.write(_generatedHeader);
  buffer.writeln();
  for (final import in extraImports) {
    buffer.writeln("import '$import';");
  }
  if (extraImports.isNotEmpty) buffer.writeln();

  buffer.writeln(
    '/// Kaynak: `packages/contracts/schema.json` -> `\$defs/${spec.className}`.',
  );
  buffer.writeln('class ${spec.className} {');
  buffer.writeln('  const ${spec.className}({');
  for (final prop in spec.properties) {
    if (prop.requiredKey) {
      buffer.writeln('    required this.${prop.name},');
    } else {
      buffer.writeln('    this.${prop.name},');
    }
  }
  buffer.writeln('  });');
  buffer.writeln();

  // fromJson
  buffer.writeln(
    '  factory ${spec.className}.fromJson(Map<String, dynamic> json) {',
  );
  for (final prop in spec.properties) {
    buffer.write(_fromJsonLines(prop.name, prop.resolved));
  }
  buffer.writeln('    return ${spec.className}(');
  for (final prop in spec.properties) {
    buffer.writeln('      ${prop.name}: ${prop.name},');
  }
  buffer.writeln('    );');
  buffer.writeln('  }');
  buffer.writeln();

  // Fields
  for (final prop in spec.properties) {
    if (prop.description != null) {
      buffer.writeln('  /// ${prop.description}');
    }
    if (prop.inlineEnumValues != null) {
      final values = prop.inlineEnumValues!.map((v) => '"$v"').join(' | ');
      buffer.writeln('  /// Bilinen değer kümesi: $values.');
    }
    buffer.writeln('  final ${_fieldDartType(prop)} ${prop.name};');
  }
  buffer.writeln();

  // toJson
  buffer.writeln('  Map<String, dynamic> toJson() {');
  buffer.writeln('    return {');
  for (final prop in spec.properties) {
    buffer.writeln(
      "      '${prop.name}': ${_toJsonExpr(prop.name, prop.resolved)},",
    );
  }
  buffer.writeln('    };');
  buffer.writeln('  }');
  buffer.writeln('}');
  return buffer.toString();
}

/// LENIENT enum politikası (bkz. dosya başlığı, tasarım kararı #6): her
/// üretilen enum'a örtük bir `unknown` fallback üyesi eklenir. `values`
/// listesinde zaten `"unknown"` OLMADIĞI `_validateEnumValues` tarafından
/// önceden garanti edilmiştir (aksi halde bu fonksiyon hiç çağrılmaz).
String _renderEnumClass(String className, List<String> values) {
  final buffer = StringBuffer();
  buffer.write(_generatedHeader);
  buffer.writeln();
  buffer.writeln(
    '/// Kaynak: `packages/contracts/schema.json` -> `\$defs/$className`.\n'
    '///\n'
    '/// LENIENT enum politikası: `unknown`, sunucudan gelen tanınmayan bir\n'
    '/// değer için ileri-uyumluluk fallback\'idir (bkz.\n'
    '/// `tool/generate_contracts.dart` dosya başlığı, tasarım kararı #6).\n'
    '/// `fromJson` tanınmayan bir string için asla exception fırlatmaz.\n'
    '/// `toJson()` ise `unknown` için TANIMSIZDIR (ham sunucu değeri elde\n'
    '/// tutulmadığından geri serialize edilemez) ve `UnsupportedError`\n'
    '/// fırlatır; bu istemci `unknown` bir değeri hiçbir zaman sunucuya\n'
    '/// geri yazmaz (yalnız okur).',
  );
  buffer.writeln('enum $className {');
  for (final value in values) {
    buffer.writeln('  $value,');
  }
  buffer.writeln();
  buffer.writeln(
    '  /// Sunucudan gelen, bu istemcinin bilmediği bir değer için '
    'ileri-uyumluluk\n'
    '  /// fallback değeri. `toJson()` bu değer için çağrılamaz.\n'
    '  unknown,',
  );
  buffer.writeln();
  buffer.writeln('  ;');
  buffer.writeln();
  buffer.writeln('  static $className fromJson(String value) {');
  buffer.writeln('    switch (value) {');
  for (final value in values) {
    buffer.writeln("      case '$value':");
    buffer.writeln('        return $className.$value;');
  }
  buffer.writeln('      default:');
  buffer.writeln('        return $className.unknown;');
  buffer.writeln('    }');
  buffer.writeln('  }');
  buffer.writeln();
  buffer.writeln('  String toJson() {');
  buffer.writeln('    if (this == $className.unknown) {');
  buffer.writeln('      throw UnsupportedError(');
  buffer.writeln(
    "        '$className.unknown serialize edilemez "
    "(ham sunucu değeri tutulmuyor).',",
  );
  buffer.writeln('      );');
  buffer.writeln('    }');
  buffer.writeln('    return name;');
  buffer.writeln('  }');
  buffer.writeln('}');
  return buffer.toString();
}

String _renderConstStringFile(String constName, String value) {
  final buffer = StringBuffer();
  buffer.write(_generatedHeader);
  buffer.writeln();
  buffer.writeln(
    '/// Kaynak: `packages/contracts/schema.json` -> `\$defs/SchemaVersion` '
    '(`const`).',
  );
  buffer.writeln("const String $constName = '$value';");
  return buffer.toString();
}

// ---------------------------------------------------------------------------
// Nesne şeması -> ObjectSpec
// ---------------------------------------------------------------------------

ObjectSpec? _buildPlainObjectSpec(
  SchemaResolver resolver,
  String defName,
  Map<String, dynamic> node,
) {
  if (node['additionalProperties'] != false) {
    _reportAmbiguity(
      defName: defName,
      field: '(tanımın kendisi)',
      issue:
          '"additionalProperties: false" içermiyor; ek alanlara açık bir '
          'nesne, kapalı bir Dart sınıfına tahminle çevrilemez',
      suggestedType: 'Map<String, dynamic> (ham) veya açık şema onayı',
    );
    return null;
  }
  final properties = (node['properties'] as Map<String, dynamic>?) ?? {};
  final required = ((node['required'] as List?) ?? const []).cast<String>();
  return _buildSpecFromPropertyMap(
    resolver,
    defName,
    className: defName,
    properties: properties,
    requiredNames: required,
  );
}

ObjectSpec? _buildAllOfObjectSpec(
  SchemaResolver resolver,
  String defName,
  Map<String, dynamic> node,
) {
  if (node['unevaluatedProperties'] != false) {
    _reportAmbiguity(
      defName: defName,
      field: '(tanımın kendisi)',
      issue:
          'allOf birleşimi "unevaluatedProperties: false" içermiyor; ek '
          'alanlara açık bir birleşim, kapalı bir Dart sınıfına tahminle '
          'çevrilemez',
      suggestedType: 'Map<String, dynamic> (ham) veya açık şema onayı',
    );
    return null;
  }

  final properties = <String, dynamic>{};
  final required = <String>[];
  for (final member in node['allOf'] as List) {
    if (_isBareRef(member)) {
      final refName = _refName((member as Map)[r'$ref'] as String);
      final target = resolver.defs[refName];
      if (target is! Map<String, dynamic> ||
          target['properties'] is! Map<String, dynamic>) {
        _reportAmbiguity(
          defName: defName,
          field: '(allOf üyesi)',
          issue: 'allOf üyesi \$ref=$refName bir nesne alan tanımı değil',
          suggestedType: 'elle inceleme gerekli',
        );
        return null;
      }
      properties.addAll(target['properties'] as Map<String, dynamic>);
      required.addAll(
        ((target['required'] as List?) ?? const []).cast<String>(),
      );
    } else if (member is Map<String, dynamic> &&
        member.containsKey('properties')) {
      properties.addAll(member['properties'] as Map<String, dynamic>);
      required.addAll(
        ((member['required'] as List?) ?? const []).cast<String>(),
      );
    } else {
      _reportAmbiguity(
        defName: defName,
        field: '(allOf üyesi)',
        issue: 'tanınamayan allOf üyesi şekli',
        suggestedType: 'elle inceleme gerekli',
      );
      return null;
    }
  }
  return _buildSpecFromPropertyMap(
    resolver,
    defName,
    className: defName,
    properties: properties,
    requiredNames: required,
  );
}

ObjectSpec? _buildSpecFromPropertyMap(
  SchemaResolver resolver,
  String defName, {
  required String className,
  required Map<String, dynamic> properties,
  required List<String> requiredNames,
}) {
  final requiredSet = requiredNames.toSet();
  final specs = <PropertySpec>[];
  var ok = true;
  for (final entry in properties.entries) {
    final propName = entry.key;
    final propSchema = entry.value as Map<String, dynamic>;
    final resolved = resolver.resolveProperty(propSchema, defName, propName);
    if (resolved == null) {
      ok = false;
      continue;
    }
    final isRequired = requiredSet.contains(propName);
    // Anahtar zorunlu değilse (opsiyonel), değeri her zaman nullable kabul
    // edilir: JSON'da anahtar tamamen yok olabilir.
    final effectiveResolved = isRequired
        ? resolved
        : Resolved(
            resolved.type,
            true,
            isSchemaVersionConst: resolved.isSchemaVersionConst,
          );
    List<String>? inlineEnumValues;
    if (!propSchema.containsKey(r'$ref') &&
        propSchema['type'] == 'string' &&
        propSchema.containsKey('enum')) {
      inlineEnumValues = (propSchema['enum'] as List).cast<String>();
    }
    specs.add(
      PropertySpec(
        name: propName,
        resolved: effectiveResolved,
        requiredKey: isRequired,
        description: propSchema['description'] as String?,
        inlineEnumValues: inlineEnumValues,
      ),
    );
  }
  if (!ok) return null;
  return ObjectSpec(className, specs);
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

void main(List<String> args) {
  final scriptFile = File.fromUri(Platform.script);
  // apps/mobile/tool/generate_contracts.dart -> tool -> mobile -> apps -> repoRoot
  final repoRoot = scriptFile.parent.parent.parent.parent;
  final schemaFile = File.fromUri(
    repoRoot.uri.resolve('packages/contracts/schema.json'),
  );
  final outDir = Directory.fromUri(
    repoRoot.uri.resolve('apps/mobile/lib/core/contracts/generated/'),
  );

  if (!schemaFile.existsSync()) {
    stderr.writeln('HATA: şema dosyası bulunamadı: ${schemaFile.path}');
    exitCode = 1;
    return;
  }

  final schema =
      jsonDecode(schemaFile.readAsStringSync()) as Map<String, dynamic>;
  final defs = (schema[r'$defs'] as Map<String, dynamic>);

  final usage = RefUsageScan()..scan(defs);
  final resolver = SchemaResolver(defs);

  // fileName -> content
  final outputs = <String, String>{};

  for (final entry in defs.entries) {
    final defName = entry.key;
    final node = entry.value as Map<String, dynamic>;

    if (node.containsKey('const')) {
      final value = node['const'];
      if (node['type'] != 'string' || value is! String) {
        _reportAmbiguity(
          defName: defName,
          field: '(tanımın kendisi)',
          issue: 'string olmayan bir "const" şeması',
          suggestedType: 'elle inceleme gerekli',
        );
        continue;
      }
      outputs['${_toSnakeCase(defName)}.dart'] = _renderConstStringFile(
        'kSchemaVersion',
        value,
      );
      continue;
    }

    if (node['type'] == 'string' && node.containsKey('enum')) {
      final ok = _validateEnumValues(
        defName: defName,
        field: '(enum değeri)',
        values: node['enum'] as List,
      );
      if (!ok) continue;
      outputs['${_toSnakeCase(defName)}.dart'] = _renderEnumClass(
        defName,
        (node['enum'] as List).cast<String>(),
      );
      continue;
    }

    if (node.containsKey('allOf')) {
      final spec = _buildAllOfObjectSpec(resolver, defName, node);
      if (spec == null) continue;
      outputs['${_toSnakeCase(defName)}.dart'] = _renderObjectClass(
        spec,
        extraImports: _importsFor(spec),
      );
      continue;
    }

    if (node['type'] == 'object' && node.containsKey('properties')) {
      // Yalnızca bir allOf birleşimi içinde kullanılan ("alan paketi") ve
      // hiçbir yerde çıplak $ref ile referans edilmeyen tanımlar bağımsız
      // bir dosya olarak üretilmez (bkz. dosya başlığı, tasarım kararı #4).
      final isFragmentOnly =
          usage.mergedOnly.contains(defName) &&
          !usage.bareRefTargets.contains(defName);
      if (isFragmentOnly) {
        continue;
      }
      final spec = _buildPlainObjectSpec(resolver, defName, node);
      if (spec == null) continue;
      outputs['${_toSnakeCase(defName)}.dart'] = _renderObjectClass(
        spec,
        extraImports: _importsFor(spec),
      );
      continue;
    }

    _reportAmbiguity(
      defName: defName,
      field: '(tanımın kendisi)',
      issue:
          'tanınamayan üst seviye \$defs şekli (ne const, ne enum, ne '
          'allOf, ne düz nesne)',
      suggestedType: 'elle inceleme gerekli',
    );
  }

  if (_ambiguities.isNotEmpty) {
    stdout.writeln('== Panelya sözleşme codegen: BELİRSİZLİK RAPORU ==');
    stdout.writeln(
      'Aşağıdaki ${_ambiguities.length} yapı Dart'
      "'a tahminsiz çevrilemedi; ÜRETİM YAPILMADI (hiçbir dosya yazılmadı).",
    );
    stdout.writeln('Bu rapor web tarafına iletilmelidir.');
    stdout.writeln('');
    for (final ambiguity in _ambiguities) {
      stdout.writeln('  - $ambiguity');
    }
    exitCode = 1;
    return;
  }

  // Determinizm: çıktı dizinini tamamen temizleyip yeniden yazıyoruz ki
  // şemadan kalkan bir tanım artık üretilmediğinde eski dosya arkada
  // kalmasın.
  if (outDir.existsSync()) {
    outDir.deleteSync(recursive: true);
  }
  outDir.createSync(recursive: true);

  final sortedFileNames = outputs.keys.toList()..sort();
  for (final fileName in sortedFileNames) {
    final file = File.fromUri(outDir.uri.resolve(fileName));
    file.writeAsStringSync(outputs[fileName]!);
  }

  final barrelBuffer = StringBuffer()
    ..write(_generatedHeader)
    ..writeln()
    ..writeln(
      '// `packages/contracts/schema.json` şemasından üretilen tüm DTO '
      'dosyalarını\n'
      '// tek noktadan dışa aktarır.',
    );
  for (final fileName in sortedFileNames) {
    barrelBuffer.writeln("export '$fileName';");
  }
  File.fromUri(
    outDir.uri.resolve('generated.dart'),
  ).writeAsStringSync(barrelBuffer.toString());

  stdout.writeln(
    'Üretim tamamlandı: ${sortedFileNames.length} dosya + generated.dart '
    '-> ${outDir.path}',
  );
}

/// Bir ObjectSpec'in ihtiyaç duyduğu (aynı klasördeki) diğer üretilmiş
/// dosyaların import listesini, alan tiplerinden çıkarır.
List<String> _importsFor(ObjectSpec spec) {
  final imports = <String>{};
  for (final prop in spec.properties) {
    if (prop.resolved.isSchemaVersionConst) {
      imports.add('schema_version.dart');
      continue;
    }
    var type = prop.resolved.type;
    if (type.kind == Kind.list) {
      type = type.itemType!;
    }
    if (type.kind == Kind.enumRef || type.kind == Kind.objectRef) {
      imports.add('${_toSnakeCase(type.refName!)}.dart');
    }
  }
  final sorted = imports.toList()..sort();
  return sorted;
}
