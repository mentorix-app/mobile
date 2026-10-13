import 'package:equatable/equatable.dart';

/// То, что отдаёт Google или Apple и что уходит на бэкенд.
class SocialCredential extends Equatable {
  const SocialCredential({
    required this.idToken,
    this.name,
    this.authorizationCode,
    this.webRedirectUri,
  });

  final String idToken;

  /// Только Apple и только при первой авторизации.
  final String? name;

  /// Только Apple: одноразовый код (живёт 5 минут), нужен бэкенду при удалении
  /// аккаунта, чтобы отозвать токены пользователя у Apple.
  final String? authorizationCode;

  /// Только Apple на Android (веб-поток): redirect URI, с которым получен код.
  /// На iOS `null`.
  final String? webRedirectUri;

  @override
  List<Object?> get props => [
    idToken,
    name,
    authorizationCode,
    webRedirectUri,
  ];
}
