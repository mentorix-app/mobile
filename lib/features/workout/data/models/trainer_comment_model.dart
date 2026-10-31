import 'package:mentorix_app/features/workout/data/models/json_reading.dart';
import 'package:mentorix_app/features/workout/domain/entities/trainer_comment.dart';

class TrainerCommentModel extends TrainerComment {
  const TrainerCommentModel({required super.id, required super.text, super.createdAt});

  /// `text` — ответ тренера (до 2000 символов); управляющие символы убираются.
  factory TrainerCommentModel.fromJson(Map<String, dynamic> json) {
    return TrainerCommentModel(
      id: JsonReading.string(json, 'id'),
      text: JsonReading.userText(json, 'text'),
      createdAt: JsonReading.dateTime(json, 'created_at'),
    );
  }
}
