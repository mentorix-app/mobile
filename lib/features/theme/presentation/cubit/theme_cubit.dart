import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mentorix_app/features/theme/domain/repositories/theme_repository.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit(this._repository) : super(_repository.load());

  final ThemeRepository _repository;

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == state) return;
    emit(mode);
    await _repository.save(mode);
  }
}
