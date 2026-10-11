import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/features/theme/data/repositories/theme_repository_impl.dart';
import 'package:mentorix_app/features/theme/presentation/cubit/theme_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<(ThemeCubit, SharedPreferences)> createCubit([
    Map<String, Object> stored = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(stored);
    final prefs = await SharedPreferences.getInstance();
    return (ThemeCubit(ThemeRepositoryImpl(prefs)), prefs);
  }

  test('без сохранённого значения — системная тема', () async {
    final (cubit, _) = await createCubit();

    expect(cubit.state, ThemeMode.system);
    await cubit.close();
  });

  test('читает сохранённое значение', () async {
    final (cubit, _) = await createCubit({'theme_mode': 'dark'});

    expect(cubit.state, ThemeMode.dark);
    await cubit.close();
  });

  test('неизвестное сохранённое значение — системная тема', () async {
    final (cubit, _) = await createCubit({'theme_mode': 'sepia'});

    expect(cubit.state, ThemeMode.system);
    await cubit.close();
  });

  test('setThemeMode меняет состояние и сохраняет выбор', () async {
    final (cubit, prefs) = await createCubit();

    await cubit.setThemeMode(ThemeMode.light);

    expect(cubit.state, ThemeMode.light);
    expect(prefs.getString('theme_mode'), 'light');
    await cubit.close();
  });

  test('повторный выбор той же темы ничего не эмитит', () async {
    final (cubit, _) = await createCubit({'theme_mode': 'light'});
    final emitted = <ThemeMode>[];
    final subscription = cubit.stream.listen(emitted.add);

    await cubit.setThemeMode(ThemeMode.light);
    await Future<void>.delayed(Duration.zero);

    expect(emitted, isEmpty);
    await subscription.cancel();
    await cubit.close();
  });
}
