import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mentorix_app/core/logging/app_logger.dart';
import 'package:mentorix_app/core/network/auth_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Токены сессии в `flutter_secure_storage`: access_token, refresh_token,
/// expires_at, user_id. В `shared_preferences` токены не попадают никогда.
class TokenStorage {
  TokenStorage(this._storage, this._prefs);

  /// iOS Keychain доступен после первой разблокировки, но не уходит в бэкапы
  /// и iCloud; на Android — EncryptedSharedPreferences с ключом в Keystore.
  static const secureStorageOptions = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Флаг лежит в `shared_preferences`: при удалении приложения он стирается,
  /// а Keychain на iOS — нет.
  static const installFlagKey = 'secure_storage_install_flag';

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _expiresKey = 'expires_at';
  static const _userIdKey = 'user_id';

  final FlutterSecureStorage _storage;
  final SharedPreferences _prefs;

  /// После переустановки Keychain хранит токены прошлой установки (на общем
  /// устройстве — возможно, чужого аккаунта). Нет флага — всё стираем.
  Future<void> ensureFreshInstall() async {
    if (_prefs.getBool(installFlagKey) ?? false) return;

    try {
      await _storage.deleteAll();
    } on PlatformException catch (e, st) {
      AppLogger.error('secure storage wipe failed', e, st);
    }
    await _prefs.setBool(installFlagKey, true);
  }

  Future<String?> readAccessToken() => _read(_accessKey);

  Future<String?> readRefreshToken() => _read(_refreshKey);

  Future<String?> readUserId() => _read(_userIdKey);

  Future<DateTime?> readExpiresAt() async {
    final raw = await _read(_expiresKey);
    return raw == null ? null : DateTime.tryParse(raw)?.toUtc();
  }

  /// Есть ли что восстанавливать: без refresh-токена сессии нет.
  Future<bool> hasSession() async => await readRefreshToken() != null;

  Future<bool> hasAnyToken() async =>
      await readRefreshToken() != null || await readAccessToken() != null;

  /// Refresh-токен пишется первым: он одноразовый, старый уже недействителен,
  /// и потерять новый хуже всего.
  Future<void> save(AuthTokens tokens) async {
    await _storage.write(key: _refreshKey, value: tokens.refreshToken);
    await _storage.write(key: _accessKey, value: tokens.accessToken);
    await _storage.write(key: _userIdKey, value: tokens.userId);

    final expiresAt = tokens.expiresAt;
    if (expiresAt == null) {
      await _storage.delete(key: _expiresKey);
    } else {
      await _storage.write(
        key: _expiresKey,
        value: expiresAt.toUtc().toIso8601String(),
      );
    }
  }

  Future<void> clear() async {
    for (final key in const [_accessKey, _refreshKey, _expiresKey, _userIdKey]) {
      try {
        await _storage.delete(key: key);
      } on PlatformException catch (e, st) {
        AppLogger.error('secure storage delete failed', e, st);
      }
    }
  }

  /// `KeyStoreException` на Android после обновления системы — это «токена
  /// нет»: пользователь увидит вход, а не бесконечный сбой.
  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } on PlatformException catch (e, st) {
      AppLogger.error('secure storage read failed', e, st);
      return null;
    }
  }
}
