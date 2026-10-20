# Mentorix — правила проекта

Flutter-приложение. Свод правил перенесён из проекта Addicted Gym: они проверены
на живом приложении и от продукта не зависят. Как всё устроено — `.claude/README.md`.

| Параметр | Значение |
|---|---|
| Имя пакета | `package:mentorix_app/…` |
| Flutter SDK | `^3.11.4` |
| Состояние | `flutter_bloc` — только Cubit; локальный UI-стейт `ValueNotifier` |
| DI | **`get_it`** — сервис-локатор в `lib/core/di/service_locator.dart` |
| Роутинг | **`go_router`** |
| Бэкенд | **свой API** — `dio`, клиент в `lib/core/network/` |
| Локали | **ru, en** — `flutter_localizations` + `intl`, ARB в `lib/l10n/` |
| Темы | светлая + тёмная, обе описаны в `globals.css` |
| Шрифт | **Inter, встроен в приложение**: `assets/fonts/Inter_18pt-*.ttf` (400 / 500 / 600), лицензия OFL рядом, семейство `Inter` в `pubspec.yaml`. `google_fonts` не используется: шрифт из сети подменял системный и давал скачок текста на первом запуске |
| Иконки и логотипы | логотипы — `assets/icons/*.svg` через `flutter_svg`, пути — константы `Assets` из `lib/generated/assets.dart`; брендовые иконки: Google (цветной, перекрашивать нельзя) и Apple — `assets/icons/google.svg`, `apple.svg` через `BrandSvgIcon`, Telegram — `font_awesome_flutter` (`FaIcon(FontAwesomeIcons.telegram)`); системные — Material Icons |
| Иконка приложения | `flutter_launcher_icons` (`flutter_launcher_icons.yaml`, исходники в `assets/app_icon/`); после смены логотипа: `python3 tool/generate_app_icons.py && dart run flutter_launcher_icons` |
| Нативный сплеш | `flutter_native_splash` (`flutter_native_splash.yaml`, картинки в `assets/splash/`); после смены логотипа или цвета фона: `tool/generate_splash_assets.sh && dart run flutter_native_splash:create`. Цвет фона — токен `background` |
| Идентификатор приложения | `com.mentorix.mobile` (Android `applicationId`/`namespace`, iOS bundle id) |
| Конфиг сборки | `config/stage.json` через `--dart-define-from-file=config/stage.json`: `API_BASE_URL`, `GOOGLE_SERVER_CLIENT_ID`, `GOOGLE_IOS_CLIENT_ID`, `TELEGRAM_BOT_NAME`, `APPLE_SERVICE_ID`, `APPLE_REDIRECT_URI` (два — веб-поток Apple на Android), `DASHBOARD_URL` (веб-кабинет для экрана тренера). Не секретные, файл в git |
| Документы | `docs/ROADMAP.md`, `docs/BUGS.md`, `docs/APP_LOGIC.md`, `docs/FEATURES.md` |

**В начале каждой сессии прочитать `docs/ROADMAP.md`** — разделы «Текущее состояние»
и «Таблица этапов»: что сделано, что на проверке, что следующее. Если файла ещё нет —
создать вместе с `docs/BUGS.md` и `docs/APP_LOGIC.md` (формат — в скилле `stage-workflow`).

---

## 0. Дизайн-токены: источник — `globals.css`

`globals.css` в корне проекта прислан дизайнерами, это **единственный источник**
цветов, радиусов и размеров текста. Придумывать свои значения нельзя; понадобился
новый токен — он сначала появляется в `globals.css`.

Палитра почти целиком ахроматическая (`oklch(L 0 0)`, chroma 0) — это шкала Tailwind
neutral; исключения: `destructive` (красный) и `sidebar-primary` в тёмной теме
(`#1447E6`, синий). `oklch` в Dart не задаётся, поэтому перевод в HEX делается
**один раз** при заводе `AppColors` (тёмная) / `AppLightColors` (светлая), а не
в каждом виджете:

