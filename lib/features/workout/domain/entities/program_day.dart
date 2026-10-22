import 'package:equatable/equatable.dart';
import 'package:mentorix_app/features/workout/domain/entities/block_type.dart';
import 'package:mentorix_app/features/workout/domain/entities/program_block.dart';

/// День недели программы.
class ProgramDay extends Equatable {
  const ProgramDay({
    required this.id,
    required this.dayKey,
    required this.dayNumber,
    this.blocks = const [],
  });

  /// Идентификатор строки; меняется при публикации, ключом отметок не служит.
  final String id;

  /// Стабильный идентификатор дня: по нему идут `completed_days` и отметка.
  /// Пустая строка — сервер ключ не прислал: день виден, но отметить его нельзя.
  final String dayKey;

  final int dayNumber;
  final List<ProgramBlock> blocks;

  /// День отдыха — день без блоков (отдельного признака нет). Его отметка
  /// вернула бы 404 `day_not_found`.
  bool get isRest => blocks.isEmpty;

  /// Тренировочный день: считается в прогрессе.
  bool get isTraining => !isRest;

  int get exerciseCount =>
      blocks.fold(0, (sum, block) => sum + block.exercises.length);

  /// Можно ли отправить отметку: есть ключ и хотя бы одно упражнение. Страховка
  /// от дня, который сервер не примет (`day_not_found`).
  bool get canComplete => dayKey.isNotEmpty && exerciseCount > 0;

  /// Типы групповых блоков в порядке появления, без повторов. Одиночные
  /// упражнения (`single`) подписи типа не имеют и сюда не входят.
  List<BlockType> get groupTypes => [
    for (final type in {
      for (final block in blocks)
        if (!block.type.isSingle) block.type,
    })
      type,
  ];

  @override
  List<Object?> get props => [id, dayKey, dayNumber, blocks];
}
