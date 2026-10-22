# Образцы ответов API

Живые ответы клиентского API для проверки моделей и тестов. Секреты и личные данные
заменены до коммита (UUID, имена, почты, ссылки).

| Файл | Запрос |
|---|---|
| `client_trainers.json` | `GET /client/trainers` |
| `client_program.json` | `GET /client/trainers/{trainer_id}/program` |
| `client_analytics_empty.json` | `GET /client/trainers/{trainer_id}/analytics`, **до первой отметки** (пустая статистика) |
| `client_analytics.json` | то же, **после первой отметки** (запись с результатом и, если тренер ответил, с его ответом) |

## Как снять

1. Запустить debug-сборку: `flutter run --dart-define-from-file=config/stage.json`.
2. Войти аккаунтом, которому назначена программа («Mentorix Mobile Test»).
3. Профиль → иконка «Debug: API samples» (`{ }`, справа в шапке) → нужная кнопка (`GET /client/trainers`,
   `…/program` или `…/analytics`). Тело ответа уходит в буфер обмена.
4. Вставить в файл из таблицы и заменить личное. В статистике личные тексты — `result_text`
   записей и `text` ответов тренера (`comments`), имена тренера и клиента, UUID.

Иконка есть только в debug; в release экрана нет.

## Что показали образцы (2026-10-20)

- Упражнение без группы приходит блоком `block_type: "single"`.
- День отдыха — `"blocks": []`.
- У упражнений AMRAP нет ключа `sets` (не `null`); `reps` — строка (`"8-12"`).
- `instruction` и `preview_image_url` без значения — пустая строка.
- `completed_days` — пустой массив, пока ничего не отмечено.
- `category` и `difficulty` — ключи (`functional`, `intermediate`).

Это тестовый аккаунт и тестовая программа: UUID и имя тренера настоящие, но секретов
в файлах нет.

## Что показал образец статистики до первой отметки (2026-10-22)

`client_analytics_empty.json` сверен с `ClientSelfAnalytics` в `docs/api/openapi.yaml`:
все обязательные поля на месте, лишних нет.

- `recent_completions: []`, `activity.by_program: []`, `first_completed_at` и
  `last_completed_at` — `null`, `week_streak` и счётчики — `0`.
- `current_assignment` есть сразу после назначения: `progress.total_training_days: 3`,
  одна неделя в `progress.weeks`. `assignment_id` в нём нет (он только в ответе программы).
- `completion_percent` приходит **целым** (`0`, а не `0.0`) — модель читает любое число.
- `client.display_name` — пустая строка (имя у аккаунта не задано); `trainer.display_name`
  заполнено. Пустое имя допустимо.
- `expires_at: null`, как и сказано в схеме для этого пути.
- `client_user_id` и `trainer_id` в файле при обезличивании искажены (длиннее UUID).
  Модели и тесты не должны проверять формат UUID — идентификаторы читаются как строки.
