import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/network/session_expired_exception.dart';
import 'package:mentorix_app/features/auth/data/mappers/auth_error_mapper.dart';
import 'package:mentorix_app/features/auth/data/mappers/invite_conflict_parser.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';
import 'package:mentorix_app/features/auth/presentation/auth_failure_message.dart';
import 'package:mentorix_app/l10n/generated/app_localizations_en.dart';
import 'package:mentorix_app/l10n/generated/app_localizations_ru.dart';

DioException _error(int status, {Object? data, DioExceptionType? type}) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    type: type ?? DioExceptionType.badResponse,
    response: Response<Object?>(
      requestOptions: options,
      statusCode: status,
      data: data,
    ),
  );
}

void main() {
  group('InviteConflictParser — 409 по message', () {
    test('invite already consumed', () {
      expect(
        InviteConflictParser.parse('invite already consumed'),
        isA<InviteAlreadyConsumedFailure>(),
      );
    });

    test('client limit reached', () {
      expect(
        InviteConflictParser.parse('client limit reached'),
        isA<InviteClientLimitReachedFailure>(),
      );
    });

    test('регистр и обрамляющий текст не важны', () {
      expect(
        InviteConflictParser.parse('Conflict: Client Limit Reached.'),
        isA<InviteClientLimitReachedFailure>(),
      );
    });

    test('неизвестный текст и null — общая ошибка 409', () {
      expect(
        InviteConflictParser.parse('something new'),
        isA<InviteConflictFailure>(),
      );
      expect(InviteConflictParser.parse(null), isA<InviteConflictFailure>());
    });
  });

  group('AuthErrorMapper', () {
    test('приглашение: 409 разбирается по message', () {
      final failure = AuthErrorMapper.map(
        _error(409, data: {'message': 'invite already consumed'}),
        endpoint: AuthErrorMapper.inviteAccept,
      );

      expect(failure, isA<InviteAlreadyConsumedFailure>());
    });

    test('приглашение: остальные статусы из контракта', () {
      AuthFailure map(int status) => AuthErrorMapper.map(
        _error(status),
        endpoint: AuthErrorMapper.inviteAccept,
      );

      expect(map(404), isA<InviteNotFoundFailure>());
      expect(map(410), isA<InviteExpiredFailure>());
      expect(map(422), isA<InviteNotAllowedFailure>());
      expect(map(403), isA<AdminAccountFailure>());
    });

    test('Telegram: 400 / 404 / 409', () {
      AuthFailure map(int status) => AuthErrorMapper.map(
        _error(status),
        endpoint: AuthErrorMapper.telegramLink,
      );

      expect(map(400), isA<TelegramCodeInvalidFailure>());
      expect(map(404), isA<AccountNotFoundFailure>());
      expect(map(409), isA<TelegramLinkConflictFailure>());
    });

    test('/auth/me: 404 — учётной записи больше нет', () {
      final failure = AuthErrorMapper.map(
        _error(404),
        endpoint: AuthErrorMapper.profile,
      );

      expect(failure, isA<AccountNotFoundFailure>());
    });

    test('404 на других эндпоинтах значит своё', () {
      // На /auth/me 404 — конец сессии, на этих — нет: разбор у каждого свой.
      expect(
        AuthErrorMapper.map(
          _error(404),
          endpoint: AuthErrorMapper.inviteAccept,
        ),
        isA<InviteNotFoundFailure>(),
      );
      expect(
        AuthErrorMapper.map(_error(404)),
        isA<UnknownFailure>(),
        reason: 'без разбора эндпоинта 404 — не конец сессии',
      );
    });

    test('Telegram 409: текст message сохраняется в ошибке', () {
      final failure = AuthErrorMapper.map(
        _error(409, data: {'message': '  telegram already linked  '}),
        endpoint: AuthErrorMapper.telegramLink,
      );

      expect(failure, isA<TelegramLinkConflictFailure>());
      expect(
        (failure as TelegramLinkConflictFailure).message,
        'telegram already linked',
      );
    });

    test('Telegram 409 без message: текста нет', () {
      final failure = AuthErrorMapper.map(
        _error(409, data: {'message': '   '}),
        endpoint: AuthErrorMapper.telegramLink,
      );

      expect((failure as TelegramLinkConflictFailure).message, isNull);
    });

    test('вход: 401 — токен провайдера не принят', () {
      final failure = AuthErrorMapper.map(
        _error(401),
        endpoint: AuthErrorMapper.socialSignIn,
      );

      expect(failure, isA<SocialTokenRejectedFailure>());
    });

    test('429 и 503 одинаковы для всех эндпоинтов', () {
      expect(
        AuthErrorMapper.map(
          _error(429),
          endpoint: AuthErrorMapper.telegramLink,
        ),
        isA<TooManyRequestsFailure>(),
      );
      expect(
        AuthErrorMapper.map(_error(503)),
        isA<ServerUnavailableFailure>(),
      );
    });

    test('таймаут и обрыв связи — сеть', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.connectionError,
      ]) {
        expect(
          AuthErrorMapper.map(
            DioException(requestOptions: RequestOptions(path: '/x'), type: type),
          ),
          isA<NetworkFailure>(),
        );
      }
    });

    test('конец сессии из перехватчика', () {
      final failure = AuthErrorMapper.map(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          error: const SessionExpiredException(),
        ),
      );

      expect(failure, isA<SessionExpiredFailure>());
    });
  });

  _spendingTests();
  _notConfiguredMessageTests();
}

void _spendingTests() {
  group('какие ошибки тратят код Telegram', () {
    test('ответ сервера, кроме 429 и 401, код тратит', () {
      for (final failure in const <AuthFailure>[
        TelegramCodeInvalidFailure(), // 400
        AccountNotFoundFailure(), // 404
        TelegramLinkConflictFailure(), // 409
        ServerUnavailableFailure(), // 503
        UnknownFailure(), // 5xx и прочее
      ]) {
        expect(failure.spendsTelegramCode, isTrue, reason: '$failure');
      }
    });

    test('429, 401 и обрыв связи код не тратят', () {
      for (final failure in const <AuthFailure>[
        TooManyRequestsFailure(), // 429
        SessionExpiredFailure(), // 401
        NetworkFailure(), // ответа сервера не было
      ]) {
        expect(failure.spendsTelegramCode, isFalse, reason: '$failure');
      }
    });
  });
}

void _notConfiguredMessageTests() {
  group('сообщение «Google не настроен»', () {
    const failure = SocialSignInNotConfiguredFailure();

    test('debug: подсказка, как запустить, на обоих языках', () {
      expect(
        failure.message(AppLocalizationsRu(), debug: true),
        'Google sign-in не настроен: запусти с '
        '--dart-define-from-file=config/stage.json',
      );
      expect(
        failure.message(AppLocalizationsEn(), debug: true),
        contains('--dart-define-from-file=config/stage.json'),
      );
    });

    test('release: общий текст, без подробностей запуска', () {
      final release = failure.message(AppLocalizationsRu(), debug: false);

      expect(release, AppLocalizationsRu().errorSocialUnavailable);
      expect(release, isNot(contains('dart-define')));
    });

    test('в тестах kDebugMode включён: по умолчанию debug-текст', () {
      expect(
        failure.message(AppLocalizationsRu()),
        AppLocalizationsRu().errorGoogleNotConfigured,
      );
    });

    test('«не настроено» код Telegram не тратит', () {
      expect(failure.spendsTelegramCode, isFalse);
    });
  });
}
