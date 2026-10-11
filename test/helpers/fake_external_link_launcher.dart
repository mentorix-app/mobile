import 'package:mentorix_app/core/platform/external_link_launcher.dart';

class FakeExternalLinkLauncher implements ExternalLinkLauncher {
  final List<Uri> opened = [];

  /// Что вернёт `open`: `false` — «открыть не удалось».
  bool result = true;

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return result;
  }
}
