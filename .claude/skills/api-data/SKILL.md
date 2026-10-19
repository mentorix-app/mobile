---
name: api-data
description: Слой данных на своём REST API — dio-клиент, перехватчик авторизации, модели с fromJson, репозитории, sealed Failure вместо текста ошибок, пагинация, кеш и офлайн. Использовать при словах «запрос», «эндпоинт», «API», «датасорс», «модель ответа», «токен», «ошибка».
---

# Слой данных на своём API

Разделение: `domain` знает только сущности и абстрактный репозиторий, `data` знает
про HTTP и JSON, `presentation` не знает ни про то, ни про другое.

## Клиент

Два экземпляра `Dio` в `lib/core/network/dio_factory.dart`, оба в `get_it`
(`DioNames.plain` и `DioNames.api`):

```dart
// Без перехватчиков: только refresh и повтор запроса внутри AuthInterceptor.
Dio createPlainDio() => Dio(_baseOptions());

// Основной: через него идут все запросы приложения.
Dio createApiDio({required Dio plainDio, required TokenStorage tokens,
    required SessionExpiredNotifier sessionExpired}) {
  final dio = Dio(_baseOptions());
  dio.interceptors.add(AuthInterceptor(
    tokens: tokens, plainDio: plainDio, sessionExpired: sessionExpired));
  return dio;
}

BaseOptions _baseOptions() => BaseOptions(
  baseUrl: ApiConfig.baseUrl,
  contentType: Headers.jsonContentType,      // без него сервер не читает тело
  connectTimeout: ApiConfig.connectTimeout,  // 60 с: stage просыпается долго
  receiveTimeout: ApiConfig.receiveTimeout,
);
```

- `baseUrl` и client id — из `config/stage.json` через
  `--dart-define-from-file=config/stage.json`, не литералами в коде.
- **Пути эндпоинтов — только константы `ApiEndpoints`**
  (`lib/core/config/api_endpoints.dart`): `_dio.get(ApiEndpoints.authMe)`, а не
  `_dio.get('/auth/me')`. Новый эндпоинт сначала добавляется туда — в датасорсе,
  перехватчике и тестах литералов нет.
- Токен подставляет **`AuthInterceptor`**, а не каждый запрос руками. Он же
  обновляет сессию: упреждающий refresh за минуту до `expires_at`, один общий
  refresh на параллельные 401, повтор запроса один раз, 401 на refresh — конец
  сессии. Refresh-токен одноразовый: новый сохраняется сразу.
- **Публичные эндпоинты** (вход, logout, refresh) датасорс помечает флагом
  `options: Options(extra: {AuthInterceptor.skipAuthKey: true})`. Перехватчик их
  не трогает: без Bearer, без упреждающего refresh, без обработки 401. Иначе 401
  «токен провайдера не принят» превратится в «сессия истекла», а refresh перед
  logout испортит refresh-токен в теле. Определять публичность по пути нельзя.
- Упреждающий refresh не удался не по 401 (сеть, 5xx, 429) — запрос уходит с
  текущим токеном, его разберёт обычная обработка 401. Повторять 429
  автоматически нельзя.
- Токен и refresh-токен — в secure storage, не в `SharedPreferences`.

## Модель

```dart
class Mentor extends Equatable {
  const Mentor({required this.id, required this.name, this.avatarUrl});

  factory Mentor.fromJson(Map<String, dynamic> json) => Mentor(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
      );

  final String id;
  final String name;
  final String? avatarUrl;

  @override
  List<Object?> get props => [id, name, avatarUrl];
}
```

- Приводить типы явно и предусматривать `null` там, где бэкенд может его прислать:
  неожидаемый `null` в списке не должен ронять весь экран.
- Поле, которого нет в ответе, — не ошибка парсинга, а значение по умолчанию.
- Домен не содержит `fromJson`: это деталь транспорта.

## Датасорс и ошибки

```dart
// domain/failures/mentor_failure.dart — подтипы без текста и без сырого ответа
sealed class MentorFailure implements Exception {
  const MentorFailure();
}
final class NetworkFailure extends MentorFailure { const NetworkFailure(); }
final class MentorNotFoundFailure extends MentorFailure { const MentorNotFoundFailure(); }
final class UnknownFailure extends MentorFailure { const UnknownFailure(); }
```

