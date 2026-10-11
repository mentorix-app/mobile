import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mentorix_app/features/theme/presentation/widgets/theme_mode_button.dart';
import 'package:mentorix_app/generated/assets.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Заглушка стартового экрана каркаса: логотип на фоне темы.
/// Заменяется настоящим экраном в следующих этапах.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(actions: const [ThemeModeButton()]),
      body: Center(
        child: SvgPicture.asset(
          isDark ? Assets.iconsFullLogoDark : Assets.iconsFullLogo,
          width: 240,
          semanticsLabel: AppLocalizations.of(context).appTitle,
        ),
      ),
    );
  }
}
