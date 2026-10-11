/// Идентификаторы клиентов для входа через Google и Apple.
///
/// Значения в код не пишутся: приходят при сборке из `config/stage.json`
/// (`flutter run --dart-define-from-file=config/stage.json`). Client id не
/// секретные, файл хранится в репозитории. Пока в нём плейсхолдеры, вход через
/// Google сообщает, что способ недоступен.
abstract final class SocialAuthConfig {
  static const googleServerClientIdPlaceholder = 'YOUR_GOOGLE_SERVER_CLIENT_ID';
  static const googleIosClientIdPlaceholder = 'YOUR_GOOGLE_IOS_CLIENT_ID';

  /// Web-клиент из Google Cloud: именно для него Google выпускает `id_token`,
  /// который проверяет бэкенд (на Android обязателен, иначе `idToken` будет `null`).
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: googleServerClientIdPlaceholder,
  );

  /// iOS-клиент из Google Cloud. Нужен только на iOS.
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: googleIosClientIdPlaceholder,
  );

  static bool get isGoogleConfigured =>
      googleServerClientId.isNotEmpty &&
      googleServerClientId != googleServerClientIdPlaceholder;

  static bool get isGoogleIosConfigured =>
      googleIosClientId.isNotEmpty &&
      googleIosClientId != googleIosClientIdPlaceholder;
}
