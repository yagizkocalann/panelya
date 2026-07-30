import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// PLAN Görev A/B ve production-bible.md §6'daki kalite kapısı
/// ("360/390 mobil, 768 tablet dikey, 1024 tablet yatay") ile aynı cihaz
/// sınıflarını temsil eden viewport boyutları.
const phonePortrait = Size(390, 844);
const phoneLandscape = Size(844, 390);
const tabletPortrait = Size(768, 1024);
const tabletLandscape = Size(1024, 768);

/// Test tuvalini verilen fiziksel boyuta ayarlar ve testin sonunda eski
/// haline döndürür (varsayılan 800x600 masaüstü tuvali gerçek bir cihazı
/// temsil etmediği için — bkz. mevcut testlerdeki `usePhoneViewport`
/// eşdeğerleri).
void useViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}
