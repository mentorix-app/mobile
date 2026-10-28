/// Правила для текста, который вводит клиент или присылает сервер: результат
/// тренировки (`result_text`) и ответ тренера.
///
/// Контракт (`docs/domain/analytics.md`): `result_text` — от 1 до 1000 символов
/// Unicode после обрезки пробелов; управляющие символы C0 приложение-клиент
/// отправлять не может, кроме `\n`, `\r` и `\t`. Telegram-бот эту проверку не
/// делает, поэтому в тексте из статистики такие символы могут прийти.
abstract final class WorkoutText {
  /// Наибольшая длина результата в символах Unicode (code points) после обрезки
  /// пробелов.
  static const maxResultLength = 1000;

  /// C0 без табуляции, перевода строки и возврата каретки.
  static final _controlChars = RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]');

  /// Текст без управляющих символов C0; `\n`, `\r` и `\t` остаются.
  static String stripControlChars(String text) =>
      text.replaceAll(_controlChars, '');

  /// Длина в символах Unicode (code points), как её считает сервер: эмодзи и
  /// составные символы могут занимать несколько единиц `String.length`, но
  /// считаются так же, как на сервере.
  static int characterCount(String text) => text.runes.length;

  /// Текст результата для отправки: без запрещённых управляющих символов и без
  /// пробелов по краям. `\n`, `\r` и `\t` внутри остаются.
  static String prepareResult(String text) => stripControlChars(text).trim();

  /// Результат подходит серверу: от 1 до [maxResultLength] символов. Передаётся
  /// уже обработанный [prepareResult] текст.
  static bool isValidResult(String prepared) {
    final count = characterCount(prepared);
    return count >= 1 && count <= maxResultLength;
  }
}
