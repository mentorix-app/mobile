abstract final class RouteNames {
  static const splash = '/splash';
  static const login = '/login';
  static const telegramOffer = '/onboarding/telegram';
  static const telegramCode = '/onboarding/telegram/code';
  static const invite = '/onboarding/invite';
  static const home = '/';
  static const profile = '/profile';

  /// Привязка Telegram из профиля: тот же экран ввода кода, что в онбординге
  /// ([telegramCode]), но успех возвращает в профиль, а не ведёт к приглашению.
  static const profileTelegram = '/profile/telegram';
  static const trainerWebOnly = '/trainer';
  static const adminWebOnly = '/admin';

  /// Программа клиента у тренера (экраны тренировок). Параметр — `trainer_id`.
  static const trainerProgram = '/trainers/:trainerId';

  static String trainerProgramPath(String trainerId) =>
      '/trainers/${Uri.encodeComponent(trainerId)}';

  /// День программы: параметры — `trainer_id` и `day_key` (стабильный ключ дня,
  /// не номер: номера меняются вместе с программой).
  static const workoutDay = '/trainers/:trainerId/days/:dayKey';

  static String workoutDayPath(String trainerId, String dayKey) =>
      '/trainers/${Uri.encodeComponent(trainerId)}/days/${Uri.encodeComponent(dayKey)}';

  /// Результат и отметка дня выполненным.
  static const completeDay = '/trainers/:trainerId/days/:dayKey/complete';

  static String completeDayPath(String trainerId, String dayKey) =>
      '${workoutDayPath(trainerId, dayKey)}/complete';

  /// Экраны тренировок: клиент попадает на них только после онбординга.
  static bool isWorkoutLocation(String location) =>
      location.startsWith('/trainers/');
}
