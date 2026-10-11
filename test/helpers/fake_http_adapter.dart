import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef FakeResponder = Future<ResponseBody> Function(RequestOptions options);

/// Сценарный HTTP-адаптер: сети нет, ответ даёт [responder], а все запросы
/// записываются в [requests].
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.responder);

  final FakeResponder responder;
  final List<RequestOptions> requests = [];

  Iterable<RequestOptions> requestsTo(String path) =>
      requests.where((r) => r.path == path);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(
  Object body, {
  int status = 200,
  Map<String, String> headers = const {},
}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      for (final entry in headers.entries) entry.key: [entry.value],
    },
  );
}

Map<String, Object?> tokenJson({
  String access = 'new-access',
  String refresh = 'new-refresh',
  String userId = 'user-1',
  Object? expiresAt = 4102444800, // 2100-01-01
}) => {
  'access_token': access,
  'token_type': 'Bearer',
  'expires_at': expiresAt,
  'user_id': userId,
  'email': 'user@example.com',
  'refresh_token': refresh,
};
