import 'package:equatable/equatable.dart';

/// Ответ `POST /client/invites/accept`.
class InviteAcceptance extends Equatable {
  const InviteAcceptance({
    required this.trainerId,
    required this.trainerDisplayName,
    required this.alreadyLinked,
  });

  final String trainerId;
  final String trainerDisplayName;

  /// Клиент уже был привязан к этому тренеру.
  final bool alreadyLinked;

  @override
  List<Object?> get props => [trainerId, trainerDisplayName, alreadyLinked];
}
