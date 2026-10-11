# Mentorix — найденные проблемы

Каждая находка пользователя записывается сюда **до** исправления и параллельно попадает
в этап в `ROADMAP.md`.

Формат пункта:

```
### N. Короткое название
- **Severity:** блокирующая | высокая | средняя | низкая
- **Статус:** ⬜ открыто | 🟡 в работе | ✅ ИСПРАВЛЕНО <дата>
- **Запрошено пользователем:** <дата>
- **Описание:** что видно и как воспроизвести.
- **Что сделано:** (после исправления) файлы и строки.
```

## Журнал исправлений

| Дата | № | Что |
|---|---|---|
| 2026-10-11 | 1 | Тема переключается через `ThemeCubit`, выбор хранится в `shared_preferences` |
| 2026-10-11 | 2 | Пути к картинкам берутся из `Assets` (`lib/generated/assets.dart`) |

## Исправлено

### 1. Тема не переключается через Cubit
- **Severity:** средняя
- **Статус:** ✅ ИСПРАВЛЕНО 2026-10-11
- **Запрошено пользователем:** 2026-10-11
- **Описание:** `MentorixApp` держал `themeMode: ThemeMode.system`, выбрать тему внутри
  приложения было нельзя.
- **Что сделано:**
  - `lib/features/theme/` — `ThemeRepository` (domain), `ThemeRepositoryImpl` на
    `shared_preferences` (data), `ThemeCubit` и временная `ThemeModeButton` (presentation);
  - `lib/app.dart` — `themeMode` берётся из `ThemeCubit` через `BlocBuilder`;
  - `lib/main.dart` — `ThemeCubit` в `MultiBlocProvider`, `main()` стал `async`;
  - `lib/core/di/service_locator.dart` — регистрация `SharedPreferences`, репозитория
    и кубита, `configureDependencies()` стал `async`;
  - `lib/features/home/presentation/screens/home_screen.dart` — кнопка в `AppBar`;
  - `lib/l10n/app_en.arb`, `app_ru.arb` — `themeModeSystem`, `themeModeLight`,
    `themeModeDark`.
  - Тесты: `test/features/theme/theme_cubit_test.dart`, `test/widget_test.dart`.

### 2. Пути к картинкам — строковые литералы
- **Severity:** низкая
- **Статус:** ✅ ИСПРАВЛЕНО 2026-10-11
- **Запрошено пользователем:** 2026-10-11
- **Описание:** `HomeScreen` писал `'assets/icons/full-logo.svg'` руками; опечатка
  в пути вылезла бы только в рантайме.
- **Что сделано:** `lib/features/home/presentation/screens/home_screen.dart` использует
  `Assets.iconsFullLogo` и `Assets.iconsFullLogoDark` из `lib/generated/assets.dart`
  (создан расширением VS Code «Flutter Assets Generator Pro»). Файл **хранится в git**:
  расширение работает только в IDE, на чистом клоне и в CI без него файла не будет
  и проект не соберётся.

## Открытые

Пока пусто.

## Снятые

### 3. Пункт из оборвавшегося сообщения
- **Запрошено пользователем:** 2026-10-11
- **Статус:** снят пользователем в тот же день («про 3 пункт забудь»).
