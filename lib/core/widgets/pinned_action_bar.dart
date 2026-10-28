import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/theme/app_theme_extension.dart';

/// Панель с главным действием экрана, закреплённая внизу: фон экрана, тонкая линия
/// сверху, отступы по сетке и отступ под индикатор «домой».
///
/// Передаётся в `Scaffold.bottomNavigationBar`, а не кладётся в тело:
/// * тело заканчивается над панелью, контент под неё не уходит;
/// * плавающие уведомления (`AppSnackBar`) встают **над** панелью и не
///   перекрывают кнопку;
/// * `Scaffold` по умолчанию прячет такую панель за клавиатурой, поэтому панель
///   сама поднимается на высоту клавиатуры.
class PinnedActionBar extends StatelessWidget {
  const PinnedActionBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeExt;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.background,
          border: Border(top: BorderSide(color: tokens.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: child,
          ),
        ),
      ),
    );
  }
}
