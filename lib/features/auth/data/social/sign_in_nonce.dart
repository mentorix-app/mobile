import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Одноразовое значение одной попытки входа (`nonce`).
///
/// Провайдеру (Apple, Google) отдаётся [hashed] — hex(SHA-256) в нижнем регистре;
/// он попадает в `id_token`. Бэкенду уходит исходная строка [raw]: он хеширует её
/// сам и сверяет с токеном, при несовпадении отвечает 401 `invalid_id_token`.
///
/// На каждую попытку входа — новый [SignInNonce]; повторно не используется.
class SignInNonce {
  const SignInNonce(this.raw);

  /// 32 байта из `Random.secure()`, base64url без заполнения.
  factory SignInNonce.generate() => SignInNonce(randomUrlSafe());

  /// Исходная строка: уходит только на бэкенд, в логах — `***`.
  final String raw;

  /// hex(SHA-256([raw])) в нижнем регистре: уходит провайдеру.
  String get hashed => hash(raw);

  static String hash(String value) =>
      sha256.convert(utf8.encode(value)).toString();

  /// [length] случайных байт, base64url без заполнения. [random] — для тестов.
  static String randomUrlSafe({int length = 32, Random? random}) {
    final source = random ?? Random.secure();
    final bytes = List<int>.generate(length, (_) => source.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