| Токен | Светлая | Тёмная |
|---|---|---|
| `background` | `#FFFFFF` | `#0A0A0A` |
| `foreground` | `#0A0A0A` | `#FAFAFA` |
| `card`, `popover` | `#FFFFFF` | `#171717` |
| `card-foreground` | `#0A0A0A` | `#FAFAFA` |
| `primary` | `#171717` | `#E5E5E5` |
| `primary-foreground` | `#FAFAFA` | `#171717` |
| `secondary`, `muted`, `accent` | `#F5F5F5` | `#262626` |
| `secondary/accent-foreground` | `#171717` | `#FAFAFA` |
| `muted-foreground` | `#737373` | `#A1A1A1` |
| `border` | `#E5E5E5` | белый с `alpha: 0.10` |
| `input` | `#E5E5E5` | белый с `alpha: 0.15` |
| `ring` | `#A1A1A1` | `#737373` |
| `destructive` | `#E7000B` | `#FF6467` |
| `chart-1…5` | `#D4D4D4`, `#737373`, `#525252`, `#404040`, `#262626` | те же |

Радиусы от `--radius: 0.625rem` = **10**: `sm 6`, `md 8`, `lg 10`, `xl 14`,
`2xl 18`, `3xl 22`, `4xl 26`.

Размеры текста — брать **мобильную колонку** (медиазапрос `max-width: 768px`),
приложение телефонное: `h1 24`, `h2 20`, `h3 18`, `h4 16`, `h5 15`,
`p-lg 16`, `p 16`, `p-sm 13`, `p-xs 12`. Отступы контента: `9` по горизонтали,
`8` по вертикали (`--app-content-px/py` в мобильном варианте).

Шкала `AppSpacing` `4 / 8 / 12 / 16 / 24` — решение уровня приложения, в `globals.css`
её нет: пока дизайнеры её не подтвердили, новые значения вне шкалы не добавлять.

`primary` в светлой теме почти чёрный, а в тёмной — почти белый: это инверсия,
а не ошибка. Текст на `primary` берётся из `primary-foreground`, иначе получится
белое на белом.

Что ещё есть в `globals.css` и пригодится позже: `sidebar-*` (для планшетной
раскладки), `--app-header-height: 56`, тонкий скроллбар. `font-sans` там —
Inter с подмножествами latin и cyrillic, в Flutter это встроенное семейство `Inter`
(`ThemeData(fontFamily: 'Inter')`); `fonts.ts` — файл веб-проекта, в приложение не
переносится.

---

## 0.1 Что ещё не решено

- HTTP-клиент поставлен `dio`; если на бэкенде окажется gRPC или GraphQL — менять
  здесь и в скилле `api-data`.
- Аналитика и крэш-репортинг не выбраны.

---

## 1. Состояние

| Что | Чем |
|---|---|
| Локальный UI-стейт | `ValueNotifier` + `ValueListenableBuilder` |
| Стейт фичи | `Cubit` (`flutter_bloc`), без Bloc-событий |
| `setState` | **запрещён**, без исключений |

```dart
// ✅
final _obscure = ValueNotifier<bool>(true);

ValueListenableBuilder<bool>(
  valueListenable: _obscure,
  builder: (context, obscure, _) => IconButton(
    icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
    onPressed: () => _obscure.value = !obscure,
  ),
)

// ❌
bool _obscure = true;
setState(() => _obscure = !_obscure);
```

**Обязательно:**

- `dispose()` для каждого `ValueNotifier`, `TextEditingController`, `AnimationController`
  и `Timer` в том виджете, который его создал. Контроллер, отданный в `showDialog`,
  диспозит сам диалог (`StatefulWidget` внутри), а не вызывающая сторона — иначе
  падение `_dependents.isEmpty` при закрытии.
- Новый список при каждом изменении, если на него подписан `ValueNotifier<List<T>>`:
  мутация того же экземпляра не разбудит слушателей.
- `if (isClosed) return;` перед каждым `emit` после `await`.
- Значения, меняющиеся по таймеру, — в отдельном самотикающем виджете со своим
  `Timer.periodic` и `ValueNotifier`, а не в `build` родителя.

## 2. BlocConsumer и BlocListener

`listener` — всегда switch-выражение через `=>`, не if/else:

```dart
listener: (context, state) => switch (state) {
  AuthAuthenticated() => context.go(RouteNames.home),
  AuthError(:final message) => AppSnackBar.showError(context, message),
  _ => null,
},
```

- Деструктуризация в паттерне (`AuthError(:final message)`), не `state.message`.
- `_ => null` в конце, пока стейты `abstract`, а не `sealed`.
- Многострочная ветка → приватный метод на `State` и вызов из arm.
- В `builder` только чтение из `state`, побочные эффекты — в `listener`.
- Уведомления только через `AppSnackBar.showError/showSuccess/showInfo/showWarning`,
  никогда raw `ScaffoldMessenger`.
