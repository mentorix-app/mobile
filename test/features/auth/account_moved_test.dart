import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mentorix_app/app.dart';
import 'package:mentorix_app/core/config/api_endpoints.dart';
import 'package:mentorix_app/core/network/api_error_codes.dart';
import 'package:mentorix_app/core/network/auth_interceptor.dart';
import 'package:mentorix_app/core/network/auth_tokens.dart';
import 'package:mentorix_app/core/network/session_expired_notifier.dart';
import 'package:mentorix_app/core/router/app_router.dart';
import 'package:mentorix_app/core/router/onboarding_flow.dart';
import 'package:mentorix_app/core/storage/storage_keys.dart';
import 'package:mentorix_app/core/storage/token_storage.dart';
import 'package:mentorix_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:mentorix_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mentorix_app/features/auth/data/storage/pending_apple_name_storage.dart';
import 'package:mentorix_app/features/auth/domain/entities/social_credential.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';
import 'package:mentorix_app/features/auth/domain/providers/social_auth_provider.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/login_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_state.dart';
import 'package:mentorix_app/features/auth/presentation/screens/login_screen.dart';
import 'package:mentorix_app/features/auth/presentation/screens/splash_screen.dart';
import 'package:mentorix_app/features/theme/data/repositories/theme_repository_impl.dart';
import 'package:mentorix_app/features/theme/presentation/cubit/theme_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_http_adapter.dart';

class _NoSocialProvider implements SocialAuthProvider {
  @override
  bool get isAvailable => true;

  @override
  Future<SocialCredential> signIn() async =>
      throw const SocialSignInUnavailableFailure();

  @override
  Future<void> disconnect() async {}
}

Map<String, Object?> _error(String code) => {
  'code': code,
  // Текст бэкенд вправе менять: клиент его не разбирает.
  'message': 'любой текст',
};

/// Весь стек без подмен репозитория: Dio + перехватчик + датасорс + репозиторий +
/// `SessionCubit` + роутер, а HTTP — сценарный адаптер.
void main() {
  late FakeHttpAdapter adapter;
  late TokenStorage tokens;
  late SessionCubit session;
  late SharedPreferences prefs;
  late AuthRepositoryImpl repository;
  late AuthRemoteDataSource remote;
  late SessionExpiredNotifier notifier;
  late int sessionExpiredEvents;

  Future<void> setUpStack(FakeResponder responder) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      // Флаг установки: иначе «чистая установка» сотрёт токены на старте.
      StorageKeys.secureStorageInstallFlag: true,
    });
    prefs = await SharedPreferences.getInstance();
    tokens = TokenStorage(const FlutterSecureStorage(), prefs);

    // Старые токены: после переноса учётной записи они ещё лежат на устройстве.
    await tokens.save(
      const AuthTokens(
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
        userId: 'old-user',
      ),
    );

    adapter = FakeHttpAdapter(responder);
    notifier = SessionExpiredNotifier();
    sessionExpiredEvents = 0;
    notifier.stream.listen((_) => sessionExpiredEvents++);

    BaseOptions baseOptions() => BaseOptions(
      baseUrl: 'https://api.test',
      contentType: Headers.jsonContentType,
    );
    final plainDio = Dio(baseOptions())..httpClientAdapter = adapter;
    final apiDio = Dio(baseOptions())
      ..httpClientAdapter = adapter
      ..interceptors.add(
        AuthInterceptor(
          tokens: tokens,
          plainDio: plainDio,
          sessionExpired: notifier,
        ),
      );

    remote = AuthRemoteDataSource(apiDio: apiDio);
    repository = AuthRepositoryImpl(
      remote: remote,
      tokens: tokens,
      sessionExpired: notifier,
      pendingAppleName: PendingAppleNameStorage(const FlutterSecureStorage()),
      google: _NoSocialProvider(),
      apple: _NoSocialProvider(),
    );
    session = SessionCubit(repository, notifier);
  }

  tearDown(() async {
    await session.close();
    await GetIt.I.reset();
  });

  testWidgets(
    'старые токены после переноса учётной записи: /auth/me 404 '
    'user_not_found → экран входа, а не заставка',
    (tester) async {
      await setUpStack((options) async {
        if (options.path == ApiEndpoints.authMe) {
          return jsonBody(_error(ApiErrorCodes.userNotFound), status: 404);
        }
        return jsonBody(_error(ApiErrorCodes.invalidToken), status: 401);
      });

      GetIt.I.registerFactory<LoginCubit>(
        () => LoginCubit(repository, session),
      );

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<ThemeCubit>(
              create: (_) => ThemeCubit(ThemeRepositoryImpl(prefs)),
            ),
            BlocProvider<SessionCubit>.value(value: session),
          ],
          child: MentorixApp(
            router: createAppRouter(
              session: session,
              flow: OnboardingFlow(prefs),
            ),
          ),
        ),
      );

      // На старте сессия неизвестна — заставка.
      expect(find.byType(SplashScreen), findsOneWidget);

      unawaited(session.start());
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);

      // Токены очищены, лишних запросов нет: 404 — не 401, refresh не нужен.
      expect(await tokens.readAccessToken(), isNull);
      expect(await tokens.readRefreshToken(), isNull);
      expect(adapter.requestsTo(ApiEndpoints.authMe), hasLength(1));
      expect(adapter.requestsTo(ApiEndpoints.authRefresh), isEmpty);
      expect(sessionExpiredEvents, 1);
    },
  );

  test('/client/trainers 404 user_not_found — тоже конец сессии', () async {
    await setUpStack((options) async {
      if (options.path == ApiEndpoints.authMe) {
        return jsonBody({
          'user_id': 'old-user',
          'email': 'a@b.c',
          'name': 'N',
          'telegram_linked': true,
        });
      }
      return jsonBody(_error(ApiErrorCodes.userNotFound), status: 404);
    });
    await tokens.save(
      const AuthTokens(
        accessToken: 'a',
        refreshToken: 'r',
        userId: 'old-user',
        expiresAt: null,
      ),
    );

    await session.start();

    expect(session.state, isA<SessionUnauthenticated>());
    expect(await tokens.readRefreshToken(), isNull);
    expect(adapter.requestsTo(ApiEndpoints.clientTrainers), hasLength(1));
    // Порядок из контракта: сначала /auth/me, затем /client/trainers.
    final paths = adapter.requests.map((r) => r.path).toList();
    expect(
      paths.indexOf(ApiEndpoints.authMe),
      lessThan(paths.indexOf(ApiEndpoints.clientTrainers)),
    );
  });

  group('404 на других эндпоинтах сессию не завершает', () {
    test('telegram/link: учётной записи больше нет, токены целы', () async {
      await setUpStack(
        (options) async =>
            jsonBody(_error(ApiErrorCodes.userNotFound), status: 404),
      );

      await expectLater(
        repository.linkTelegram('ABCD1234'),
        throwsA(isA<AccountNotFoundFailure>()),
      );

      expect(await tokens.readRefreshToken(), 'old-refresh');
      expect(sessionExpiredEvents, 0);
    });

    test('invites/accept: приглашение не найдено, токены целы', () async {
      await setUpStack(
        (options) async =>
            jsonBody(_error(ApiErrorCodes.inviteNotFound), status: 404),
      );

      await expectLater(
        repository.acceptInvite('inv_abc'),
        throwsA(isA<InviteNotFoundFailure>()),
      );

      expect(await tokens.readRefreshToken(), 'old-refresh');
      expect(sessionExpiredEvents, 0);
    });
  });
}
