/// Название на языке приложения: `*_ru`, если язык русский и поле не пустое,
/// иначе основное (`name`, `exercise_name`). Если основное пусто, а русское
/// есть — русское; оба пусты — пустая строка (подставляет вызывающий).
///
/// Правило бэкенда: `name` заполнен всегда, любое `*_ru` необязательно.
String localizedName({
  required String name,
  required String nameRu,
  required String localeName,
}) {
  final main = name.trim();
  final russian = nameRu.trim();

  if (localeName == 'ru' && russian.isNotEmpty) return russian;
  return main.isNotEmpty ? main : russian;
}
