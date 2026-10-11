import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/network/session_expired_notifier.dart';
import 'package:mentorix_app/core/theme/app_theme.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/screens/splash_screen.dart';
import 'package:mentorix_app/generated/assets.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

import '../../helpers/auth_fakes.dart';

/// Flutter-сплеш должен совпадать с нативным экраном запуска: тот же логотип,
/// тот же размер и центр всего экрана, а не безопасной области.
void main() {
  // iPhone с Dynamic Island: сверху вырез заметно больше, чем снизу.
  const screen = Size(402, 874);
  const padding = EdgeInsets.only(top: 62, bottom: 34);

  Future<void> pumpSplash(
    WidgetTester tester, {
    required Brightness brightness,
  }) async {
    final cubit = SessionCubit(FakeAuthRepository(), SessionExpiredNotifier());
    addTearDown(cubit.close);

    tester.view
      ..physicalSize = screen
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: screen, padding: padding),
        child: BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SplashScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder logo() => find.byType(Image);

  testWidgets('логотип по центру всего экрана, а не безопасной области', (
    tester,
  ) async {
    await pumpSplash(tester, brightness: Brightness.light);

    final center = tester.getCenter(logo());
    expect(center.dx, closeTo(screen.width / 2, 0.5));
    expect(
      center.dy,
      closeTo(screen.height / 2, 0.5),
      reason: 'с SafeArea центр уехал бы вниз на (62 − 34) / 2 = 14 dp',
    );
  });

  testWidgets('ширина логотипа — 240 dp, как у нативного сплеша', (
    tester,
  ) async {
    await pumpSplash(tester, brightness: Brightness.light);

    expect(tester.getSize(logo()).width, SplashScreen.logoWidth);
    expect(SplashScreen.logoWidth, 240);
  });

  testWidgets('светлая тема — светлый PNG, тёмная — тёмный', (tester) async {
    await pumpSplash(tester, brightness: Brightness.light);
    var image = tester.widget<Image>(logo());
    expect((image.image as AssetImage).assetName, Assets.splashFullLogo);

    await pumpSplash(tester, brightness: Brightness.dark);
    await tester.pumpAndSettle();
    image = tester.widget<Image>(logo());
    expect((image.image as AssetImage).assetName, Assets.splashFullLogoDark);
  });

  testWidgets('фон — токен background темы, как у нативного экрана', (
    tester,
  ) async {
    await pumpSplash(tester, brightness: Brightness.dark);
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor ?? AppTheme.dark.scaffoldBackgroundColor,
        const Color(0xFF0A0A0A));
  });
}
