import 'package:mentorix_app/features/auth/domain/entities/linked_trainer.dart';

class LinkedTrainerModel extends LinkedTrainer {
  const LinkedTrainerModel({
    required super.trainerId,
    required super.trainerDisplayName,
    super.linkedAt,
  });

  /// `trainer_display_name` может быть пустой строкой или отсутствовать.
  factory LinkedTrainerModel.fromJson(Map<String, dynamic> json) {
    final trainerId = json['trainer_id'];
    if (trainerId is! String || trainerId.isEmpty) {
      throw const FormatException('trainer_id is missing');
    }

    final displayName = json['trainer_display_name'];
    final linkedAt = json['linked_at'];

    return LinkedTrainerModel(
      trainerId: trainerId,
      trainerDisplayName: displayName is String ? displayName : '',
      linkedAt: linkedAt is String ? DateTime.tryParse(linkedAt)?.toUtc() : null,
    );
  }

  /// Ответ `{"items": [...]}`; `items` всегда массив, пустой — тренера нет.
  /// Элемент неожиданного вида пропускается, а не роняет экран.
  static List<LinkedTrainerModel> listFromJson(Map<String, dynamic> json) {
    final items = json['items'];
    if (items is! List) throw const FormatException('items is not a list');

    return [
      for (final item in items)
        if (item is Map<String, dynamic>) LinkedTrainerModel.fromJson(item),
    ];
  }
}
