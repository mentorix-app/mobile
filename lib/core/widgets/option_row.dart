import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';

/// Одна строка выбора из нескольких вариантов (язык, тема): название и галочка у
/// выбранного. Строки одной группы помечены для доступности как взаимоисключающие.
class OptionRow extends StatelessWidget {
  const OptionRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: label,
      button: true,
      onTap: onTap,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Text(label, style: textTheme.bodyLarge),
                  ),
                ),
                if (selected) const Icon(Icons.check),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
