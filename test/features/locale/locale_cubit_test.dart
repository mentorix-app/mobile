import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/storage/storage_keys.dart';
import 'package:mentorix_app/features/locale/data/repositories/locale_repository_impl.dart';
import 'package:mentorix_app/features/locale/presentation/cubit/locale_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<(LocaleCubit, SharedPreferences)> createCubit([
    Map<String, Object> stored = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(stored);
    final prefs = await SharedPreferences.getInstance();
    return (LocaleCubit(LocaleRepositoryImpl(prefs)), prefs);
  }

  test('без сохранённого значения — «Системный» (null)', () async {
    final (cubit, _) = await createCubit();

    expect(cubit.state, isNull);
    await cubit.close();
  });

  test('читает сохранённый язык синхронно, до первого кадра', () async {
    final (ru, _) = await createCubit({StorageKeys.localeMode: 'ru'});
    expect(ru.state, const Locale('ru'));
    await ru.close();

    final (en, _) = await createCubit({StorageKeys.localeMode: 'en'});
    expect(en.state, const Locale('en'));
    await en.close();
  });

  test('значение «system» и неизвестное значение — «Системный»', () async {
    for (final value in ['system', 'de', '', 'RU']) {
      final (cubit, _) = await createCubit({StorageKeys.localeMode: value});

      expect(cubit.state, isNull, reason: value);
      await cubit.close();
    }
  });

  test('select меняет состояние и сохраняет выбор', () async {
    final (cubit, prefs) = await createCubit();

    await cubit.select(const Locale('ru'));
    expect(cubit.state, const Locale('ru'));
    expect(prefs.getString(StorageKeys.localeMode), 'ru');

    await cubit.select(const Locale('en'));
    expect(prefs.getString(StorageKeys.localeMode), 'en');
    await cubit.close();
  });

  test('возврат к «Системный» сохраняет system', () async {
    final (cubit, prefs) = await createCubit({StorageKeys.localeMode: 'ru'});

    await cubit.select(null);

    expect(cubit.state, isNull);
    expect(prefs.getString(StorageKeys.localeMode), 'system');
    await cubit.close();
  });

  test('повторный выбор того же языка ничего не эмитит и не пишет', () async {
    final (cubit, prefs) = await createCubit({StorageKeys.localeMode: 'ru'});
    final emitted = <Locale?>[];
    final sub = cubit.stream.listen(emitted.add);

    await cubit.select(const Locale('ru'));
    await pumpEventQueue();

    expect(emitted, isEmpty);
    expect(prefs.getString(StorageKeys.localeMode), 'ru');
    await sub.cancel();
    await cubit.close();
  });
}
