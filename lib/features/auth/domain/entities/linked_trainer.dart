import 'package:equatable/equatable.dart';

/// Тренер, к которому привязан клиент (`GET /client/trainers`).
class LinkedTrainer extends Equatable {
  const LinkedTrainer({
    required this.trainerId,
    required this.trainerDisplayName,
    this.linkedAt,
  });

  /// UUID строкой.
  final String trainerId;

  /// Может быть пустой строкой.
  final String trainerDisplayName;

  final DateTime? linkedAt;

  @override
  List<Object?> get props => [trainerId, trainerDisplayName, linkedAt];
}
