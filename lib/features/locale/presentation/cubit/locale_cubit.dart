import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mentorix_app/features/locale/domain/repositories/locale_repository.dart';

/// Язык приложения: `null` — «Системный» (язык берётся с телефона). Сохранённое
/// читается синхронно, чтобы первый кадр сразу был на нужном языке.
class LocaleCubit extends Cubit<Locale?> {
  LocaleCubit(this._repository) : super(_repository.load());

  final LocaleRepository _repository;

  Future<void> select(Locale? locale) async {
    if (locale == state) return;
    emit(locale);
    await _repository.save(locale);
  }
}
