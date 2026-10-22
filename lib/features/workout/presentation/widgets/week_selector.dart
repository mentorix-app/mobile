import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Выбор недели: чипы «Неделя N» в горизонтальной прокрутке. Выбранный залит
/// `primary` (тема чипов). Для программы из одной недели не показывается.
class WeekSelector extends StatelessWidget {
  const WeekSelector({
    super.key,
    required this.weekNumbers,
    required this.selected,
    required this.onSelected,
  });

  final List<int> weekNumbers;
  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          for (final number in weekNumbers) ...[
            ChoiceChip(
              key: ValueKey(number),
              label: Text(l10n.weekLabel(number)),
              selected: number == selected,
              onSelected: (_) => onSelected(number),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}