```dart
// data/datasources/mentor_remote_datasource.dart
Future<List<Mentor>> fetchMentors({int page = 1}) async {
  try {
    final response = await _dio.get<Object?>(ApiEndpoints.mentors,
        queryParameters: {'page': page});
    return (_object(response)['items'] as List)
        .map((e) => MentorModel.fromJson(e as Map<String, dynamic>))
        .toList();
  } on DioException catch (e, st) {
    AppLogger.dioError(e, st);        // метод, путь, статус — без тел и токенов
    throw MentorErrorMapper.map(e);
  } on FormatException catch (e, st) {
    AppLogger.error('unexpected response', e, st);
    throw const UnknownFailure();
  }
}

// data/mappers/mentor_error_mapper.dart — единственное место разбора статусов
abstract final class MentorErrorMapper {
  static MentorFailure map(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return const NetworkFailure();
    }
    return switch (e.response?.statusCode) {
      404 => const MentorNotFoundFailure(),
      _ => const UnknownFailure(),
    };
  }
}
```

- **Sealed `<Feature>Failure`, не код и не текст.** Образец — `AuthFailure`
  (`lib/features/auth/domain/failures/auth_failure.dart`) и `AuthErrorMapper`.
  Текст от бэкенда на одном языке — это не сообщение для пользователя: перевод
  подставляет **только слой представления** расширением с исчерпывающим `switch`
  (без `_`), новый подтип без текста не компилируется:

  ```dart
  extension MentorFailureMessage on MentorFailure {
    String message(AppLocalizations l10n) => switch (this) {
      NetworkFailure() => l10n.errorNetwork,
      MentorNotFoundFailure() => l10n.errorMentorNotFound,
      UnknownFailure() => l10n.errorUnknown,
    };
  }
  ```
- `AppException` и `AppErrorCode` **не используются**. Общие случаи (нет связи,
  429, 503, неизвестная ошибка) пока повторяются в `Failure` каждой фичи.
- Ошибка API приходит как `{"code","message"}`: ветвиться только по `code`
  (константы `ApiErrorCodes`), `message` не разбирать и не показывать. Неизвестный
  `code` — общий текст по HTTP-статусу. Пользователю — локализованная строка.
- **Логирование — только через `AppLogger` и Talker**, `print`/`debugPrint`/
  `developer.log` не использовать. Запросы пишет `MaskedTalkerDioLogger` (на
  обоих `Dio`): метод, путь, статус, время, заголовки, тела. **Маскировка секретов
  обязательна** (`SecretMasker`, `***`): `Authorization`; в телах, в том числе
  вложенных, `access_token`, `refresh_token`, `id_token`, `apple_id_token`,
  `apple_authorization_code`, `token`; `code` в теле `/auth/telegram/link`.
  Новый секретный ключ — сначала в `SecretMasker` и тест. Маскируется копия:
  запрос и ответ едут дальше без изменений. Только debug: в release нет ни
  Talker, ни логгера в цепочке, ни экрана логов (`DebugLog.enabled`).
- Новый перехватчик ставить так, чтобы логгер видел заголовок `Authorization`:
  `MaskedTalkerDioLogger` идёт после `AuthInterceptor`.
- Таймаут и отсутствие сети — отдельный подтип: пользователю нужно «проверьте
  соединение», а не «что-то пошло не так».
- 429 и 503 — отдельные подтипы; 429 не повторяется автоматически.
- Ошибки валидации (422) желательно донести до полей формы, а не одним снекбаром.

## Списки и пагинация

- Пагинация с первого дня там, где список растёт: страницы или курсор, а не
  «отдай всё». Экран, который получает готовый список через `extra` с другого
  экрана, невозможно пролистать дальше — так в прошлом проекте история обрезалась
  восемью неделями.
- Кеш на сессию для справочников, которые не меняются в ходе работы.
- Данные, которые жалко потерять при обрыве (черновик, незавершённое действие),
  дублировать локально и досылать позже.

## Что проверять по каждому эндпоинту

- [ ] Пустой ответ, одна запись, много записей.
- [ ] 401 — уводит на вход и не теряет введённое.
- [ ] Отсутствие сети и таймаут — понятное сообщение, кнопка «повторить».
- [ ] Повторный тап по кнопке не отправляет два запроса (guard в кубите).
- [ ] Ответ с лишними и отсутствующими полями не роняет экран.
