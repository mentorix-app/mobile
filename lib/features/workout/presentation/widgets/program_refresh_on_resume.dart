import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mentorix_app/features/workout/presentation/cubit/program_cubit.dart';

/// Тихо обновляет программу, когда приложение возвращается на передний план:
/// день мог быть отмечен в Telegram-боте, а тренер — поменять программу. Ошибка
/// такого обновления не сообщается, показанные данные остаются.
class ProgramRefreshOnResume extends StatefulWidget {
  const ProgramRefreshOnResume({super.key, required this.child});

  final Widget child;

  @override
  State<ProgramRefreshOnResume> createState() => _ProgramRefreshOnResumeState();
}

class _ProgramRefreshOnResumeState extends State<ProgramRefreshOnResume>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<ProgramCubit>().refresh(silent: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
