import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/network/session_expired_exception.dart';
import 'package:mentorix_app/features/auth/data/mappers/auth_error_mapper.dart';
import 'package:mentorix_app/features/auth/data/mappers/invite_conflict_parser.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';

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
}
