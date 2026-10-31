import 'package:equatable/equatable.dart';

/// Ответ тренера на результат. Клиент его только читает: ответить нельзя. На одну
/// отметку приходится один ответ (в схеме — список, показываем все по порядку).
class TrainerComment extends Equatable {
  const TrainerComment({required this.id, required this.text, this.createdAt});

  final String id;
  final String text;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [id, text, createdAt];
}
