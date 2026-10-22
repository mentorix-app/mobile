import 'package:mentorix_app/features/workout/domain/entities/block_type.dart';
import 'package:mentorix_app/l10n/generated/app_localizations.dart';

/// Подпись типа блока (названия — `docs/BRAND.md`). Список исчерпывающий (без
/// `_`): новый тип без подписи не компилируется. Незнакомый тип подписывается
/// «Блок». У `single` подпись есть, но в интерфейсе не показывается: это обычное
/// упражнение без группы.
extension BlockTypeLabel on BlockType {
  String label(AppLocalizations l10n) => switch (this) {
    BlockType.single => l10n.blockTypeSingle,
    BlockType.emom => l10n.blockTypeEmom,
    BlockType.amrap => l10n.blockTypeAmrap,
    BlockType.forTime => l10n.blockTypeForTime,
    BlockType.intervals => l10n.blockTypeIntervals,
    BlockType.chipper => l10n.blockTypeChipper,
    BlockType.ladder => l10n.blockTypeLadder,
    BlockType.deathBy => l10n.blockTypeDeathBy,
    BlockType.superset => l10n.blockTypeSuperset,
    BlockType.complex => l10n.blockTypeComplex,
    BlockType.skillWork => l10n.blockTypeSkillWork,
    BlockType.strength => l10n.blockTypeStrength,
    BlockType.conditioning => l10n.blockTypeConditioning,
    BlockType.gymnastics => l10n.blockTypeGymnastics,
    BlockType.weightlifting => l10n.blockTypeWeightlifting,
    BlockType.unknown => l10n.blockTypeUnknown,
  };
}
