# mentorix_app

A new Flutter project.

## Запуск

Адрес API и client id Google берутся из файла конфигурации при сборке
(`--dart-define-from-file`). Client id не секретные, поэтому `config/stage.json`
лежит в репозитории.

```sh
flutter run --dart-define-from-file=config/stage.json
```

То же для сборок: `flutter build apk --dart-define-from-file=config/stage.json`.

Готовые конфигурации запуска уже в репозитории: VS Code — `.vscode/launch.json`
(«mentorix (stage)» и варианты profile и release), Android Studio —
`.run/main.dart (stage).run.xml`. Без `--dart-define-from-file` приложение
запускается, но вход через Google сообщает, что он не настроен.

В `config/stage.json` лежат client id Google: `GOOGLE_SERVER_CLIENT_ID` — web-клиент
(он же `serverClientId` на обеих платформах), `GOOGLE_IOS_CLIENT_ID` — iOS-клиент.
Client id продублированы в `ios/Runner/Info.plist` (`GIDClientID`,
`GIDServerClientID`, URL scheme), совпадение проверяет тест. При смене client id
меняются оба файла. Если в файле плейсхолдеры `YOUR_GOOGLE_…`, вход через Google
сообщает, что способ недоступен.

`TELEGRAM_BOT_NAME` — имя Telegram-бота без `@`. Пока там плейсхолдер
`YOUR_TELEGRAM_BOT_NAME`, кнопка «Открыть бота» неактивна.

Проверки перед коммитом: `flutter analyze --no-pub` и `flutter test`.

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

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
