import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mentorix_app/core/router/route_names.dart';

/// Кнопка «назад» для первой страницы `ShellRoute`.
///
/// У такой страницы свой вложенный `Navigator` с единственным маршрутом, поэтому
/// `AppBar` сам кнопку не рисует (ему «некуда» возвращаться), хотя на уровень выше
/// есть предыдущий экран. Кнопка закрывает страницу оболочки целиком; если
/// возвращаться некуда (экран открыт по прямой ссылке), ведёт на главный экран.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BackButton(
      onPressed: () {
        final router = GoRouter.of(context);
        router.canPop() ? router.pop() : router.go(RouteNames.home);
      },
    );
  }
}
