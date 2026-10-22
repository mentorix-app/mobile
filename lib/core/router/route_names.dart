abstract final class RouteNames {
  static const splash = '/splash';
  static const login = '/login';
  static const telegramOffer = '/onboarding/telegram';
  static const telegramCode = '/onboarding/telegram/code';
  static const invite = '/onboarding/invite';
  static const home = '/';
  static const profile = '/profile';
  static const trainerWebOnly = '/trainer';
  static const adminWebOnly = '/admin';

  /// Программа клиента у тренера (экраны тренировок). Параметр — `trainer_id`.
  static const trainerProgram = '/trainers/:trainerId';

  static String trainerProgramPath(String trainerId) =>
      '/trainers/${Uri.encodeComponent(trainerId)}';

  /// Экраны тренировок: клиент попадает на них только после онбординга.
  static bool isWorkoutLocation(String location) =>
      location.startsWith('/trainers/');
}
