import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/logging/debug_log.dart';
import 'package:mentorix_app/features/auth/data/mappers/auth_error_mapper.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';
import 'package:mentorix_app/features/auth/presentation/auth_failure_message.dart';
import 'package:mentorix_app/l10n/generated/app_localizations_en.dart';
import 'package:mentorix_app/l10n/generated/app_localizations_ru.dart';

DioException _error(int status, {Object? body, String path = '/auth/me'}) {
  final options = RequestOptions(path: path, method: 'DELETE');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<Object?>(
      requestOptions: options,
      statusCode: status,
      data: body,
    ),
  );
}

/// Статус и `code` рядом с текстом ошибки — только в debug-сборке.
void main() {
  final ru = AppLocalizationsRu();
  final en = AppLocalizationsEn();

  tearDown(() => DebugLog.debugModeOverride = null);

  group('debug: к тексту добавляются статус и code', () {
    test('503 provider_not_configured на удалении аккаунта', () {
      final failure = AuthErrorMapper.map(
        _error(503, body: {'code': 'provider_not_configured', 'message': 'x'}),
        endpoint: AuthErrorMapper.accountDeletion,
      );

      expect(failure, isA<AccountDeletionFailedFailure>());
      expect(
        failure.message(ru),
        '${ru.errorAccountDeletionFailed} (503 provider_not_configured)',
      );
      expect(
        failure.message(en),
        '${en.errorAccountDeletionFailed} (503 provider_not_configured)',
      );
    });

    test('статус без code', () {
      final failure = AuthErrorMapper.map(_error(500, body: 'oops'));

      expect(failure.message(ru), '${ru.errorUnknown} (500)');
    });

    test('сбой без ответа сервера — тип ошибки', () {
      final failure = AuthErrorMapper.map(
        DioException.connectionError(
          requestOptions: RequestOptions(path: '/auth/me'),
          reason: 'offline',
        ),
      );

      expect(failure, isA<NetworkFailure>());
      expect(failure.message(ru), '${ru.errorNetwork} (connectionError)');
    });

    test('тип ошибки не меняется от того, что приложен ответ', () {
      final failure = AuthErrorMapper.map(
        _error(409, body: {'code': 'telegram_already_linked'}),
      );

      expect(failure, isA<TelegramAlreadyLinkedFailure>());
      expect(failure.details?.status, 409);
      expect(failure.details?.code, 'telegram_already_linked');
    });

    test('сохраняется провайдер у «не настроено»', () {
      const failure = SocialSignInNotConfiguredFailure(
        provider: SocialProvider.apple,
      );

      final copy = failure.withDetails(const ApiErrorDetails(status: 503));

      expect(
        copy,
        isA<SocialSignInNotConfiguredFailure>().having(
          (f) => f.provider,
          'provider',
          SocialProvider.apple,
        ),
      );
    });
  });

  group('release: только обычный текст', () {
    setUp(() => DebugLog.debugModeOverride = false);

    test('details не создаётся, code и статус в тексте не показываются', () {
      final failure = AuthErrorMapper.map(
        _error(503, body: {'code': 'provider_not_configured'}),
        endpoint: AuthErrorMapper.accountDeletion,
      );

      expect(failure.details, isNull);
      final text = failure.message(ru);
      expect(text, ru.errorAccountDeletionFailed);
      expect(text, isNot(contains('503')));
      expect(text, isNot(contains('provider_not_configured')));
    });

    test('даже если details приложены, release их не показывает', () {
      const failure = AccountDeletionFailedFailure(
        details: ApiErrorDetails(status: 503, code: 'provider_not_configured'),
      );

      expect(failure.message(ru), ru.errorAccountDeletionFailed);
      expect(failure.message(ru, debug: false), ru.errorAccountDeletionFailed);
    });

    test('сетевой сбой — без типа ошибки', () {
      final failure = AuthErrorMapper.map(
        DioException.connectionError(
          requestOptions: RequestOptions(path: '/auth/me'),
          reason: 'offline',
        ),
      );

      expect(failure.message(ru), ru.errorNetwork);
    });
  });
}
