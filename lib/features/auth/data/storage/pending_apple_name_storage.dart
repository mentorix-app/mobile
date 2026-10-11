import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mentorix_app/core/logging/app_logger.dart';

/// Имя из Apple, которое ещё не принял бэкенд.
///
/// Apple отдаёт имя только при первой авторизации: если запрос упал по сети,
/// второй раз имени уже не будет. Поэтому оно хранится до успешного ответа.
/// Имя — персональные данные, потому лежит в защищённом хранилище.
class PendingAppleNameStorage {
  PendingAppleNameStorage(this._storage);

  static const _key = 'pending_apple_name';

  final FlutterSecureStorage _storage;

  Future<String?> read() async {
    try {
      final value = await _storage.read(key: _key);
      return value == null || value.isEmpty ? null : value;
    } on PlatformException catch (e, st) {
      AppLogger.error('pending apple name read failed', e, st);
      return null;
    }
  }

  Future<void> save(String name) async {
    try {
      await _storage.write(key: _key, value: name);
    } on PlatformException catch (e, st) {
      AppLogger.error('pending apple name write failed', e, st);
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } on PlatformException catch (e, st) {
      AppLogger.error('pending apple name delete failed', e, st);
    }
  }
}
