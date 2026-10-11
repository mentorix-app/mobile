import 'package:dio/dio.dart';
import 'package:mentorix_app/core/logging/app_logger.dart';
import 'package:mentorix_app/core/network/auth_interceptor.dart';
import 'package:mentorix_app/core/network/auth_tokens.dart';
import 'package:mentorix_app/features/auth/data/mappers/auth_error_mapper.dart';
import 'package:mentorix_app/features/auth/data/models/invite_acceptance_model.dart';
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
        '/auth/google',
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
      final response = await _dio.post<Object?>(
        '/auth/apple',
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
      '/auth/logout',
      data: {'refresh_token': refreshToken},
      options: _public,
    );
  });

  Future<void> logoutAll() => _guard(() async {
    await _dio.post<Object?>('/auth/logout-all');
  });

  Future<UserProfileModel> getMe() => _guard(() async {
    final response = await _dio.get<Object?>('/auth/me');
    return UserProfileModel.fromJson(_object(response));
  });

  /// Описания тела ответа у PATCH в контракте нет — ответ не разбирается.
  Future<void> updateName(String name) => _guard(() async {
    await _dio.patch<Object?>('/auth/me', data: {'name': name});
  });

  Future<AuthTokens> linkTelegram(String code) => _guard(
    endpoint: AuthErrorMapper.telegramLink,
    () async {
      final response = await _dio.post<Object?>(
        '/auth/telegram/link',
        data: {'code': code},
      );
      return AuthTokens.fromJson(_object(response));
    },
  );

  Future<InviteAcceptanceModel> acceptInvite(String token) => _guard(
    endpoint: AuthErrorMapper.inviteAccept,
    () async {
      final response = await _dio.post<Object?>(
        '/client/invites/accept',
        data: {'token': token},
      );
      return InviteAcceptanceModel.fromJson(_object(response));
    },
  );

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
