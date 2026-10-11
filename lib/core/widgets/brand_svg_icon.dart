import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mentorix_app/core/theme/app_theme_extension.dart';

/// Брендовая иконка из `assets/icons/*.svg` для кнопок.
///
/// Цветной логотип (Google) показывается как есть: по правилам бренда его
/// нельзя перекрашивать. Одноцветный (Apple) задаётся с [tinted] и берёт цвет
/// текста кнопки из `IconTheme`: в самом файле он белый и на светлой кнопке
/// был бы невидим.
class BrandSvgIcon extends StatelessWidget {
  const BrandSvgIcon({
    super.key,
    required this.asset,
    this.size = 20,
    this.tinted = false,
  });

  final String asset;
  final double size;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ?? context.themeExt.foreground;

    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: tinted ? ColorFilter.mode(color, BlendMode.srcIn) : null,
    );
  }
}
