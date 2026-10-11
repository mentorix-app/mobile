import 'package:mentorix_app/features/auth/domain/entities/user_profile.dart';

class UserProfileModel extends UserProfile {
  const UserProfileModel({
    required super.userId,
    required super.email,
    required super.name,
    required super.telegramLinked,
    super.createdAt,
    super.roles,
  });

  /// `email` и `name` могут быть пустой строкой, неизвестные поля игнорируются.
  /// Без `user_id` профиль бессмыслен — [FormatException].
  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    final userId = json['user_id'];
    if (userId == null || userId.toString().isEmpty) {
      throw const FormatException('user_id is missing');
    }

    final email = json['email'];
    final name = json['name'];
    final createdAt = json['created_at'];
    final roles = json['roles'];

    return UserProfileModel(
      userId: userId.toString(),
      email: email is String ? email : '',
      name: name is String ? name : '',
      telegramLinked: json['telegram_linked'] == true,
      createdAt: createdAt is String ? DateTime.tryParse(createdAt) : null,
      roles: roles is List ? roles.whereType<String>().toList() : const [],
    );
  }
}