- `buildWhen` там, где стейт меняется чаще, чем нужно картинке.

## 3. Виджеты — файл на виджет

- **Приватных виджет-классов нет.** Приватными остаются только `State`-классы.
- **Методов, возвращающих виджеты, нет.** `Widget _buildHeader()` → отдельный публичный
  виджет в своём файле.
- Виджет фичи → `lib/features/<feature>/presentation/widgets/`, общий → `lib/core/widgets/`.
- Перед новым виджетом — поиск по `core/widgets/` и `widgets/` фичи: копии расходятся
  и начинают выглядеть по-разному.
- Списки из изменяемых коллекций — с `key: ValueKey(<стабильный id>)`.

## 4. Архитектура

- Clean Architecture по фичам: `domain` (entities + абстрактные repositories)
  → `data` (datasources + реализации) → `presentation` (cubit + screens + widgets).
- Зависимости регистрируются в `get_it` (`lib/core/di/service_locator.dart`):
  репозитории и клиенты — `registerLazySingleton`, кубиты — `registerFactory`.
  В виджетах `GetIt.I<T>()` вызывается только там, где создаётся кубит, —
  не внутри `build`.
- **Исключение — `SessionCubit`: он регистрируется как `registerLazySingleton`**,
  потому что у сессии один экземпляр на приложение и его слушают и роутер
  (`redirect`, `refreshListenable`), и экраны. Создавать его вторым экземпляром
  нельзя: роутер и экраны увидят разные состояния. В дерево он подаётся через
  `BlocProvider.value`, чтобы дерево его не закрывало.
- Глобальные кубиты (сессия, тема, язык) — в `main.dart` через `MultiBlocProvider`.
  Обычный глобальный кубит (`ThemeCubit`) — `registerFactory` + `BlocProvider(create:)`;
  singleton — только если на кубит смотрит кто-то вне дерева виджетов.
- Кубиты фич — на уровне роута, в `builder` роутера; экраны кубиты не создают.
- `extra` в `go_router` не сериализуется: у каждого маршрута с `extra` — `redirect`
  с проверкой типа, иначе восстановление экрана системой роняет приложение.
- `refreshListenable` роутера дёргать **только при смене факта наличия сессии**, а не на
  каждое событие авторизации: иначе обновление токена пересоберёт маршрут и потеряет `extra`.

## 5. Данные и ошибки

- Текст исключения и `message` из ответа бэкенда пользователю не показываются
  никогда и не разбираются: пользователю — локализованное сообщение, в debug-лог
  идут только статус и `code`. Исключений нет.
- Ошибки фичи — **sealed-класс `<Feature>Failure`** в `domain/failures/`
  (образец — `AuthFailure`): подтипы без текста и без сырого ответа, класс
  `implements Exception`. Датасорс бросает только его подтипы; перевод в строку
  делает **только слой представления** — расширением с исчерпывающим `switch`
  (без `_`), так что новый подтип не компилируется, пока для него нет текста.
  Готовая строка в domain или data означает, что переводить нечего.
- **`enum AppErrorCode` и `AppException` не используются и не заводятся.** Общих
  случаев (нет связи, 429, 503, неизвестная ошибка) пока достаточно повторить в
  `Failure` каждой фичи; когда фич станет несколько и дублирование начнёт мешать,
  выделить общий sealed-базовый класс в `lib/core/`, а не возвращаться к кодам.
- Ошибка API — `{"code","message"}`: ветвиться **только по `code`**, строки кодов —
  константы `ApiErrorCodes` (`lib/core/network/api_error_codes.dart`), не
  `enum AppErrorCode`. Разбор `code` и HTTP-статуса в `Failure` — в **одном** месте
  фичи (маппер ошибок). Неизвестный `code` (в том числе `bad_request`, `not_found`,
  `conflict` — имена статусов) разбирается по статусу в общий текст. Кубит ловит
  `on <Feature>Failure`, а не `Exception`. На 429 ничего не повторяется автоматически.
