import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/network/auth_tokens.dart';
import 'package:mentorix_app/core/storage/storage_keys.dart';
import 'package:mentorix_app/core/storage/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<TokenStorage> create({
    Map<String, String> secure = const {},
    Map<String, Object> prefs = const {},
  }) async {
    // Мок пишет прямо в переданную карту, поэтому передаём изменяемую копию.
    FlutterSecureStorage.setMockInitialValues(Map.of(secure));
    SharedPreferences.setMockInitialValues(prefs);
    return TokenStorage(
      const FlutterSecureStorage(),
      await SharedPreferences.getInstance(),
    );
  }

  test('сохраняет и читает все четыре значения', () async {
    final storage = await create();
    final expiresAt = DateTime.utc(2030, 5, 6, 7, 8, 9);

    await storage.save(
      AuthTokens(
        accessToken: 'a',
        refreshToken: 'r',
        userId: 'u',
        expiresAt: expiresAt,
      ),
    );

    expect(await storage.readAccessToken(), 'a');
    expect(await storage.readRefreshToken(), 'r');
    expect(await storage.readUserId(), 'u');
    expect(await storage.readExpiresAt(), expiresAt);
    expect(await storage.hasSession(), isTrue);
  });

  test('токены не попадают в shared_preferences', () async {
    final storage = await create();
    await storage.save(
      const AuthTokens(accessToken: 'a', refreshToken: 'r', userId: 'u'),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getKeys().where((key) => !key.contains('install_flag')),
      isEmpty,
    );
  });

  test('clear удаляет всё', () async {
    final storage = await create();
    await storage.save(
      const AuthTokens(accessToken: 'a', refreshToken: 'r', userId: 'u'),
    );

    await storage.clear();

    expect(await storage.hasAnyToken(), isFalse);
    expect(await storage.readUserId(), isNull);
  });

  group('переустановка', () {
    test('нет флага установки — токены прошлой установки стираются', () async {
      final storage = await create(
        secure: {
          StorageKeys.accessToken: 'stale',
          StorageKeys.refreshToken: 'stale',
        },
      );

      await storage.ensureFreshInstall();

      expect(await storage.hasAnyToken(), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(StorageKeys.secureStorageInstallFlag), isTrue);
    });

    test('флаг есть — токены сохраняются', () async {
      final storage = await create(
        secure: {StorageKeys.accessToken: 'a', StorageKeys.refreshToken: 'r'},
        prefs: {StorageKeys.secureStorageInstallFlag: true},
      );

      await storage.ensureFreshInstall();

      expect(await storage.readRefreshToken(), 'r');
    });
  });

  group('AuthTokens.parseExpiresAt', () {
    test('ISO-8601, unix-секунды и миллисекунды', () {
      final expected = DateTime.utc(2030, 1, 1);
      final seconds = expected.millisecondsSinceEpoch ~/ 1000;

      expect(AuthTokens.parseExpiresAt('2030-01-01T00:00:00Z'), expected);
      expect(AuthTokens.parseExpiresAt(seconds), expected);
      expect(AuthTokens.parseExpiresAt('$seconds'), expected);
      expect(
        AuthTokens.parseExpiresAt(expected.millisecondsSinceEpoch),
        expected,
      );
    });

    test('мусор и null → null, а не исключение', () {
      expect(AuthTokens.parseExpiresAt(null), isNull);
      expect(AuthTokens.parseExpiresAt('когда-нибудь'), isNull);
      expect(AuthTokens.parseExpiresAt(<String>[]), isNull);
    });
  });

  group('AuthTokens.fromJson', () {
    test('без refresh_token — FormatException, а не половина сессии', () {
      expect(
        () => AuthTokens.fromJson({
          'access_token': 'a',
          'user_id': 'u',
        }),
        throwsFormatException,
      );
    });

    test('user_id как число приводится к строке', () {
      final tokens = AuthTokens.fromJson({
        'access_token': 'a',
        'refresh_token': 'r',
        'user_id': 42,
      });

      expect(tokens.userId, '42');
    });
  });
}
