import 'package:flutter/material.dart';

abstract class ThemeRepository {
  ThemeMode load();

  Future<void> save(ThemeMode mode);
}
