import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mentorix_app/core/router/onboarding_flow.dart';
import 'package:mentorix_app/core/router/route_names.dart';
import 'package:mentorix_app/features/auth/domain/entities/user_profile.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/invite_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/login_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_state.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/telegram_link_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/screens/invite_screen.dart';
import 'package:mentorix_app/features/auth/presentation/screens/login_screen.dart';
import 'package:mentorix_app/features/auth/presentation/screens/splash_screen.dart';
import 'package:mentorix_app/features/auth/presentation/screens/telegram_code_screen.dart';
import 'package:mentorix_app/features/auth/presentation/screens/telegram_offer_screen.dart';
import 'package:mentorix_app/features/auth/presentation/session_refresh_listenable.dart';
import 'package:mentorix_app/features/home/presentation/screens/home_screen.dart';

/// Роутер зависит от сессии: куда можно попасть, решает [SessionCubit],
/// а порядок экранов после входа — [OnboardingFlow].
GoRouter createAppRouter({
  required SessionCubit session,
  required OnboardingFlow flow,
}) {
  String? redirect(BuildContext context, GoRouterState state) {
    final location = state.matchedLocation;

    return switch (session.state) {
      SessionUnknown() =>
        location == RouteNames.splash ? null : RouteNames.splash,
      SessionUnauthenticated() =>
        location == RouteNames.login ? null : RouteNames.login,
      SessionAuthenticated(:final profile) => _authenticatedRedirect(
        location,
        profile,
        flow,
      ),
    };
  }

  return GoRouter(
    initialLocation: RouteNames.home,
    refreshListenable: SessionRefreshListenable(session),
    redirect: redirect,
    routes: [
      GoRoute(
        path: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) => BlocProvider(
          create: (_) => GetIt.I<LoginCubit>(),
          child: const LoginScreen(),
        ),
      ),
      // Один TelegramLinkCubit на предложение и ввод кода.
      ShellRoute(
        builder: (context, state, child) => BlocProvider(
          create: (_) => GetIt.I<TelegramLinkCubit>(),
          child: child,
        ),
        routes: [
          GoRoute(
            path: RouteNames.telegramOffer,
            builder: (context, state) => const TelegramOfferScreen(),
          ),
          GoRoute(
            path: RouteNames.telegramCode,
            builder: (context, state) => const TelegramCodeScreen(),
          ),
        ],
      ),
      GoRoute(
        path: RouteNames.invite,
        builder: (context, state) => BlocProvider(
          create: (_) => GetIt.I<InviteCubit>(),
          child: const InviteScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.home,
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
}

String? _authenticatedRedirect(
  String location,
  UserProfile profile,
  OnboardingFlow flow,
) {
  final next = flow.nextRoute(profile);

  // Вход и заставка: сразу на следующий шаг.
  if (location == RouteNames.splash || location == RouteNames.login) {
    return next;
  }
  // Главный экран недоступен, пока не пройден порядок «Telegram → приглашение».
  if (location == RouteNames.home && next != RouteNames.home) {
    return next;
  }
  return null;
}