- **Логирование — только через `AppLogger` и Talker** (`talker_flutter`,
  `talker_dio_logger`). Прямые `print`, `debugPrint`, `developer.log` в коде
  приложения не пишутся. `AppLogger` — ошибки и предупреждения, `DebugLog`
  (`lib/core/logging/debug_log.dart`) — диагностика с тегом (`[mentorix.apple]`,
  `[mentorix.delete]`); оба пишут в единственный `Talker` (`AppTalker`). Запросы к
  API пишет `MaskedTalkerDioLogger` на обоих `Dio`: метод, путь, статус, время,
  заголовки и тела запроса и ответа.
- **Маскировка секретов обязательна** (`SecretMasker`, значение → `***`):
  заголовки `Authorization`, `Cookie`, `Set-Cookie`; в телах, в том числе
  вложенных, — `access_token`, `refresh_token`, `id_token`, `apple_id_token`,
  `apple_authorization_code`, `nonce` (защита входа), `token` (приглашение); `code` — в теле запроса
  `/auth/telegram/link` (в ответах `code` — код ошибки, он виден). Появился новый
  секретный ключ — он сначала добавляется в `SecretMasker` и в тест, а уже потом
  используется в запросах. Логгер маскирует **копию**; настоящие запрос и ответ
  не меняются.
- **Логи — только debug.** В release нет ни `Talker`, ни `TalkerDioLogger`, ни
  экрана логов (`AppLogger` и `DebugLog` там ничего не делают). Экран логов
  (`TalkerScreen`) — долгое нажатие на заголовок профиля (`DebugLogsEntry`).
  Значения одноразовых кодов в `DebugLog` пишутся только как `yes`/`no`.
- Операции, которые не должны разъезжаться, — одним запросом к своему API:
  последовательность из двух запросов при обрыве связи оставляет данные битыми.
- Ответы API разбираются в `data`: модель с `fromJson`, домен не знает про JSON.
  Неизвестное поле или `null` там, где ждали значение, не должны ронять экран.
- Токен авторизации подставляет интерсептор `dio`, а не каждый запрос руками;
  обновление токена — в одном месте, с защитой от параллельных обновлений.
- **Адреса и пути не хардкодятся.** Пути эндпоинтов — константы `ApiEndpoints`
  (`lib/core/config/api_endpoints.dart`), базовый адрес и таймауты — `ApiConfig`.
  Литералов вида `'/auth/me'` и `'https://…'` в датасорсах, перехватчиках и тестах
  нет; новый эндпоинт сначала появляется в `ApiEndpoints`.
- **Публичные эндпоинты** (вход, refresh, logout) датасорс помечает флагом
  `extra: {AuthInterceptor.skipAuthKey: true}`: перехватчик не подставляет Bearer,
  не делает упреждающий refresh и не обрабатывает 401. По путям он их не определяет.
  Упреждающий refresh, упавший не по 401, запрос не отклоняет — запрос уходит
  с текущим токеном.

### Где что хранится

**Ключи — только `StorageKeys`** (`lib/core/storage/storage_keys.dart`): и для
`shared_preferences`, и для `flutter_secure_storage`. Строковых литералов ключей
(`'theme_mode'`, `'access_token'`, …) в датасорсах, репозиториях и тестах нет; новый
ключ сначала появляется там, с пояснением, где он хранится.

| Данные | Где |
|---|---|
| Access- и refresh-токен, любые секреты | **`flutter_secure_storage`** |
| Тема, язык, флаг онбординга, черновики, кеш | **`shared_preferences`** |

`shared_preferences` — незашифрованный файл в песочнице, и на Android он **по умолчанию
уезжает в Google Drive** через Auto Backup: токен в prefs означает токен в чужом облаке.
Secure storage — это iOS Keychain и Android EncryptedSharedPreferences с ключом в Keystore.

Обратное тоже верно: держать в secure storage тему и язык вредно — каждое чтение идёт
через платформенный канал с расшифровкой, а читается это на старте и часто.

```dart
const storage = FlutterSecureStorage(
  iOptions: IOSOptions(
    // Доступно после первой разблокировки (чтобы работало фоновое обновление
    // токена), но не попадает в бэкапы и не синхронизируется в iCloud.
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);
```

Две вещи, которые нужно предусмотреть сразу:

- **Keychain переживает удаление приложения.** После переустановки приложение получит
  протухший токен прошлой установки — на общем устройстве возможно и от чужого аккаунта.
  Решение: на старте проверять флаг установки в `shared_preferences` (они при удалении
  стираются); флага нет — полностью очистить secure storage и поставить флаг.
