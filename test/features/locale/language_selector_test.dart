import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mentorix_app/app.dart';
import 'package:mentorix_app/core/storage/storage_keys.dart';
import 'package:mentorix_app/features/locale/data/repositories/locale_repository_impl.dart';
import 'package:mentorix_app/features/locale/presentation/cubit/locale_cubit.dart';
import 'package:mentorix_app/features/locale/presentation/widgets/language_selector.dart';
import 'package:mentorix_app/features/theme/data/repositories/theme_repository_impl.dart';
import 'package:mentorix_app/features/theme/presentation/cubit/theme_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  /// Приложение целиком с одним экраном выбора языка. [system] — язык телефона.
  Future<void> pumpSelector(
    WidgetTester tester, {
    Map<String, Object> stored = const {},
    Locale system = const Locale('en'),
    Size size = const Size(402, 874),
    double textScale = 1,
  }) async {
    SharedPreferences.setMockInitialValues(stored);
    prefs = await SharedPreferences.getInstance();
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localesTestValue = [system];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<ThemeCubit>(create: (_) => ThemeCubit(ThemeRepositoryImpl(prefs))),
          BlocProvider<LocaleCubit>(create: (_) => LocaleCubit(LocaleRepositoryImpl(prefs))),
        ],
        child: MentorixApp(
          router: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const Scaffold(
                  body: SafeArea(child: SingleChildScrollView(child: LanguageSelector())),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder optionRow(String label) => find.ancestor(
    of: find.text(label),
    matching: find.byType(InkWell),
  );

  bool isSelected(WidgetTester tester, String label) => find
      .descendant(of: optionRow(label), matching: find.byIcon(Icons.check))
      .evaluate()
      .isNotEmpty;

  testWidgets('три варианта; названия языков на своих языках', (tester) async {
    await pumpSelector(tester);

    expect(find.text('Language'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Русский'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('системный русский: «Системный», «Русский» и «English» без перевода', (tester) async {
    await pumpSelector(tester, system: const Locale('ru'));

    expect(find.text('Язык'), findsOneWidget);
    expect(find.text('Системный'), findsOneWidget);
    expect(find.text('Русский'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('по умолчанию выбран «Системный»', (tester) async {
    await pumpSelector(tester);

    expect(isSelected(tester, 'System'), isTrue);
    expect(isSelected(tester, 'Русский'), isFalse);
    expect(isSelected(tester, 'English'), isFalse);
  });

  testWidgets('«Русский»: экран сразу на русском, выбор сохранён', (tester) async {
    await pumpSelector(tester);

    await tester.tap(find.text('Русский'));
    await tester.pumpAndSettle();

    expect(find.text('Язык'), findsOneWidget);
    expect(find.text('Системный'), findsOneWidget);
    expect(isSelected(tester, 'Русский'), isTrue);
    expect(prefs.getString(StorageKeys.localeMode), 'ru');
  });

  testWidgets('«English» при русском телефоне', (tester) async {
    await pumpSelector(tester, system: const Locale('ru'));

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('Language'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(isSelected(tester, 'English'), isTrue);
    expect(prefs.getString(StorageKeys.localeMode), 'en');
  });

  testWidgets('«Системный» возвращает язык телефона', (tester) async {
    await pumpSelector(tester, system: const Locale('ru'), stored: {StorageKeys.localeMode: 'en'});
    expect(find.text('Language'), findsOneWidget);

    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();

    expect(find.text('Язык'), findsOneWidget);
    expect(prefs.getString(StorageKeys.localeMode), 'system');
  });

  testWidgets('неподдерживаемый язык телефона — английский', (tester) async {
    await pumpSelector(tester, system: const Locale('de'));

    expect(find.text('Language'), findsOneWidget);
    expect(isSelected(tester, 'System'), isTrue);
  });

  testWidgets('сохранённый язык виден с первого кадра, телефон на другом языке', (tester) async {
    await pumpSelector(tester, system: const Locale('en'), stored: {StorageKeys.localeMode: 'ru'});

    expect(find.text('Язык'), findsOneWidget);
    expect(isSelected(tester, 'Русский'), isTrue);
  });

  testWidgets('доступность: выбранный вариант помечен, касание работает как кнопка', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpSelector(tester, stored: {StorageKeys.localeMode: 'ru'});

    expect(
      tester.getSemantics(optionRow('Русский')),
      matchesSemantics(
        label: 'Русский',
        isButton: true,
        isSelected: true,
        isInMutuallyExclusiveGroup: true,
        hasSelectedState: true,
        hasTapAction: true,
        hasEnabledState: false,
      ),
    );
    expect(
      tester.getSemantics(optionRow('English')),
      matchesSemantics(
        label: 'English',
        isButton: true,
        isSelected: false,
        isInMutuallyExclusiveGroup: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );

    handle.dispose();
  });

  testWidgets('строки не ниже 48 px', (tester) async {
    await pumpSelector(tester);

    for (final label in ['System', 'Русский', 'English']) {
      expect(tester.getSize(optionRow(label)).height, greaterThanOrEqualTo(48), reason: label);
    }
  });

  for (final locale in const [Locale('ru'), Locale('en')]) {
    testWidgets('320 px, шрифт ×2, ${locale.languageCode}: без переполнения', (tester) async {
      await pumpSelector(tester, system: locale, size: const Size(320, 568), textScale: 2);

      expect(tester.takeException(), isNull);
    });
  }
}
