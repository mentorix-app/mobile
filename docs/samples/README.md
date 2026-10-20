# Образцы ответов API

Живые ответы клиентского API для проверки моделей и тестов. Секреты и личные данные
заменены до коммита (UUID, имена, почты, ссылки).

| Файл | Запрос |
|---|---|
| `client_trainers.json` | `GET /client/trainers` |
| `client_program.json` | `GET /client/trainers/{trainer_id}/program` |

## Как снять

1. Запустить debug-сборку: `flutter run --dart-define-from-file=config/stage.json`.
2. Войти аккаунтом, которому назначена программа («Mentorix Mobile Test»).
3. Профиль → иконка «Debug: API samples» в шапке → нужная кнопка. Тело ответа уходит в буфер обмена.
4. Вставить в файл из таблицы и заменить личное.

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
