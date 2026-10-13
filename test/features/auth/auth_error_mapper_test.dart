import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/network/api_error_codes.dart';
import 'package:mentorix_app/core/network/session_expired_exception.dart';
import 'package:mentorix_app/features/auth/data/mappers/auth_error_mapper.dart';
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

/// Ответ вида `{"code": ..., "message": ...}`.
DioException _coded(int status, String code, {String message = 'любой текст'}) =>
    _error(status, data: {'code': code, 'message': message});

void main() {
  group('AuthErrorMapper — ветвление по code', () {
    // Статус намеренно «не тот»: разбор идёт по code, а не по статусу.
    const cases = <String, Type>{
      ApiErrorCodes.rateLimited: TooManyRequestsFailure,
      ApiErrorCodes.invalidIdToken: SocialTokenRejectedFailure,
      ApiErrorCodes.missingAuthorization: SessionExpiredFailure,
      ApiErrorCodes.invalidToken: SessionExpiredFailure,
      ApiErrorCodes.invalidRefreshToken: SessionExpiredFailure,
      ApiErrorCodes.userNotFound: AccountNotFoundFailure,
      ApiErrorCodes.providerNotConfigured: ServerUnavailableFailure,
      ApiErrorCodes.invalidLinkCode: TelegramCodeInvalidFailure,
      ApiErrorCodes.telegramLinkConflict: TelegramLinkConflictFailure,
      ApiErrorCodes.telegramAlreadyLinked: TelegramAlreadyLinkedFailure,
      ApiErrorCodes.inviteNotFound: InviteNotFoundFailure,
      ApiErrorCodes.inviteExpired: InviteExpiredFailure,
      ApiErrorCodes.inviteConsumed: InviteAlreadyConsumedFailure,
      ApiErrorCodes.clientLimitReached: InviteClientLimitReachedFailure,
      ApiErrorCodes.selfInvite: InviteNotAllowedFailure,
      ApiErrorCodes.clientBlocked: InviteNotAllowedFailure,
      ApiErrorCodes.adminCannotAccept: AdminAccountFailure,
    };

    cases.forEach((code, expected) {
      test('$code → $expected', () {
        final failure = AuthErrorMapper.map(_coded(418, code));

        expect(failure.runtimeType, expected);
      });
    });

    test('два вида 409 на привязке Telegram различаются только кодом', () {
      // Тексты одинаковые — результат разный: message не разбирается.
      final conflict = AuthErrorMapper.map(
        _coded(409, ApiErrorCodes.telegramLinkConflict, message: 'conflict'),
      );
      final already = AuthErrorMapper.map(
        _coded(409, ApiErrorCodes.telegramAlreadyLinked, message: 'conflict'),
      );

      expect(conflict, isA<TelegramLinkConflictFailure>());
      expect(already, isA<TelegramAlreadyLinkedFailure>());
    });

    test('message не влияет на результат: ни текст, ни его отсутствие', () {
      // Старый разбор по тексту «invite already consumed» больше не работает.
      final byText = AuthErrorMapper.map(
        _error(409, data: {'message': 'invite already consumed'}),
      );
      final withCode = AuthErrorMapper.map(
        _coded(409, ApiErrorCodes.inviteConsumed, message: 'совсем другой'),
      );

      expect(byText, isA<UnknownFailure>());
      expect(withCode, isA<InviteAlreadyConsumedFailure>());
    });

    test('code приоритетнее статуса', () {
      final failure = AuthErrorMapper.map(
        _coded(503, ApiErrorCodes.inviteExpired),
      );

      expect(failure, isA<InviteExpiredFailure>());
    });
  });

  group('AuthErrorMapper — неизвестный code → общий текст по статусу', () {
    test('имена статусов вместо кодов: bad_request / not_found / conflict', () {
      expect(
        AuthErrorMapper.map(_coded(400, 'bad_request')),
        isA<InvalidRequestFailure>(),
      );
      expect(
        AuthErrorMapper.map(_coded(404, 'not_found')),
        isA<UnknownFailure>(),
      );
      expect(
        AuthErrorMapper.map(_coded(409, 'conflict')),
        isA<UnknownFailure>(),
      );
    });

    test('новый, ещё не известный клиенту code', () {
      expect(
        AuthErrorMapper.map(_coded(429, 'some_future_code')),
        isA<TooManyRequestsFailure>(),
      );
      expect(
        AuthErrorMapper.map(_coded(503, 'some_future_code')),
        isA<ServerUnavailableFailure>(),
      );
      expect(
        AuthErrorMapper.map(_coded(422, 'some_future_code')),
        isA<UnknownFailure>(),
      );
      expect(
        AuthErrorMapper.map(_coded(401, 'some_future_code')),
        isA<SessionExpiredFailure>(),
      );
    });

    test('тела нет, тело не объект или code не строка', () {
      expect(AuthErrorMapper.map(_error(400)), isA<InvalidRequestFailure>());
      expect(
        AuthErrorMapper.map(_error(500, data: 'Internal Server Error')),
        isA<UnknownFailure>(),
      );
      expect(
        AuthErrorMapper.map(_error(400, data: {'code': 42})),
        isA<InvalidRequestFailure>(),
      );
      expect(
        AuthErrorMapper.map(_error(400, data: {'code': ''})),
        isA<InvalidRequestFailure>(),
      );
    });

    test('вход: 401 без известного code — токен провайдера не принят', () {
      final failure = AuthErrorMapper.map(
        _error(401),
        endpoint: AuthErrorMapper.socialSignIn,
      );

      expect(failure, isA<SocialTokenRejectedFailure>());
    });

    test('на других эндпоинтах тот же 401 — конец сессии', () {
      expect(AuthErrorMapper.map(_error(401)), isA<SessionExpiredFailure>());
    });

    test('429 и 503 одинаковы для всех эндпоинтов', () {
      expect(
        AuthErrorMapper.map(
          _error(429),
          endpoint: AuthErrorMapper.socialSignIn,
        ),
        isA<TooManyRequestsFailure>(),
      );
      expect(
        AuthErrorMapper.map(_error(503)),
        isA<ServerUnavailableFailure>(),
      );
    });
  });

  group('AuthErrorMapper — без ответа сервера', () {
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
  _everyFailureHasText();
}

void _spendingTests() {
  group('какие ошибки тратят код Telegram', () {
    test('ответ сервера, кроме 429 и 401, код тратит', () {
      for (final failure in const <AuthFailure>[
        TelegramCodeInvalidFailure(), // 400
        AccountNotFoundFailure(), // 404
        TelegramLinkConflictFailure(), // 409
        TelegramAlreadyLinkedFailure(), // 409
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
  group('сообщение «не настроено»', () {
    const google = SocialSignInNotConfiguredFailure();
    const apple = SocialSignInNotConfiguredFailure(
      provider: SocialProvider.apple,
    );

    test('debug: подсказка, как запустить, на обоих языках', () {
      expect(
        google.message(AppLocalizationsRu(), debug: true),
        'Google sign-in не настроен: запусти с '
        '--dart-define-from-file=config/stage.json',
      );
      expect(
        apple.message(AppLocalizationsRu(), debug: true),
        startsWith('Apple sign-in не настроен'),
      );
      expect(
        google.message(AppLocalizationsEn(), debug: true),
        contains('--dart-define-from-file=config/stage.json'),
      );
      expect(
        apple.message(AppLocalizationsEn(), debug: true),
        contains('Apple sign-in is not configured'),
      );
    });

    test('release: общий текст, без подробностей запуска', () {
      final release = google.message(AppLocalizationsRu(), debug: false);

      expect(release, AppLocalizationsRu().errorSocialUnavailable);
      expect(release, isNot(contains('dart-define')));
      expect(
        apple.message(AppLocalizationsRu(), debug: false),
        AppLocalizationsRu().errorSocialUnavailable,
      );
    });

    test('в тестах kDebugMode включён: по умолчанию debug-текст', () {
      expect(
        google.message(AppLocalizationsRu()),
        AppLocalizationsRu().errorGoogleNotConfigured,
      );
    });

    test('«не настроено» и несовпадение state код Telegram не тратят', () {
      expect(google.spendsTelegramCode, isFalse);
      expect(
        const SocialSignInStateMismatchFailure().spendsTelegramCode,
        isFalse,
      );
    });
  });
}

void _everyFailureHasText() {
  test('у новых ошибок есть локализованный текст на обоих языках', () {
    for (final failure in const <AuthFailure>[
      TelegramAlreadyLinkedFailure(),
      TelegramLinkConflictFailure(),
      SocialSignInStateMismatchFailure(),
    ]) {
      expect(failure.message(AppLocalizationsRu()), isNotEmpty);
      expect(failure.message(AppLocalizationsEn()), isNotEmpty);
    }

    expect(
      const TelegramAlreadyLinkedFailure().message(AppLocalizationsRu()),
      isNot(const TelegramLinkConflictFailure().message(AppLocalizationsRu())),
    );
  });
}
