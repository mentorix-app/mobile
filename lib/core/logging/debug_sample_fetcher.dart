import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:mentorix_app/core/config/api_endpoints.dart';

/// Ответ API, снятый для `docs/samples/`: путь, статус и тело как пришло.
class DebugSample {
  const DebugSample({
    required this.path,
    required this.status,
    required this.body,
  });

  final String path;
  final int? status;

  /// Тело ответа: JSON с отступами, если разобрался, иначе строка как есть.
  final String body;
}

/// Одноразовый инструмент разработчика: достаёт сырые ответы клиентского API,
/// чтобы сохранить их образцами в `docs/samples/`. Секреты и личные данные в
/// образцах заменяет человек, прежде чем класть файл в репозиторий.
///
/// Только debug: экран, который его вызывает, в release не показывается.
class DebugSampleFetcher {
  DebugSampleFetcher(this._dio);

  /// `Dio` с `AuthInterceptor`: Bearer и refresh подставляет он.
  final Dio _dio;

  Future<DebugSample> trainers() => _get(ApiEndpoints.clientTrainers);

  /// Программа первого тренера из `GET /client/trainers`. Нет тренеров —
  /// образец с пустым телом и без статуса.
  Future<DebugSample> program() async {
    final trainerId = _firstTrainerId((await trainers()).body);
    if (trainerId == null) {
      return const DebugSample(
        path: ApiEndpoints.clientTrainers,
        status: null,
        body: 'no trainers in GET /client/trainers',
      );
    }

    return _get(ApiEndpoints.clientTrainerProgram(trainerId));
  }

  /// `ResponseType.plain` — тело приходит строкой без разбора, ровно как с
  /// сервера. `validateStatus` пропускает любой статус: ошибка API — тоже
  /// образец (например, 403 `client_not_linked`).
  Future<DebugSample> _get(String path) async {
    final response = await _dio.get<String>(
      path,
      options: Options(
        responseType: ResponseType.plain,
        validateStatus: (_) => true,
      ),
    );

    return DebugSample(
      path: path,
      status: response.statusCode,
      body: _pretty(response.data ?? ''),
    );
  }

  static String? _firstTrainerId(String body) {
    try {
      final json = jsonDecode(body);
      final items = json is Map ? json['items'] : null;
      if (items is! List || items.isEmpty) return null;

      final first = items.first;
      final id = first is Map ? first['trainer_id'] : null;
      return id is String && id.isNotEmpty ? id : null;
    } on FormatException {
      return null;
    }
  }

  static String _pretty(String body) {
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(body));
    } on FormatException {
      return body;
    }
  }
}
