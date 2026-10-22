import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Прокручиваемая область со «потяни, чтобы обновить» в родном виде платформы.
/// Единственный способ делать pull-to-refresh в приложении (`CLAUDE.md`, §6.1).
///
/// * **iOS и macOS** — `CupertinoSliverRefreshControl` первым сливером (если
///   есть закреплённая шапка [headerSlivers], например `SliverAppBar.large`, —
///   сразу под ней): контент отъезжает вниз, показывается родной индикатор, по
///   завершении всё плавно возвращается. Физика — `BouncingScrollPhysics` поверх
///   `AlwaysScrollableScrollPhysics`.
/// * **Остальные платформы** — `RefreshIndicator` вокруг `CustomScrollView` с
///   `AlwaysScrollableScrollPhysics`; при закреплённой шапке [edgeOffset] опускает
///   индикатор под неё.
///
/// `RefreshIndicator.adaptive` не подходит: он меняет только вид индикатора, а
/// поведение (контент не отъезжает) остаётся материальным.
///
/// Физика всегда «прокручиваемая», поэтому обновление работает и когда контент
/// короче экрана. Платформа берётся из `Theme.of(context).platform`, чтобы в
/// тестах её можно было переключать.
///
/// [onRefresh] должен вернуть `Future`, который завершается, когда обновление
/// закончилось (успехом или ошибкой): пока он не завершён, индикатор не прячется.
class AdaptiveRefreshScrollView extends StatelessWidget {
  const AdaptiveRefreshScrollView({
    super.key,
    required this.onRefresh,
    required this.slivers,
    this.headerSlivers = const [],
    this.edgeOffset = 0,
    this.controller,
  });

  final Future<void> Function() onRefresh;

  /// Содержимое. Индикатор обновления на iOS добавляется перед ним сам.
  final List<Widget> slivers;

  /// Закреплённая шапка (`SliverAppBar`): стоит выше индикатора обновления, чтобы
  /// тот выезжал под шапкой, а не поверх неё.
  final List<Widget> headerSlivers;

  /// Отступ индикатора `RefreshIndicator` сверху (высота закреплённой шапки с
  /// учётом строки состояния). На iOS не используется.
  final double edgeOffset;

  final ScrollController? controller;

  /// iOS и macOS используют родной (Cupertino) индикатор.
  static bool usesCupertino(TargetPlatform platform) =>
      platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

  @override
  Widget build(BuildContext context) {
    if (usesCupertino(Theme.of(context).platform)) {
      return CustomScrollView(
        controller: controller,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          ...headerSlivers,
          CupertinoSliverRefreshControl(onRefresh: onRefresh),
          ...slivers,
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      edgeOffset: edgeOffset,
      child: CustomScrollView(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [...headerSlivers, ...slivers],
      ),
    );
  }
}
