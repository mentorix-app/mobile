/// Тип блока тренировки (`block_type`, `docs/domain/programs.md`).
///
/// `single` — упражнение без группы. Тип, которого приложение не знает (его
/// добавили на сервере раньше, чем в приложении), — [unknown]: экран не падает,
/// а показывает запасную подпись «Блок».
enum BlockType {
  single('single'),
  emom('emom'),
  amrap('amrap'),
  forTime('for_time'),
  intervals('intervals'),
  chipper('chipper'),
  ladder('ladder'),
  deathBy('death_by'),
  superset('superset'),
  complex('complex'),
  skillWork('skill_work'),
  strength('strength'),
  conditioning('conditioning'),
  gymnastics('gymnastics'),
  weightlifting('weightlifting'),
  unknown('');

  const BlockType(this.key);

  /// Значение `block_type` в API.
  final String key;

  /// Тип по ключу API; пустой, `null` и незнакомый ключ — [unknown].
  static BlockType fromKey(String? key) {
    for (final type in values) {
      if (type != unknown && type.key == key) return type;
    }
    return unknown;
  }

  /// Упражнение без группы: показывается как обычное упражнение, без подписи
  /// типа и без рамки блока.
  bool get isSingle => this == single;
}
