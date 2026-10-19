import 'package:equatable/equatable.dart';

sealed class DashboardLinkState extends Equatable {
  const DashboardLinkState();

  @override
  List<Object?> get props => [];
}

class DashboardLinkIdle extends DashboardLinkState {
  const DashboardLinkIdle();
}

/// Браузер запрашивается: кнопка на это время неактивна.
class DashboardLinkOpening extends DashboardLinkState {
  const DashboardLinkOpening();
}
