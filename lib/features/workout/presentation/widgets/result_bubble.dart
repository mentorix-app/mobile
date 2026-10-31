import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_radii.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/theme/app_theme_extension.dart';

/// Результат клиента: серый пузырь справа, как свой ответ в чате. Не шире 85%,
/// переносы строк сохраняются.
class ResultBubble extends StatelessWidget {
  const ResultBubble({super.key, required this.text});

  final String text;

  /// Доля ширины, которую пузырь не превышает.
  static const maxWidthFactor = 0.85;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeExt;

    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: AlignmentDirectional.centerEnd,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * maxWidthFactor),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.secondary,
              borderRadius: BorderRadius.circular(AppRadii.xl),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: tokens.secondaryForeground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
