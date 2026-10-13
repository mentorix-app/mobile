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
    test('ISO 8601 в UTC — формат контракта', () {
      final expected = DateTime.utc(2026, 10, 12, 6, 15);

      expect(AuthTokens.parseExpiresAt('2026-10-12T06:15:00Z'), expected);
      expect(
        AuthTokens.parseExpiresAt('2026-10-12T09:15:00+03:00'),
        expected,
        reason: 'смещение приводится к UTC',
      );
      expect(AuthTokens.parseExpiresAt('2026-10-12T06:15:00Z')!.isUtc, isTrue);
    });

    test('unix-время бэкенд больше не присылает: число → null', () {
      expect(AuthTokens.parseExpiresAt(1893456000), isNull);
      expect(AuthTokens.parseExpiresAt('1893456000'), isNull);
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

    test('user_id — UUID строкой', () {
      final tokens = AuthTokens.fromJson({
        'access_token': 'a',
        'refresh_token': 'r',
        'user_id': '0b6e4f0e-3c1d-4a8e-9b7a-1f2d3c4b5a69',
        'expires_at': '2026-10-12T06:15:00Z',
      });

      expect(tokens.userId, '0b6e4f0e-3c1d-4a8e-9b7a-1f2d3c4b5a69');
      expect(tokens.expiresAt, DateTime.utc(2026, 10, 12, 6, 15));
    });

    test('user_id числом — не тот ответ: FormatException', () {
      expect(
        () => AuthTokens.fromJson({
          'access_token': 'a',
          'refresh_token': 'r',
          'user_id': 42,
        }),
        throwsFormatException,
      );
    });
  });
}
