import 'package:flutter/material.dart';
import 'package:mentorix_app/core/theme/app_radii.dart';
import 'package:mentorix_app/core/theme/app_theme_extension.dart';

/// Единственный способ показать уведомление: `ScaffoldMessenger` напрямую
/// в остальном коде не используется.
abstract final class AppSnackBar {
  static void showError(BuildContext context, String message) =>
      _show(context, message, context.themeExt.destructive);

  static void showSuccess(BuildContext context, String message) =>
      _show(context, message, context.themeExt.primary);

  static void showInfo(BuildContext context, String message) =>
      _show(context, message, context.themeExt.mutedForeground);

  static void showWarning(BuildContext context, String message) =>
      _show(context, message, context.themeExt.ring);

  static void _show(BuildContext context, String message, Color accent) {
    final tokens = context.themeExt;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(color: tokens.cardForeground),
          ),
          backgroundColor: tokens.card,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            side: BorderSide(color: accent),
          ),
        ),
      );
  }
}
