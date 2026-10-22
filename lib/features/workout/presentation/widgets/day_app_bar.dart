import 'package:flutter/material.dart';
import 'package:mentorix_app/core/router/route_names.dart';
import 'package:mentorix_app/core/widgets/app_back_button.dart';
import 'package:mentorix_app/core/widgets/large_title_sliver_app_bar.dart';

/// Шапка экрана дня — та же крупная, что у программы: «Неделя N, день M». Кнопка
/// «назад» ведёт к программе этого тренера, даже если день открыт по ссылке.
class DayAppBar extends StatelessWidget {
  const DayAppBar({super.key, required this.title, required this.trainerId});

  final String title;
  final String trainerId;

  @override
  Widget build(BuildContext context) {
    return LargeTitleSliverAppBar(
      title: title,
      leading: AppBackButton(
        fallbackLocation: RouteNames.trainerProgramPath(trainerId),
      ),
    );
  }
}
