/// Идентификаторы клиентов для входа через Google и Apple.
///
/// Значения в код не пишутся: приходят при сборке из `config/stage.json`
/// (`flutter run --dart-define-from-file=config/stage.json`). Client id не
/// секретные, файл хранится в репозитории. Если в файле остались плейсхолдеры,
/// вход через Google сообщает, что способ недоступен.
///
/// Те же значения продублированы в `ios/Runner/Info.plist` (`GIDClientID`,
/// `GIDServerClientID`, URL scheme) — их читает iOS SDK; совпадение с
/// `config/stage.json` проверяет тест.
abstract final class SocialAuthConfig {
  static const googleServerClientIdPlaceholder = 'YOUR_GOOGLE_SERVER_CLIENT_ID';
  static const googleIosClientIdPlaceholder = 'YOUR_GOOGLE_IOS_CLIENT_ID';
  static const appleServiceIdPlaceholder = 'YOUR_APPLE_SERVICE_ID';
  static const appleRedirectUriPlaceholder = 'YOUR_APPLE_REDIRECT_URI';

  /// **Web-клиент** из Google Cloud. Передаётся как `serverClientId` на обеих
  /// платформах: тогда `aud` в `id_token` одинаковый на iOS и Android, и
  /// бэкенду достаточно проверять один client id. На Android обязателен.
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: googleServerClientIdPlaceholder,
  );

  /// iOS-клиент из Google Cloud. Передаётся как `clientId` (только iOS;
  /// Android его игнорирует). В `id_token` он попадает в `azp`, а не в `aud`.
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: googleIosClientIdPlaceholder,
  );

  /// Services ID Apple (`com.mentorix.mobile.signin`) — `client_id` веб-потока.
  /// Нужен только на Android: iOS входит нативно по bundle id.
  static const appleServiceId = String.fromEnvironment(
    'APPLE_SERVICE_ID',
    defaultValue: appleServiceIdPlaceholder,
  );

  /// Return URL Services ID: `…/auth/apple/callback` на бэкенде. Сервер
  /// переадресует на `intent://callback?…`, где его ловит
  /// `SignInWithAppleCallback` из `AndroidManifest.xml`.
  static const appleRedirectUri = String.fromEnvironment(
    'APPLE_REDIRECT_URI',
    defaultValue: appleRedirectUriPlaceholder,
  );

  /// Предупреждение в лог, когда Apple Services ID или redirect URI не заданы.
  static const appleNotConfiguredWarning =
      'Apple sign-in на Android не настроен: запусти с '
      '--dart-define-from-file=config/stage.json';

  /// Предупреждение в лог, когда Google client id не задан.
  static const googleNotConfiguredWarning =
      'Google sign-in не настроен: запусти с '
      '--dart-define-from-file=config/stage.json';

  /// Задан ли реальный client id, а не пустая строка или плейсхолдер.
  static bool isRealClientId(String value, String placeholder) =>
      value.isNotEmpty && value != placeholder;
}
