import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mentorix_app/app.dart';
import 'package:mentorix_app/core/di/service_locator.dart';
import 'package:mentorix_app/features/theme/presentation/cubit/theme_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<ThemeCubit>(create: (_) => GetIt.I<ThemeCubit>()),
      ],
      child: MentorixApp(router: GetIt.I<GoRouter>()),
    ),
  );
}