- **Keystore на Android иногда ломается** после обновления системы или на кривых
  прошивках: чтение падает с `KeyStoreException`. Обрабатывать как «токена нет» и уводить
  на вход, а не падать в цикле. `resetOnError: true` молча стирает всё хранилище —
  лучше ловить ошибку самому и логировать.

Короткоживущий access-токен и ротация refresh-токена на сервере защищают сильнее любого
выбора хранилища. Токены не логировать никогда.
- Прогресс, который жалко потерять, дублировать локально (`SharedPreferences`) —
  он должен переживать убийство приложения.

## 6. Дизайн-система

- Цвета только из токенов, в виджетах — через расширение темы (`context.themeExt`),
  хардкода hex в виджетах нет.
- Отступы, радиусы, тени — `AppSpacing`, `AppRadii`, `AppShadows`.
- Текстовые стили — из `Theme.of(context).textTheme`, одна шкала на обе темы.
- `withValues(alpha:)` вместо deprecated `withOpacity()`.
- Контраст по WCAG AA: 4.5:1 для текста, 3:1 для элементов. На тёмном фоне заливка
  карточки больше 1.2:1 не даёт — работает граница, а не цвет заливки.
- Загрузка — скелетоны, не спиннеры по центру.
- Тактильный отклик на значимые действия (`HapticFeedback`), но не на каждый тап.

## 7. Локализация

- Строка добавляется **сразу во все ARB-файлы**, затем `flutter gen-l10n`.
- Хардкода пользовательских строк в коде нет.
- Числа — ICU-плюрали; даты и время — `DateFormat(..., l10n.localeName)`.
- Переполнения проверять на самой длинной локали: узкие подписи в `FittedBox`,
  ряды равных слотов — `Expanded` с зазором между слотами, не padding внутри каждого.

## 8. Как работаем

- **Этапами.** Один этап = один логический блок правок, после него пользователь проверяет
  в запущенном приложении. Коммит только после подтверждения.
- **Документация обновляется в том же шаге, что и код** (`docs/`). Новая находка
  пользователя сразу попадает в `BUGS.md` и `ROADMAP.md`, чтобы не потерялась.
- **При изменении функционала обновлять `docs/FEATURES.md` в том же коммите.**
  Это обзор для людей (что функция делает, статус, платформы и проверено ли на
  устройстве, эндпоинты, ошибки пользователя, ссылка на `APP_LOGIC.md`): новая или
  изменённая функция, смена статуса, новый текст ошибки, результат проверки на
  устройстве, пункт из «Что запланировано». Простой язык, без кода.
- **`flutter analyze` чистый и `flutter test` зелёный** после каждого этапа.
- **Файлы Xcode — `ios/Runner/Info.plist` и `ios/Runner.xcodeproj/project.pbxproj` —
  могут содержать правки, сделанные пользователем в Xcode** (команда и стиль подписи,
  capability, схемы). **Перед любым откатом таких изменений — `git checkout`,
  `git restore`, `git reset`, перезапись генератором — всегда спрашивать.** Как
  работать с этими файлами:
  - перед правкой смотреть `git diff` по ним: чужое не затирать;
  - править точечно (одна строка), не пересохранять файл целиком;
  - генераторы (`flutter_launcher_icons`, `flutter_native_splash`) их переписывают:
    после запуска смотреть `git diff` и возвращать только собственный мусор;
  - коммитить файлы по именам, а не `git add -A`: так правки Xcode не попадают
    в коммит про другое;
  - Xcode при открытом проекте пересохраняет эти файлы сам (теряет комментарии
    в plist, нормализует pbxproj) — это не повод откатывать.
- **`dart format` на весь файл не запускать** — переформатирование прячет смысловые правки
  в диффе. Проверять через `git diff -w`.
- **Проверять на полностью перезапущенном приложении:** hot reload не вызывает `initState`
  у открытых экранов и не переустанавливает запущенные `Timer.periodic`.
- Коммиты на русском: `feat(scope): …`, `fix(scope): …`, `refactor(scope): …`.

## 9. Особенности платформ

- `PopScope(canPop: false)` на iOS отключает жест «назад» целиком — диалог подтверждения
  свайпом не проверить.
- Разрешение на уведомления запрашивать там, где уведомление понадобится, а не только
  в настройках.
- Уведомление при открытом приложении на iOS баннером не показывается — проверять
  со свёрнутым приложением.
