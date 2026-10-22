import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Длинный текст (инструкция тренера до 5000 символов): первые [maxLines] строк и
/// «Показать полностью». Если текст помещается, кнопки нет. Раскрытие хранится
/// здесь и сбрасывается вместе с виджетом.
class ExpandableText extends StatefulWidget {
  const ExpandableText({
    super.key,
    required this.text,
    this.style,
    this.maxLines = 6,
  });

  final String text;
  final TextStyle? style;
  final int maxLines;

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  final _expanded = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _expanded.dispose();
    super.dispose();
  }

  /// Не помещается ли текст в [ExpandableText.maxLines] строк при этой ширине и
  /// масштабе шрифта.
  bool _exceeds(BuildContext context, TextStyle style, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: style),
      maxLines: widget.maxLines,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth);
    final exceeds = painter.didExceedMaxLines;
    painter.dispose();
    return exceeds;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = DefaultTextStyle.of(context).style.merge(
      widget.style ?? Theme.of(context).textTheme.bodyMedium,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final exceeds = _exceeds(context, style, constraints.maxWidth);

        return ValueListenableBuilder<bool>(
          valueListenable: _expanded,
          builder: (context, expanded, _) {
            final collapsed = exceeds && !expanded;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.text,
                  style: style,
                  maxLines: collapsed ? widget.maxLines : null,
                  overflow: collapsed ? TextOverflow.ellipsis : TextOverflow.clip,
                ),
                if (exceeds) ...[
                  const SizedBox(height: AppSpacing.xs),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 48),
                      alignment: Alignment.centerLeft,
                    ),
                    onPressed: () => _expanded.value = !expanded,
                    child: Text(
                      expanded ? l10n.showLessAction : l10n.showMoreAction,
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}
