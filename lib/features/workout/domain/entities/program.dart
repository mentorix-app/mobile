import 'package:equatable/equatable.dart';
import 'package:mentorix_app/features/workout/domain/entities/program_week.dart';

/// Программа, как её видит клиент: недели, дни, блоки, упражнения.
/// Категория, сложность, описание и картинка в версии 1 не показываются и не
/// разбираются.
class Program extends Equatable {
  const Program({
    required this.id,
    required this.name,
    this.nameRu = '',
    this.weeks = const [],
  });

  final String id;

  /// Заполнено всегда.
  final String name;

  /// Может быть пустым: на stage у большинства программ пусто.
  final String nameRu;

  final List<ProgramWeek> weeks;

  @override
  List<Object?> get props => [id, name, nameRu, weeks];
}
