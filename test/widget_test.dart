import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/app.dart';
import 'package:mentorix_app/core/router/app_router.dart';
import 'package:mentorix_app/features/home/presentation/screens/home_screen.dart';
import 'package:mentorix_app/features/theme/data/repositories/theme_repository_impl.dart';
import 'package:mentorix_app/features/theme/presentation/cubit/theme_cubit.dart';
import 'package:mentorix_app/features/theme/presentation/widgets/theme_mode_button.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.clearAllTestValues();
  });

  Future<({BuildContext context, SharedPreferences prefs})> pumpApp(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    Locale locale = const Locale('en'),
    Map<String, Object> stored = const {},
  }) async {
    SharedPreferences.setMockInitialValues(stored);
    final prefs = await SharedPreferences.getInstance();

    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    tester.platformDispatcher.localesTestValue = [locale];

    await tester.pumpWidget(
      BlocProvider(
        create: (_) => ThemeCubit(ThemeRepositoryImpl(prefs)),
        child: MentorixApp(router: createAppRouter()),
      ),
    );
    await tester.pumpAndSettle();

    return (context: tester.element(find.byType(HomeScreen)), prefs: prefs);
  }

  Brightness currentBrightness(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(HomeScreen))).brightness;

  for (final brightness in Brightness.values) {
    for (final locale in const [Locale('ru'), Locale('en')]) {
      testWidgets(
        'стартовый экран собирается: ${brightness.name}, ${locale.languageCode}',
        (tester) async {
          final app = await pumpApp(
            tester,
            brightness: brightness,
            locale: locale,
          );

          expect(Theme.of(app.context).brightness, brightness);
          expect(
            AppLocalizations.of(app.context).localeName,
            locale.languageCode,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('по умолчанию тема следует за системной', (tester) async {
    await pumpApp(tester, brightness: Brightness.dark);

    expect(currentBrightness(tester), Brightness.dark);
  });

  testWidgets('сохранённый выбор темы применяется с первого кадра', (
    tester,
  ) async {
    await pumpApp(
      tester,
      brightness: Brightness.light,
      stored: {ThemeRepositoryImpl.storageKey: 'dark'},
    );

    expect(currentBrightness(tester), Brightness.dark);
  });

  testWidgets('кнопка проходит систему → светлую → тёмную → систему', (
    tester,
  ) async {
    // Системная тема — тёмная, чтобы шаги «система» и «светлая» различались.
    final app = await pumpApp(tester, brightness: Brightness.dark);
    final l10n = AppLocalizations.of(app.context);

    Future<void> tapButton() async {
      await tester.tap(find.byType(ThemeModeButton));
      await tester.pumpAndSettle();
    }

    expect(find.byTooltip(l10n.themeModeSystem), findsOneWidget);

    await tapButton();
    expect(find.byTooltip(l10n.themeModeLight), findsOneWidget);
    expect(currentBrightness(tester), Brightness.light);
    expect(app.prefs.getString(ThemeRepositoryImpl.storageKey), 'light');

    await tapButton();
    expect(find.byTooltip(l10n.themeModeDark), findsOneWidget);
    expect(currentBrightness(tester), Brightness.dark);
    expect(app.prefs.getString(ThemeRepositoryImpl.storageKey), 'dark');

    await tapButton();
    expect(find.byTooltip(l10n.themeModeSystem), findsOneWidget);
    expect(app.prefs.getString(ThemeRepositoryImpl.storageKey), 'system');
  });
}
