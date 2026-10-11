import 'package:url_launcher/url_launcher.dart';

/// Открытие внешней ссылки в другом приложении (Telegram, браузер).
/// За интерфейсом — чтобы кубиты и тесты не знали про `url_launcher`.
abstract class ExternalLinkLauncher {
  /// `false`, если ссылку открыть не удалось.
  Future<bool> open(Uri uri);
}

class UrlLauncherExternalLinkLauncher implements ExternalLinkLauncher {
  const UrlLauncherExternalLinkLauncher();

  @override
  Future<bool> open(Uri uri) async {
    try {
      // Без canLaunchUrl: он на Android 11+ и iOS требует объявленных схем,
      // а launchUrl сам вернёт false, если открыть нечем.
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }
}
