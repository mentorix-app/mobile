---
name: flutter-feature
description: Создать новую фичу по Clean Architecture — entity, repository, datasource, cubit, state, экран, регистрация в DI и роутере. Использовать при словах «новая фича», «добавь экран», «новый cubit».
---

# Новая фича

Порядок: `domain` → `data` → DI → `presentation` → роутер. Снизу вверх, чтобы на каждом
шаге код компилировался.

```
lib/features/<feature>/
├── domain/
│   ├── entities/<thing>.dart              # неизменяемая модель, Equatable
│   ├── failures/<feature>_failure.dart    # sealed <Feature>Failure, без текста
│   └── repositories/<feature>_repository.dart   # абстрактный класс
├── data/
│   ├── datasources/<feature>_remote_datasource.dart
│   ├── mappers/<feature>_error_mapper.dart      # статусы → Failure, в одном месте
│   └── repositories/<feature>_repository_impl.dart
└── presentation/
    ├── cubit/<feature>_cubit.dart
    ├── cubit/<feature>_state.dart
    ├── <feature>_failure_message.dart     # Failure → локализованный текст
    ├── screens/<feature>_screen.dart
    └── widgets/…
```

## 1. domain

```dart
class Thing extends Equatable {
  const Thing({required this.id, required this.name});

  final String id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}
```

```dart
abstract class FeatureRepository {
  Future<List<Thing>> fetchAll();   // бросает только FeatureFailure
  Future<void> save(Thing thing);
}
```

```dart
// Образец — AuthFailure. Подтипы без текста и без сырого ответа бэкенда.
sealed class FeatureFailure implements Exception {
  const FeatureFailure();
}
final class NetworkFailure extends FeatureFailure { const NetworkFailure(); }
final class UnknownFailure extends FeatureFailure { const UnknownFailure(); }
```

Абстракция живёт в `domain`, реализация — в `data`. Презентация знает только абстракцию.
Ошибки фичи — sealed `FeatureFailure` в `domain/failures/`; `AppErrorCode` и
`AppException` не используются.

## 2. data

Датасорс знает про HTTP и JSON, репозиторий — про домен. Подробнее — скилл `api-data`.

```dart
class FeatureRemoteDatasource {
  FeatureRemoteDatasource({required Dio apiDio}) : _dio = apiDio;

  final Dio _dio;

  Future<List<ThingModel>> fetchAll() async {
    try {
      final response = await _dio.get<Object?>(ApiEndpoints.things);
      return ((response.data as Map<String, dynamic>)['items'] as List)
          .map((e) => ThingModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e, st) {
      AppLogger.dioError(e, st);            // сырой текст — только в лог
      throw FeatureErrorMapper.map(e);      // статусы → FeatureFailure
    } on FormatException catch (e, st) {
      AppLogger.error('unexpected response', e, st);
      throw const UnknownFailure();
    }
  }
}
```

- Датасорс бросает **sealed `FeatureFailure`**, не готовую строку и не код:
  готовая строка в слое данных означает, что переводить нечего. Разбор статусов —
  в одном маппере фичи (образец — `AuthErrorMapper`).
- Публичные эндпоинты (вход, logout) — с `extra: {AuthInterceptor.skipAuthKey: true}`,
  см. скилл `api-data`. Токен подставляет интерсептор, а не датасорс.
- Операции, которые не должны разъезжаться, — одним запросом, а не серией.

## 3. DI

В `lib/core/di/service_locator.dart` зарегистрировать в `get_it`:

```dart
getIt.registerLazySingleton<FeatureRepository>(
  () => FeatureRepositoryImpl(
    FeatureRemoteDatasource(apiDio: getIt<Dio>(instanceName: DioNames.api)),
  ),
);
getIt.registerFactory(() => FeatureCubit(getIt<FeatureRepository>()));
```

Репозитории и клиенты — `registerLazySingleton`, кубиты — `registerFactory`,
чтобы новый экран получал свой экземпляр. Исключение — кубит, на который смотрит
кто-то вне дерева виджетов (как `SessionCubit` для роутера): он singleton и
подаётся через `BlocProvider.value`.

## 4. presentation

Стейты — отдельные классы, чтобы `switch` в слушателе читался:

```dart
sealed class FeatureState extends Equatable {
  const FeatureState();
  @override
  List<Object?> get props => [];
}

class FeatureInitial extends FeatureState { const FeatureInitial(); }
class FeatureLoading extends FeatureState { const FeatureLoading(); }

class FeatureLoaded extends FeatureState {
  const FeatureLoaded(this.things);
  final List<Thing> things;
  @override
  List<Object?> get props => [things];
}

class FeatureError extends FeatureState {
  const FeatureError(this.failure);
  final FeatureFailure failure;
  @override
  List<Object?> get props => [failure];
}
```

Перевод в строку — только здесь, в `presentation`, расширением с исчерпывающим
`switch` (без `_`): новый подтип `Failure` без текста не компилируется.

```dart
extension FeatureFailureMessage on FeatureFailure {
  String message(AppLocalizations l10n) => switch (this) {
    NetworkFailure() => l10n.errorNetwork,
    UnknownFailure() => l10n.errorUnknown,
  };
}
```

В `listener`: `FeatureError(:final failure) => AppSnackBar.showError(context, failure.message(l10n))`.

```dart
class FeatureCubit extends Cubit<FeatureState> {
  FeatureCubit(this._repository) : super(const FeatureInitial());

  final FeatureRepository _repository;

  Future<void> load() async {
    if (state is FeatureLoading) return;        // guard от двойного вызова
    emit(const FeatureLoading());
    try {
      final things = await _repository.fetchAll();
      if (isClosed) return;                     // обязательно после await
      emit(FeatureLoaded(things));
    } on FeatureFailure catch (failure) {
      if (isClosed) return;
      emit(FeatureError(failure));
    }
  }
}
```

Экран — `StatelessWidget`, если нет контроллеров; загрузка запускается в `initState`
того виджета, который владеет экраном, либо прямо в конструкторе кубита, если данные
нужны всегда.

## 5. Роутер

Имя маршрута — в `RouteNames`, провайдер — в `builder`:

```dart
GoRoute(
  path: RouteNames.feature,
  builder: (context, state) => BlocProvider(
    create: (_) => GetIt.I<FeatureCubit>()..load(),
    child: const FeatureScreen(),
  ),
),
```

Если маршрут принимает `extra` — обязательно `redirect` с проверкой типа:

```dart
redirect: (context, state) => state.extra is FeatureRouteExtra ? null : RouteNames.home,
```

Иначе восстановление экрана системой (возврат в убитое приложение) уронит каст.

## Чек-лист перед сдачей

- [ ] Абстракция в `domain`, реализация в `data`, презентация не знает про HTTP и JSON.
- [ ] `isClosed` перед каждым `emit` после `await`.
- [ ] Guard от повторного запуска у операций записи.
- [ ] Ошибки — sealed `FeatureFailure`, не строки; перевод только в `presentation`;
      сырой текст — в `AppLogger`.
- [ ] Все строки в `app_ru.arb` и `app_en.arb`, `flutter gen-l10n` выполнен.
- [ ] Экран без `setState`, без приватных виджет-классов и build-методов.
- [ ] `flutter analyze` чистый, `flutter test` зелёный.
- [ ] `docs/APP_LOGIC.md` описывает новое поведение.
