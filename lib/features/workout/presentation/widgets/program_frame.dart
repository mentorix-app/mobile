import 'package:flutter/material.dart';
import 'package:mentorix_app/core/widgets/app_back_button.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Обычная шапка с кнопкой «назад» и словом «Программа» для экрана, пока
/// название программы ещё неизвестно или показывать его нечему: загрузка, ошибка,
/// «программа не назначена». Когда программа получена, вместо неё —
/// [ProgramAppBar] с крупным названием.
class ProgramFrame extends StatelessWidget {
  const ProgramFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(AppLocalizations.of(context).programTitle),
      ),
      body: SafeArea(child: child),
    );
  }
}
