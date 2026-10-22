import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Строка добавляется сразу во все ARB-файлы (`CLAUDE.md`, раздел 7): набор
/// ключей в русском и английском совпадает, значения не пустые.
void main() {
  Map<String, dynamic> load(String locale) =>
      jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
          as Map<String, dynamic>;

  final en = load('en');
  final ru = load('ru');

  Set<String> messageKeys(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  test('ключи ru и en совпадают', () {
    final enKeys = messageKeys(en);
    final ruKeys = messageKeys(ru);

    expect(enKeys.difference(ruKeys), isEmpty, reason: 'нет в app_ru.arb');
    expect(ruKeys.difference(enKeys), isEmpty, reason: 'нет в app_en.arb');
  });

  test('значения не пустые', () {
    for (final arb in [en, ru]) {
      for (final key in messageKeys(arb)) {
        final value = arb[key];
        if (key == '@@locale') continue;
        expect(value is String && value.trim().isNotEmpty, isTrue, reason: key);
      }
    }
  });
}
