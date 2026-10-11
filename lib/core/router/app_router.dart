import 'package:go_router/go_router.dart';
import 'package:mentorix_app/core/router/route_names.dart';
import 'package:mentorix_app/features/home/presentation/screens/home_screen.dart';

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: RouteNames.home,
    routes: [
      GoRoute(
        path: RouteNames.home,
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
}
