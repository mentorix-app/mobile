import 'package:mentorix_app/features/auth/domain/entities/invite_acceptance.dart';

class InviteAcceptanceModel extends InviteAcceptance {
  const InviteAcceptanceModel({
    required super.trainerId,
    required super.trainerDisplayName,
    required super.alreadyLinked,
  });

  factory InviteAcceptanceModel.fromJson(Map<String, dynamic> json) {
    final trainerId = json['trainer_id'];
    if (trainerId is! String || trainerId.isEmpty) {
      throw const FormatException('trainer_id is missing');
    }

    final displayName = json['trainer_display_name'];

    return InviteAcceptanceModel(
      trainerId: trainerId,
      trainerDisplayName: displayName is String ? displayName : '',
      alreadyLinked: json['already_linked'] == true,
    );
  }
}
