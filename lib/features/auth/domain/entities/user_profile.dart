import 'package:equatable/equatable.dart';
import 'package:mentorix_app/features/auth/domain/entities/app_mode.dart';

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

  static const roleClient = 'client';
  static const roleTrainer = 'trainer';
  static const roleAdmin = 'admin';

  /// Режимы, доступные по ролям, в порядке приоритета.
  ///
  /// - `admin` исключителен (ограничение в БД), поэтому перебивает остальное;
  /// - `client` и `trainer` вместе — оба режима, клиентский первым;
  /// - только `trainer` — тренерский;
  /// - ролей нет или они незнакомы — клиентский: вход через провайдера создаёт
  ///   клиента, а права всё равно проверяет сервер.
  List<AppMode> get availableModes {
    if (roles.contains(roleAdmin)) return const [AppMode.admin];

    final isClient = roles.contains(roleClient);
    final isTrainer = roles.contains(roleTrainer);

    if (isClient && isTrainer) return const [AppMode.client, AppMode.trainer];
    if (isTrainer) return const [AppMode.trainer];
    return const [AppMode.client];
  }

  /// Режим, в котором приложение открывается. Сейчас это первый из
  /// [availableModes]: у `client` + `trainer` — клиентский.
  ///
  /// Место под переключение режимов: когда оно появится, выбранный режим будет
  /// храниться в сессии и приходить сюда же, а список [availableModes] решит,
  /// показывать ли переключатель (длина больше единицы).
  AppMode get mode => availableModes.first;

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
