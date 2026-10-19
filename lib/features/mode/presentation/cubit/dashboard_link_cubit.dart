import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mentorix_app/core/config/dashboard_config.dart';
import 'package:mentorix_app/core/logging/app_logger.dart';
import 'package:mentorix_app/core/platform/external_link_launcher.dart';
import 'package:mentorix_app/features/mode/presentation/cubit/dashboard_link_state.dart';

/// Открытие веб-кабинета в браузере с экрана тренера.
class DashboardLinkCubit extends Cubit<DashboardLinkState> {
  DashboardLinkCubit(this._launcher, {String url = DashboardConfig.url})
    : _uri = DashboardConfig.parse(url),
      super(const DashboardLinkIdle()) {
    if (_uri == null) {
      AppLogger.warning(
        'DASHBOARD_URL не задан в config/stage.json: кнопка «Открыть дашборд» '
        'неактивна.',
      );
    }
  }

  final ExternalLinkLauncher _launcher;
  final Uri? _uri;

  bool get isConfigured => _uri != null;

  /// `false` — адрес не задан или браузер открыть не удалось.
  Future<bool> openDashboard() async {
    final uri = _uri;
    if (uri == null || state is DashboardLinkOpening) return false;

    emit(const DashboardLinkOpening());
    final opened = await _launcher.open(uri);
    if (!isClosed) emit(const DashboardLinkIdle());
    return opened;
  }
}
