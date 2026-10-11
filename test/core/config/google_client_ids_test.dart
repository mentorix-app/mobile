import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `config/stage.json` (читает Dart) и `ios/Runner/Info.plist` (читает iOS SDK)
/// хранят одни и те же client id: расхождение даёт токен с чужим `aud`.
void main() {
  late Map<String, dynamic> stage;
  late String infoPlist;

  setUpAll(() {
    stage =
        jsonDecode(File('config/stage.json').readAsStringSync())
            as Map<String, dynamic>;
    infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
  });

  String plistString(String key) {
    final match = RegExp(
      '<key>$key</key>\\s*<string>([^<]*)</string>',
    ).firstMatch(infoPlist);
    expect(match, isNotNull, reason: 'в Info.plist нет ключа $key');
    return match!.group(1)!;
  }

  test('в config/stage.json заданы все ключи', () {
    for (final key in const [
      'API_BASE_URL',
      'GOOGLE_SERVER_CLIENT_ID',
      'GOOGLE_IOS_CLIENT_ID',
      'TELEGRAM_BOT_NAME',
    ]) {
      expect(stage[key], isA<String>(), reason: key);
      expect((stage[key] as String).isNotEmpty, isTrue, reason: key);
    }
  });

  test('client id в stage.json — не плейсхолдеры и не перепутаны', () {
    final web = stage['GOOGLE_SERVER_CLIENT_ID'] as String;
    final ios = stage['GOOGLE_IOS_CLIENT_ID'] as String;

    expect(web, endsWith('.apps.googleusercontent.com'));
    expect(ios, endsWith('.apps.googleusercontent.com'));
    expect(web, isNot(startsWith('YOUR_')));
    expect(ios, isNot(startsWith('YOUR_')));
    expect(web, isNot(ios), reason: 'web и iOS — разные клиенты');
  });

  test('Info.plist: GIDClientID — iOS-клиент, GIDServerClientID — web-клиент', () {
    expect(plistString('GIDClientID'), stage['GOOGLE_IOS_CLIENT_ID']);
    expect(plistString('GIDServerClientID'), stage['GOOGLE_SERVER_CLIENT_ID']);
  });

  test('Info.plist: URL scheme — iOS client id в обратном порядке', () {
    final ios = stage['GOOGLE_IOS_CLIENT_ID'] as String;
    final withoutSuffix = ios.replaceFirst('.apps.googleusercontent.com', '');
    final expectedScheme = 'com.googleusercontent.apps.$withoutSuffix';

    final schemes = RegExp(
      r'<key>CFBundleURLSchemes</key>\s*<array>(.*?)</array>',
      dotAll: true,
    ).firstMatch(infoPlist);

    expect(schemes, isNotNull, reason: 'нет CFBundleURLSchemes');
    expect(schemes!.group(1), contains('<string>$expectedScheme</string>'));
  });
}
