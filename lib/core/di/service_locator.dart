import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mentorix_app/core/router/app_router.dart';
import 'package:mentorix_app/features/theme/data/repositories/theme_repository_impl.dart';
import 'package:mentorix_app/features/theme/domain/repositories/theme_repository.dart';
import 'package:mentorix_app/features/theme/presentation/cubit/theme_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Регистрирует зависимости приложения. Вызывается один раз из `main()`.
///
/// Репозитории и клиенты — `registerLazySingleton`, кубиты — `registerFactory`.
Future<void> configureDependencies() async {
  final getIt = GetIt.I;

  getIt.registerSingleton<SharedPreferences>(
    await SharedPreferences.getInstance(),
  );

  getIt.registerLazySingleton<ThemeRepository>(
    () => ThemeRepositoryImpl(getIt<SharedPreferences>()),
  );
  getIt.registerFactory<ThemeCubit>(() => ThemeCubit(getIt<ThemeRepository>()));

  getIt.registerLazySingleton<GoRouter>(createAppRouter);
}
