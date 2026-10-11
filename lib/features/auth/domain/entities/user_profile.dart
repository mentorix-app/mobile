import 'package:equatable/equatable.dart';

/// Ответ `GET /auth/me`.
///
/// `email` и `name` могут быть пустой строкой (провайдер не подтвердил почту,
/// имени не было в токене) — в UI они не обязательны.
class UserProfile extends Equatable {
  const UserProfile({
    required this.userId,
    required this.email,
    required this.name,
    required this.telegramLinked,
    this.createdAt,
    this.roles = const [],
  });

  final String userId;
  final String email;
  final String name;
  final bool telegramLinked;
  final DateTime? createdAt;
  final List<String> roles;

  /// Что показать в интерфейсе, когда имя пустое.
  String get displayName => name.isNotEmpty ? name : email;

  @override
  List<Object?> get props => [
    userId,
    email,
    name,
    telegramLinked,
    createdAt,
    roles,
  ];
}
