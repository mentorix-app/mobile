import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/theme/app_text_theme.dart';
import 'package:mentorix_app/core/theme/app_theme.dart';

/// Inter лежит в приложении, а не скачивается: шрифт есть в первом кадре, и
/// подмена системным (и «скачок» текста) невозможна. Тест следит, что файлы
/// на месте и целые, а тема действительно на них опирается.
void main() {
  late String pubspec;

  setUpAll(() => pubspec = File('pubspec.yaml').readAsStringSync());

  /// Пути файлов Inter и их веса из секции `fonts` в `pubspec.yaml`.
  Map<String, int> declaredFonts() {
    final result = <String, int>{};
    final entry = RegExp(
      r'asset:\s*(assets/fonts/[^\s]+\.ttf)\s*\n\s*weight:\s*(\d+)',
    );
    for (final m in entry.allMatches(pubspec)) {
      result[m.group(1)!] = int.parse(m.group(2)!);
    }
    return result;
  }

  /// TrueType-файл целый: все таблицы лежат внутри файла (обрезанная
  /// загрузка выходит за его конец).
  bool isIntactTrueType(Uint8List bytes) {
    if (bytes.length < 12) return false;
    final data = ByteData.sublistView(bytes);
    final isTrueType = data.getUint32(0) == 0x00010000 || data.getUint32(0) == 0x74727565;
    if (!isTrueType) return false;

    final tables = data.getUint16(4);
    var end = 0;
    for (var i = 0; i < tables; i++) {
      final record = 12 + 16 * i;
      if (record + 16 > bytes.length) return false;
      final offset = data.getUint32(record + 8);
      final length = data.getUint32(record + 12);
      if (offset + length > end) end = offset + length;
    }
    return end <= bytes.length;
  }

  test('объявлены веса 400, 500, 600 и 700 семейства Inter', () {
    expect(declaredFonts().values.toSet(), {400, 500, 600, 700});
    expect(declaredFonts().keys, contains('assets/fonts/Inter_18pt-Bold.ttf'));
    expect(pubspec, contains('family: Inter'));
  });

  test('файлы шрифтов на месте и не обрезаны', () {
    for (final entry in declaredFonts().entries) {
      final file = File(entry.key);
      expect(file.existsSync(), isTrue, reason: '${entry.key} не найден');
      expect(
        isIntactTrueType(file.readAsBytesSync()),
        isTrue,
        reason: '${entry.key} повреждён или обрезан',
      );
    }
  });

  test('лицензия шрифта лежит рядом', () {
    final license = File('assets/fonts/OFL.txt');
    expect(license.existsSync(), isTrue);
    expect(license.readAsStringSync(), contains('SIL Open Font License'));
  });

  test('шрифты не скачиваются из сети: google_fonts не подключён', () {
    expect(pubspec, isNot(contains('google_fonts')));
  });

  test('вся шкала на семействе Inter с нужными весами', () {
    final text = AppTheme.light.textTheme;

    for (final style in [
      text.headlineLarge,
      text.headlineMedium,
      text.headlineSmall,
      text.titleLarge,
      text.titleMedium,
      text.bodyLarge,
      text.bodyMedium,
      text.bodySmall,
      text.labelSmall,
    ]) {
      expect(style?.fontFamily, AppTextTheme.fontFamily);
    }
    expect(text.headlineLarge?.fontWeight, FontWeight.w600);
    expect(text.bodyMedium?.fontWeight, FontWeight.w400);
  });

  test('Bold той же версии Inter, что и остальные начертания', () {
    String version(String path) {
      // Запись `name` ID 5 («Version 4.001;git-…») в кодировке UTF-16BE.
      final bytes = File(path).readAsBytesSync();
      final data = ByteData.sublistView(bytes);
      final tables = data.getUint16(4);
      for (var i = 0; i < tables; i++) {
        final record = 12 + 16 * i;
        final tag = String.fromCharCodes(bytes.sublist(record, record + 4));
        if (tag != 'name') continue;
        final offset = data.getUint32(record + 8);
        final count = data.getUint16(offset + 2);
        final strings = offset + data.getUint16(offset + 4);
        for (var r = 0; r < count; r++) {
          final at = offset + 6 + 12 * r;
          if (data.getUint16(at) != 3 || data.getUint16(at + 6) != 5) continue;
          final length = data.getUint16(at + 8);
          final start = strings + data.getUint16(at + 10);
          return String.fromCharCodes([
            for (var b = 0; b < length; b += 2) data.getUint16(start + b),
          ]);
        }
      }
      return '';
    }

    final versions = {
      for (final path in declaredFonts().keys) path: version(path),
    };

    expect(versions.values.toSet(), hasLength(1), reason: '$versions');
    expect(versions.values.toSet().single, startsWith('Version 4.001'));
  });

  test('w700 рисуется настоящим Bold: вес объявлен, синтетического утолщения нет', () {
    expect(declaredFonts()['assets/fonts/Inter_18pt-Bold.ttf'], 700);
    expect(AppTheme.light.textTheme.displaySmall?.fontWeight, FontWeight.w700);
    expect(AppTheme.light.textTheme.displaySmall?.fontFamily, AppTextTheme.fontFamily);
  });
}
