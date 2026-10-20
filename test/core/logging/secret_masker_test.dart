import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/logging/secret_masker.dart';

void main() {
  const mask = SecretMasker.mask;

  group('заголовки', () {
    test('Authorization скрыт без учёта регистра, остальные целы', () {
      final masked = SecretMasker.maskHeaders({
        'Authorization': 'Bearer SECRET',
        'authorization': 'Bearer SECRET',
        'AUTHORIZATION': 'Bearer SECRET',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      });

      expect(masked['Authorization'], mask);
      expect(masked['authorization'], mask);
      expect(masked['AUTHORIZATION'], mask);
      expect(masked['Content-Type'], 'application/json');
      expect(masked['Accept'], 'application/json');
    });

    test('Cookie и Set-Cookie тоже; значения-списки остаются списками', () {
      final masked = SecretMasker.maskHeaders({
        'Set-Cookie': ['sid=SECRET; HttpOnly'],
        'cookie': 'sid=SECRET',
        'etag': ['abc'],
      });

      expect(masked['Set-Cookie'], [mask]);
      expect(masked['cookie'], mask);
      expect(masked['etag'], ['abc']);
    });
  });

  group('тела', () {
    test('все перечисленные поля скрыты', () {
      final masked =
          SecretMasker.maskBody({
                'access_token': 'SECRET',
                'refresh_token': 'SECRET',
                'id_token': 'SECRET',
                'apple_id_token': 'SECRET',
                'apple_authorization_code': 'SECRET',
                'nonce': 'SECRET',
                'user_id': 'user-1',
                'token_type': 'Bearer',
                'email': 'user@example.com',
              })!
              as Map;

      for (final key in const [
        'access_token',
        'refresh_token',
        'id_token',
        'apple_id_token',
        'apple_authorization_code',
        'nonce',
      ]) {
        expect(masked[key], mask, reason: key);
      }
      // Остальное не тронуто, в том числе `token_type` (не `token`).
      expect(masked['user_id'], 'user-1');
      expect(masked['token_type'], 'Bearer');
      expect(masked['email'], 'user@example.com');
    });

    test('вложенные объекты и списки', () {
      final masked =
          SecretMasker.maskBody({
                'data': {
                  'session': {'access_token': 'SECRET', 'ok': true},
                  'items': [
                    {'refresh_token': 'SECRET'},
                    [
                      {'id_token': 'SECRET'},
                    ],
                  ],
                },
              })!
              as Map;

      final text = masked.toString();
      expect(text, isNot(contains('SECRET')));
      expect((masked['data'] as Map)['session']['ok'], true);
    });

    test('JSON внутри строки', () {
      final masked = SecretMasker.maskBody(
        '{"access_token":"SECRET","nested":{"refresh_token":"SECRET"},"a":1}',
      );

      expect(masked, isA<String>());
      expect(masked as String, isNot(contains('SECRET')));
      expect(masked, contains('"a":1'));
    });

    test('не JSON и числа возвращаются как есть', () {
      expect(SecretMasker.maskBody('Internal Server Error'), 'Internal Server Error');
      expect(SecretMasker.maskBody(42), 42);
      expect(SecretMasker.maskBody(null), isNull);
      expect(SecretMasker.maskBody('{битый json'), '{битый json');
    });

    test('исходный объект не изменяется', () {
      final original = {
        'access_token': 'SECRET',
        'nested': {'refresh_token': 'SECRET'},
      };

      SecretMasker.maskBody(original);

      expect(original['access_token'], 'SECRET');
      expect((original['nested']! as Map)['refresh_token'], 'SECRET');
    });
  });

  group('code', () {
    test('по умолчанию — код ошибки, виден', () {
      final masked =
          SecretMasker.maskBody({'code': 'invalid_link_code', 'message': 'x'})!
              as Map;

      expect(masked['code'], 'invalid_link_code');
    });

    test('в теле привязки Telegram — секрет', () {
      final masked =
          SecretMasker.maskBody({'code': 'ABCD1234'}, maskCode: true)! as Map;

      expect(masked['code'], mask);
    });
  });
}
