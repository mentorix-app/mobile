import 'package:flutter/material.dart';
import 'package:mentorix_app/core/router/route_names.dart';
import 'package:mentorix_app/core/widgets/app_back_button.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Обычная шапка с кнопкой «назад» и словом «Программа» для экрана, пока
/// название программы ещё неизвестно или показывать его нечему: загрузка, ошибка,
/// «программа не назначена». Когда программа получена, вместо неё —
/// крупная шапка (`LargeTitleSliverAppBar`) с названием. [backFallback] — куда ведёт
/// «назад», если возвращаться некуда (экран открыт по прямой ссылке).
class ProgramFrame extends StatelessWidget {
  const ProgramFrame({
    super.key,
    required this.child,
    this.backFallback = RouteNames.home,
  });

  final Widget child;
  final String backFallback;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton(fallbackLocation: backFallback),
        title: Text(AppLocalizations.of(context).programTitle),
      ),
      body: SafeArea(child: child),
    );
  }
}
