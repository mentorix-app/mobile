import 'package:flutter/material.dart';
import 'package:mentorix_app/core/widgets/app_back_button.dart';

/// Шапка экрана программы: название программы крупно, при прокрутке сворачивается
/// в обычную строку. Название — на языке приложения, до двух строк. Кнопка
/// «назад» своя: это первая страница `ShellRoute`, `AppBar` её не рисует.
class ProgramAppBar extends StatelessWidget {
  const ProgramAppBar({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar.large(
      leading: const AppBackButton(),
      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }
}
