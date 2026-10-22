import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/theme/app_theme_extension.dart';

/// Делегат закреплённой шапки с крупным заголовком в духе iOS: [LargeTitleSliverAppBar]
/// собирает его и считает высоту заголовка.
///
/// Свёрнутая шапка — строка состояния и тулбар ([collapsedExtent]): кнопка «назад»
/// и маленький заголовок по центру. Развёрнутая — выше на высоту крупного
/// заголовка: он прижат к низу шапки, слева на линии контента. При прокрутке
/// крупный заголовок уходит под тулбар и гаснет, маленький проявляется, снизу
/// появляется тонкая линия.
class LargeTitleHeaderDelegate extends SliverPersistentHeaderDelegate {
  const LargeTitleHeaderDelegate({
    required this.title,
    required this.largeStyle,
    required this.collapsedStyle,
    required this.titleHeight,
    required this.topInset,
    required this.toolbarHeight,
    this.leading,
  });

  final String title;

  /// Стиль развёрнутого заголовка (`textTheme.displaySmall`).
  final TextStyle largeStyle;

  /// Стиль свёрнутого заголовка (заголовок `AppBar`).
  final TextStyle? collapsedStyle;

  /// Высота развёрнутого заголовка: одна или две строки.
  final double titleHeight;

  /// Высота строки состояния.
  final double topInset;
  final double toolbarHeight;
  final Widget? leading;

  /// Отступ под развёрнутым заголовком.
  static const double bottomGap = AppSpacing.xs;

  double get collapsedExtent => topInset + toolbarHeight;

  @override
  double get minExtent => collapsedExtent;

  @override
  double get maxExtent => collapsedExtent + titleHeight + bottomGap;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final tokens = context.themeExt;
    final range = maxExtent - minExtent;
    final progress = range <= 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0);

    // Крупный гаснет за первую половину сворачивания, маленький проявляется за
    // вторую: в середине пути заголовка нет, а не два сразу.
    final largeOpacity = (1 - progress * 2).clamp(0.0, 1.0);
    final smallOpacity = ((progress - 0.5) * 2).clamp(0.0, 1.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.background,
          border: Border(
            bottom: BorderSide(
              color: tokens.border.withValues(alpha: tokens.border.a * progress),
            ),
          ),
        ),
        child: Stack(
          children: [
            // Крупный заголовок: область под тулбаром сжимается вместе с шапкой,
            // заголовок прижат к её низу и обрезается сверху, как при прокрутке.
            Positioned(
              left: 0,
              right: 0,
              top: collapsedExtent,
              bottom: 0,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.bottomLeft,
                  minHeight: titleHeight + bottomGap,
                  maxHeight: titleHeight + bottomGap,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      bottomGap,
                    ),
                    child: Opacity(
                      opacity: largeOpacity,
                      child: Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: largeStyle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: topInset,
              height: toolbarHeight,
              child: NavigationToolbar(
                leading: leading,
                centerMiddle: true,
                middleSpacing: AppSpacing.sm,
                // Заголовок для экранных читалок уже есть в развёрнутой строке.
                middle: ExcludeSemantics(
                  child: Opacity(
                    opacity: smallOpacity,
                    child: Text(
                      title,
                      style: collapsedStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(LargeTitleHeaderDelegate old) =>
      title != old.title ||
      largeStyle != old.largeStyle ||
      collapsedStyle != old.collapsedStyle ||
      titleHeight != old.titleHeight ||
      topInset != old.topInset ||
      toolbarHeight != old.toolbarHeight ||
      leading != old.leading;
}
