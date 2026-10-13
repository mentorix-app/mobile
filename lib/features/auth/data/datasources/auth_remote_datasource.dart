import 'package:dio/dio.dart';
import 'package:mentorix_app/core/config/api_endpoints.dart';
import 'package:mentorix_app/core/logging/app_logger.dart';
import 'package:mentorix_app/core/logging/debug_log.dart';
import 'package:mentorix_app/core/network/auth_interceptor.dart';
import 'package:mentorix_app/core/network/auth_tokens.dart';
import 'package:mentorix_app/features/auth/data/mappers/auth_error_mapper.dart';
import 'package:mentorix_app/features/auth/data/models/apple_deletion_proof.dart';
import 'package:mentorix_app/features/auth/data/models/invite_acceptance_model.dart';
import 'package:mentorix_app/features/auth/data/models/linked_trainer_model.dart';
import 'package:mentorix_app/features/auth/data/models/user_profile_model.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';

/// Эндпоинты из `docs/auth_api.md`. Бросает только [AuthFailure].
///
/// Все запросы идут через основной `Dio`. Публичные (`/auth/google`,
/// `/auth/apple`, `/auth/logout`) помечены `skipAuth`: перехватчик их не трогает —
/// не подставляет Bearer, не делает упреждающий refresh и не принимает 401 за
/// «сессия истекла» (на входе это «токен провайдера не принят», а refresh перед
/// logout отправил бы в тело уже недействительный refresh-токен).
class AuthRemoteDataSource {
  AuthRemoteDataSource({required Dio apiDio}) : _dio = apiDio;

  final Dio _dio;

  static final _public = Options(extra: {AuthInterceptor.skipAuthKey: true});

  Future<AuthTokens> signInWithGoogle(String idToken) => _guard(
    endpoint: AuthErrorMapper.socialSignIn,
    () async {
      final response = await _dio.post<Object?>(
        ApiEndpoints.authGoogle,
        data: {'id_token': idToken},
        options: _public,
      );
      return AuthTokens.fromJson(_object(response));
    },
  );

  /// [name] — только при первой авторизации в Apple; дальше сервер его игнорирует.
  Future<AuthTokens> signInWithApple(String idToken, {String? name}) => _guard(
    endpoint: AuthErrorMapper.socialSignIn,
    () async {
      // Только debug: есть ли в теле `name` и что именно ушло. `id_token` не
      // пишется.
      DebugLog.write(
        'mentorix.apple',
        'POST ${ApiEndpoints.authApple} body: '
        'id_token=${DebugLog.yesNo(idToken)} '
        'name=${name == null ? 'absent' : DebugLog.quoted(name)}',
      );

      final response = await _dio.post<Object?>(
        ApiEndpoints.authApple,
        data: {'id_token': idToken, 'name': ?name},
        options: _public,
      );
      return AuthTokens.fromJson(_object(response));
    },
  );

  /// Нужен `Content-Type: application/json` (задан в `BaseOptions`), иначе
  /// сервер вернёт 204, но сессию не завершит.
  Future<void> logout(String refreshToken) => _guard(() async {
    await _dio.post<Object?>(
      ApiEndpoints.authLogout,
      data: {'refresh_token': refreshToken},
      options: _public,
    );
  });

  Future<void> logoutAll() => _guard(() async {
    await _dio.post<Object?>(ApiEndpoints.authLogoutAll);
  });

  Future<UserProfileModel> getMe() => _guard(() async {
    final response = await _dio.get<Object?>(ApiEndpoints.authMe);
    return UserProfileModel.fromJson(_object(response));
  });

  /// Описания тела ответа у PATCH в контракте нет — ответ не разбирается.
  Future<void> updateName(String name) => _guard(() async {
    await _dio.patch<Object?>(ApiEndpoints.authMe, data: {'name': name});
  });

  /// `DELETE /auth/me`: 204 без тела. Без [apple] — тело не отправляется; для
  /// аккаунтов со входом через Apple бэкенд ответит 422
  /// `apple_authorization_required`, и запрос повторяют с [apple]. Тело — только
  /// с `Content-Type: application/json`, иначе 400.
  Future<void> deleteAccount({AppleDeletionProof? apple}) =>
      _guard(endpoint: AuthErrorMapper.accountDeletion, () async {
        // Только да/нет: значения токена и кода в лог не попадают.
        DebugLog.write(
          'mentorix.delete',
          apple == null
              ? 'DELETE ${ApiEndpoints.authMe} body: none'
              : 'DELETE ${ApiEndpoints.authMe} body: '
                    'apple_id_token=${DebugLog.yesNo(apple.idToken)} '
                    'apple_authorization_code='
                    '${DebugLog.yesNo(apple.authorizationCode)} '
                    'apple_redirect_uri=${DebugLog.yesNo(apple.redirectUri)}',
        );

        await _dio.delete<Object?>(
          ApiEndpoints.authMe,
          data: apple?.toJson(),
          options: apple == null
              ? null
              : Options(contentType: Headers.jsonContentType),
        );
      });

  /// `GET /client/trainers`: `items` всегда массив, пустой — тренера нет.
  /// Вызывается после `GET /auth/me`.
  Future<List<LinkedTrainerModel>> getTrainers() => _guard(() async {
    final response = await _dio.get<Object?>(ApiEndpoints.clientTrainers);
    return LinkedTrainerModel.listFromJson(_object(response));
  });

  Future<AuthTokens> linkTelegram(String code) => _guard(() async {
    final response = await _dio.post<Object?>(
      ApiEndpoints.authTelegramLink,
      data: {'code': code},
    );
    return AuthTokens.fromJson(_object(response));
  });

  Future<InviteAcceptanceModel> acceptInvite(String token) => _guard(() async {
    final response = await _dio.post<Object?>(
      ApiEndpoints.clientInviteAccept,
      data: {'token': token},
    );
    return InviteAcceptanceModel.fromJson(_object(response));
  });

  Map<String, dynamic> _object(Response<Object?> response) {
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    throw const FormatException('response body is not a JSON object');
  }

  Future<T> _guard<T>(
    Future<T> Function() action, {
    EndpointFailureMapper? endpoint,
  }) async {
    try {
      return await action();
    } on DioException catch (e, st) {
      AppLogger.dioError(e, st);
      throw AuthErrorMapper.map(e, endpoint: endpoint);
    } on FormatException catch (e, st) {
      // Ответ не того вида: сырой текст — в лог, пользователю — «что-то не так».
      AppLogger.error('unexpected auth response', e, st);
      throw const UnknownFailure();
    }
  }
}
