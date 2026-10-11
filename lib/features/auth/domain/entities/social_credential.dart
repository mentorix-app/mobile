import 'package:equatable/equatable.dart';

/// То, что отдаёт Google или Apple и что уходит на бэкенд.
class SocialCredential extends Equatable {
  const SocialCredential({required this.idToken, this.name});

  final String idToken;

  /// Только Apple и только при первой авторизации.
  final String? name;

  @override
  List<Object?> get props => [idToken, name];
}
