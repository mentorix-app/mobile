/// Настройки API. Значения приходят при сборке из `config/stage.json`:
/// `flutter run --dart-define-from-file=config/stage.json`.
/// Без файла берётся stage.
abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://mentorix-api-stage.onrender.com',
  );

  /// Stage на Render может просыпаться больше минуты: таймауты не меньше 60 секунд.
  static const connectTimeout = Duration(seconds: 60);
  static const receiveTimeout = Duration(seconds: 60);
  static const sendTimeout = Duration(seconds: 60);
}
