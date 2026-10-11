import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/generated/assets.dart';

/// Правила бренда заложены в самих файлах: если кто-то подменит SVG
/// одноцветным, кнопка входа перестанет соответствовать требованиям Google.
void main() {
  Set<String> fills(String path) => RegExp(r'fill="(#[0-9A-Fa-f]{6})"')
      .allMatches(File(path).readAsStringSync())
      .map((m) => m.group(1)!.toUpperCase())
      .toSet();

  test('google.svg — цветной логотип G: четыре фирменных цвета', () {
    expect(
      fills(Assets.iconsGoogle),
      {'#EA4335', '#4285F4', '#FBBC05', '#34A853'},
    );
  });

  test('apple.svg — одноцветный, поэтому на кнопке перекрашивается', () {
    expect(fills(Assets.iconsApple), hasLength(1));
  });

  test('файлы иконок лежат там, куда ведут константы Assets', () {
    expect(File(Assets.iconsGoogle).existsSync(), isTrue);
    expect(File(Assets.iconsApple).existsSync(), isTrue);
  });
}
