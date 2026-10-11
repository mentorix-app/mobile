import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mentorix_app/app.dart';
import 'package:mentorix_app/core/config/api_endpoints.dart';
import 'package:mentorix_app/core/network/auth_interceptor.dart';
import 'package:mentorix_app/core/network/auth_tokens.dart';
import 'package:mentorix_app/core/network/session_expired_notifier.dart';
import 'package:mentorix_app/core/router/app_router.dart';
import 'package:mentorix_app/core/router/onboarding_flow.dart';
import 'package:mentorix_app/core/storage/token_storage.dart';
import 'package:mentorix_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:mentorix_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mentorix_app/features/auth/data/storage/pending_apple_name_storage.dart';
import 'package:mentorix_app/features/auth/domain/entities/social_credential.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';
import 'package:mentorix_app/features/auth/domain/providers/social_auth_provider.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/login_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_cubit.dart';
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
}

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
      TokenStorage.installFlagKey: true,
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
    'старые токены после переноса учётной записи: /auth/me 404 → '
    'экран входа, а не заставка',
    (tester) async {
      await setUpStack((options) async {
        if (options.path == ApiEndpoints.authMe) {
          return jsonBody({'message': 'user not found'}, status: 404);
        }
        return jsonBody({'message': 'unauthorized'}, status: 401);
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

  group('404 на других эндпоинтах сессию не завершает', () {
    test('telegram/link: учётной записи больше нет, токены целы', () async {
      await setUpStack(
        (options) async => jsonBody({'message': 'not found'}, status: 404),
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
        (options) async => jsonBody({'message': 'not found'}, status: 404),
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
