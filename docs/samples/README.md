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

## Что проверить в программе

- Приходит ли упражнение без группы блоком `block_type: "single"`.
- `sets: null` у AMRAP, строки вида `5/4` и `8-12`.
- `completed_days` — массив объектов `{"day_key": "..."}`.
- `category` и `difficulty` — ключи или `null`.
