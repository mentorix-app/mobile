import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/widgets/large_title_header_delegate.dart';

/// Шапка экрана с крупным заголовком, как large title в iOS (`CLAUDE.md`, §6.1).
///
/// * Развёрнутая: заголовок крупный и жирный (`textTheme.displaySmall`), до двух
///   строк с многоточием, прижат к низу шапки и стоит слева на линии контента
///   (`AppSpacing.lg`). Высота шапки равна тулбару плюс высота самого заголовка —
///   пустоты между кнопкой «назад» и заголовком нет.
/// * При прокрутке плавно сворачивается: крупный уходит под тулбар и гаснет,
///   маленький проявляется по центру тулбара (одна строка, многоточие).
///
/// Вместо `SliverAppBar.large`: тот держит жёсткую высоту, заголовок остаётся мелким
/// с большими пустыми полями. Ставится в `headerSlivers` у
/// `AdaptiveRefreshScrollView`; [collapsedExtent] — высота свёрнутой шапки для
/// `edgeOffset` индикатора Android.
class LargeTitleSliverAppBar extends StatelessWidget {
  const LargeTitleSliverAppBar({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
  });

  final String title;

  /// Обычно `AppBackButton`.
  final Widget? leading;

  /// Действие справа (значок). Должен помещаться в тулбар высотой 56.
  final Widget? trailing;

  /// Высота свёрнутой шапки вместе со строкой состояния.
  static double collapsedExtent(BuildContext context) =>
      MediaQuery.paddingOf(context).top + kToolbarHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final largeStyle = theme.textTheme.displaySmall!;
    final textScaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final topInset = MediaQuery.paddingOf(context).top;

    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: title, style: largeStyle),
          maxLines: 2,
          ellipsis: '…',
          textDirection: direction,
          textScaler: textScaler,
        )..layout(maxWidth: constraints.crossAxisExtent - 2 * AppSpacing.lg);
        final titleHeight = painter.height;
        painter.dispose();

        return SliverPersistentHeader(
          pinned: true,
          delegate: LargeTitleHeaderDelegate(
            title: title,
            largeStyle: largeStyle,
            collapsedStyle:
                theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge,
            titleHeight: titleHeight,
            topInset: topInset,
            toolbarHeight: kToolbarHeight,
            leading: leading,
            trailing: trailing,
          ),
        );
      },
    );
  }
}
