import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mentorix_app/app.dart';
import 'package:mentorix_app/core/di/service_locator.dart';
import 'package:mentorix_app/core/startup/precache_splash_logos.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_cubit.dart';
import 'package:mentorix_app/features/theme/presentation/cubit/theme_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  // Логотип сплеша должен быть в кэше к первому кадру, иначе он «мигает».
  await precacheSplashLogos();

  final session = GetIt.I<SessionCubit>();
  // Не ждём: приложение сразу показывает заставку, роутер сам уведёт дальше.
  unawaited(session.start());

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<ThemeCubit>(create: (_) => GetIt.I<ThemeCubit>()),
        BlocProvider<SessionCubit>.value(value: session),
      ],
      child: MentorixApp(router: GetIt.I<GoRouter>()),
    ),
  );
}
