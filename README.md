# Mentorix

Мобильное приложение Mentorix на Flutter: вход через Google и Apple, привязка
Telegram, приглашение тренера.

| | |
|---|---|
| Flutter SDK | `^3.11.4` |
| Идентификатор | `com.mentorix.mobile` (Android и iOS) |
| Состояние | `flutter_bloc` (только Cubit) |
| DI и навигация | `get_it`, `go_router` |
| Бэкенд | свой REST API через `dio` |
| Локали | ru, en |
| Темы | светлая и тёмная, токены из `globals.css` |
| Шрифт | Inter, встроен в приложение (`assets/fonts`) |

## Запуск

```sh
flutter pub get
flutter run --dart-define-from-file=config/stage.json
```

То же для сборок: `flutter build apk --dart-define-from-file=config/stage.json`.

Готовые конфигурации запуска уже в репозитории: VS Code — `.vscode/launch.json`
(«mentorix (stage)» и варианты profile и release), Android Studio —
`.run/main.dart (stage).run.xml`.

На iOS после `flutter pub get` один раз: `cd ios && pod install`. Подпись
настраивается в Xcode (`ios/Runner.xcworkspace`, команда и «Automatically manage
signing»).

### Конфигурация сборки

Значения приходят при сборке из `config/stage.json` (`--dart-define-from-file`).
Они не секретные, поэтому файл лежит в репозитории.

| Ключ | Что это |
|---|---|
| `API_BASE_URL` | адрес API (по умолчанию stage) |
| `GOOGLE_SERVER_CLIENT_ID` | web-клиент Google; `serverClientId` на обеих платформах |
| `GOOGLE_IOS_CLIENT_ID` | iOS-клиент Google |
| `TELEGRAM_BOT_NAME` | имя бота без `@` (stage: `mentorix_dev_bot`) |
| `APPLE_SERVICE_ID` | Services ID Apple (`com.mentorix.mobile.signin`): `clientId` веб-потока на Android |
| `APPLE_REDIRECT_URI` | Return URL Services ID: `…/auth/apple/callback` на бэкенде; на Android возвращает в приложение через `SignInWithAppleCallback` |

- Без `--dart-define-from-file` приложение запускается, но вход через Google
  (и через Apple на Android) сообщает, что он не настроен, а кнопка «Открыть бота»
  неактивна.
- В debug-сборке каждый запрос к API пишет в консоль (`debugPrint`, видно в
  `flutter run` и Debug Console VS Code) строку: время (UTC), метод, путь, статус и
  `code` из ответа — по ней бэкенд сверяет запросы со своими логами. Рядом с текстом
  ошибки на экране показываются статус и `code`. В release ничего этого нет.
- Client id Google продублированы в `ios/Runner/Info.plist` (`GIDClientID`,
  `GIDServerClientID`, URL scheme): при смене меняются оба файла, совпадение
  проверяет тест.

## Проверки

```sh
flutter analyze --no-pub
flutter test
```

## Структура

```
lib/
├── core/        конфиг, DI, сеть, хранилище, роутер, тема, общие виджеты
├── features/    auth, home, theme — по слоям domain / data / presentation
├── l10n/        ARB (ru, en) и сгенерированный AppLocalizations
└── generated/   константы путей ассетов (assets.dart)
```

- Строки — только через `AppLocalizations`; после правки ARB: `flutter gen-l10n`.
- Цвета, радиусы и размеры текста — токены `globals.css`, в коде — `context.themeExt`.
- Пути API — `ApiEndpoints`, ключи хранилища — `StorageKeys`.

## Нативный сплеш

Экран запуска (до первого кадра Flutter) — фон темы и логотип, настройка в
`flutter_native_splash.yaml`. После смены логотипа или цвета фона (macOS):

```sh
tool/generate_splash_assets.sh && dart run flutter_native_splash:create
```

## Иконка приложения

Исходники — `assets/app_icon/`, их делает скрипт из `assets/icons/mini-logo.svg`
(macOS). После смены логотипа:

```sh
python3 tool/generate_app_icons.py && dart run flutter_launcher_icons
```

Генераторы переписывают `ios/Runner/Info.plist` и `ios/Runner.xcodeproj/project.pbxproj`:
после запуска смотрите `git diff` по ним и не затирайте правки из Xcode.

## Документация

| Файл | О чём |
|---|---|
| `docs/ROADMAP.md` | этапы, решения, сценарии проверки, вопросы к бэкенду |
| `docs/APP_LOGIC.md` | как приложение работает (поведение) |
| `docs/BUGS.md` | найденные проблемы |
| `docs/auth_api.md` | контракт API авторизации |
