/// Веб-кабинет (дашборд), куда ведёт экран тренера.
///
/// Адрес приходит при сборке из `config/stage.json` (ключ `DASHBOARD_URL`).
/// Пока там плейсхолдер, кнопка «Открыть дашборд» неактивна.
abstract final class DashboardConfig {
  static const urlPlaceholder = 'YOUR_DASHBOARD_URL';

  static const url = String.fromEnvironment(
    'DASHBOARD_URL',
    defaultValue: urlPlaceholder,
  );

  static bool get isConfigured => isRealUrl(url);

  /// Реальный адрес: абсолютный `http(s)://…`, не пустая строка и не плейсхолдер.
  static bool isRealUrl(String value) => parse(value) != null;

  /// `null` — адрес не задан или это не `http(s)`-ссылка.
  static Uri? parse([String value = url]) {
    if (value.isEmpty || value == urlPlaceholder) return null;

    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;
    return uri;
  }
}
