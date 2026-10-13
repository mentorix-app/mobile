/// Тело `DELETE /auth/me` для аккаунтов со входом через Apple: Apple требует
/// отозвать токены пользователя при удалении, поэтому бэкенду нужен свежий
/// `authorization_code` (одноразовый, живёт 5 минут).
class AppleDeletionProof {
  const AppleDeletionProof({
    required this.idToken,
    required this.authorizationCode,
    this.redirectUri,
  });

  final String idToken;
  final String authorizationCode;

  /// Только Android (веб-поток): тот же адрес, что `redirectUri` входа.
  /// На iOS поле не отправляется.
  final String? redirectUri;

  Map<String, Object> toJson() => {
    'apple_id_token': idToken,
    'apple_authorization_code': authorizationCode,
    'apple_redirect_uri': ?redirectUri,
  };
}
