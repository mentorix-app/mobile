import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mentorix_app/core/network/dio_factory.dart';
import 'package:mentorix_app/core/network/session_expired_notifier.dart';
import 'package:mentorix_app/core/platform/external_link_launcher.dart';
import 'package:mentorix_app/core/router/app_router.dart';
import 'package:mentorix_app/core/router/onboarding_flow.dart';
import 'package:mentorix_app/core/storage/token_storage.dart';
import 'package:mentorix_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:mentorix_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mentorix_app/features/auth/data/social/apple_auth_provider.dart';
import 'package:mentorix_app/features/auth/data/social/google_auth_provider.dart';
import 'package:mentorix_app/features/auth/data/storage/pending_apple_name_storage.dart';
import 'package:mentorix_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/account_deletion_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/invite_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/login_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/telegram_link_cubit.dart';
import 'package:mentorix_app/features/theme/data/repositories/theme_repository_impl.dart';
import 'package:mentorix_app/features/theme/domain/repositories/theme_repository.dart';
import 'package:mentorix_app/features/theme/presentation/cubit/theme_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Имена экземпляров `Dio` в `get_it`.
abstract final class DioNames {
  /// Без перехватчиков: только refresh и повтор запросов внутри `AuthInterceptor`.
  static const plain = 'plain';

  /// С `AuthInterceptor`: все запросы приложения; публичные помечены `skipAuth`.
  static const api = 'api';
}

/// Регистрирует зависимости приложения. Вызывается один раз из `main()`.
///
/// Репозитории и клиенты — `registerLazySingleton`, кубиты — `registerFactory`.
/// Исключение — [SessionCubit]: сессия одна на всё приложение, на неё смотрят
/// и роутер, и экраны.
Future<void> configureDependencies() async {
  final getIt = GetIt.I;

  // --- хранилища -------------------------------------------------------------
  getIt.registerSingleton<SharedPreferences>(
    await SharedPreferences.getInstance(),
  );
  getIt.registerSingleton<FlutterSecureStorage>(
    TokenStorage.secureStorageOptions,
  );
  getIt.registerLazySingleton<TokenStorage>(
    () => TokenStorage(
      getIt<FlutterSecureStorage>(),
      getIt<SharedPreferences>(),
    ),
  );

  // --- сеть ------------------------------------------------------------------
  getIt.registerLazySingleton<SessionExpiredNotifier>(SessionExpiredNotifier.new);
  getIt.registerLazySingleton<Dio>(createPlainDio, instanceName: DioNames.plain);
  getIt.registerLazySingleton<Dio>(
    () => createApiDio(
      plainDio: getIt<Dio>(instanceName: DioNames.plain),
      tokens: getIt<TokenStorage>(),
      sessionExpired: getIt<SessionExpiredNotifier>(),
    ),
    instanceName: DioNames.api,
  );

  // --- авторизация -----------------------------------------------------------
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remote: AuthRemoteDataSource(
        apiDio: getIt<Dio>(instanceName: DioNames.api),
      ),
      tokens: getIt<TokenStorage>(),
      sessionExpired: getIt<SessionExpiredNotifier>(),
      pendingAppleName: PendingAppleNameStorage(getIt<FlutterSecureStorage>()),
      google: GoogleAuthProvider(),
      apple: AppleAuthProvider(),
    ),
  );
  getIt.registerLazySingleton<OnboardingFlow>(
    () => OnboardingFlow(getIt<SharedPreferences>()),
  );
  getIt.registerLazySingleton<SessionCubit>(
    () => SessionCubit(
      getIt<AuthRepository>(),
      getIt<SessionExpiredNotifier>(),
    ),
  );
  getIt.registerFactory<LoginCubit>(
    () => LoginCubit(getIt<AuthRepository>(), getIt<SessionCubit>()),
  );
  getIt.registerLazySingleton<ExternalLinkLauncher>(
    () => const UrlLauncherExternalLinkLauncher(),
  );
  getIt.registerFactory<TelegramLinkCubit>(
    () => TelegramLinkCubit(
      getIt<AuthRepository>(),
      getIt<SessionCubit>(),
      getIt<OnboardingFlow>(),
      getIt<ExternalLinkLauncher>(),
    ),
  );
  getIt.registerFactory<AccountDeletionCubit>(
    () => AccountDeletionCubit(
      getIt<AuthRepository>(),
      getIt<SessionCubit>(),
      getIt<OnboardingFlow>(),
    ),
  );
  getIt.registerFactory<InviteCubit>(
    () => InviteCubit(
      getIt<AuthRepository>(),
      getIt<SessionCubit>(),
      getIt<OnboardingFlow>(),
    ),
  );

  // --- тема ------------------------------------------------------------------
  getIt.registerLazySingleton<ThemeRepository>(
    () => ThemeRepositoryImpl(getIt<SharedPreferences>()),
  );
  getIt.registerFactory<ThemeCubit>(() => ThemeCubit(getIt<ThemeRepository>()));

  // --- роутер ----------------------------------------------------------------
  getIt.registerLazySingleton<GoRouter>(
    () => createAppRouter(
      session: getIt<SessionCubit>(),
      flow: getIt<OnboardingFlow>(),
    ),
  );
}
