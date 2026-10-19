1. Программа клиента у тренера

GET /client/trainers/{trainer_id}/program

Ответ:
{
  "trainer_id": "...",
  "trainer_display_name": "...",
  "assignment": {
    "assignment_id": "...",
    "program_id": "...",
    "program_version_id": "...",
    "completion_cycle_id": "...",
    "assigned_at": "..."
  },
  "program": {
    "program_id": "...", "name": "...", "name_ru": "...",
    "description": "...", "description_ru": "...",
    "category": "...", "difficulty": "...", "preview_image_url": "...",
    "weeks": [ ... недели, дни (у каждого дня есть day_key), блоки и упражнения ... ]
  },
  "completed_days": [ {"day_key": "..."} ]
}

Если программу ещё не назначили, assignment и program приходят как null. category и difficulty тоже могут быть null, если тренер их не заполнил. completed_days всегда массив, по нему рисуешь галочки. В программе только те блоки, которые тренер разрешил клиенту видеть.

Ошибки:
403 client_not_linked: у клиента нет связи с этим тренером
422 client_blocked: тренер заблокировал клиента
400: trainer_id в пути не UUID

2. Отметить тренировку

POST /client/trainers/{trainer_id}/completions
Content-Type: application/json
{
  "program_assignment_id": "...",
  "program_version_id": "...",
  "completion_cycle_id": "...",
  "day_key": "...",
  "result_text": "Сделал 3x10, последний подход тяжело"
}

Первые три значения бери из assignment в ответе программы, day_key из дня.

При успехе отвечаю 201 {"id","day_key","week_number","day_number","completed_at","result_text"}, и при следующем запросе программы этот день будет в completed_days.

Ошибки:
409 workout_already_completed: этот день уже отмечен
409 program_changed: тренер успел поменять программу, перезагрузи её и покажи новую
404 day_not_found: такого дня нет или в нём нет упражнений (день отдыха)
400: пустой текст, текст длиннее 1000 символов, управляющие символы в тексте или не хватает полей
413: тело больше 16 КБ
403 client_not_linked и 422 client_blocked: так же, как в программе

Результат пока только текстом, как в боте. Подходы, вес и повторы добавлю потом новыми полями, а текущие поля не поменяются.

3. Статистика и ответы тренера

GET /client/trainers/{trainer_id}/analytics

Здесь то же, что на странице статистики по ссылке из бота: текущее назначение, активность и последние 30 тренировок с ответами тренера. expires_at в этом ответе всегда null.

Ошибка: 404 client_not_found, если у клиента нет связи с тренером или его заблокировали.

Учти, что на «нет связи» программа и отметка отвечают 403 или 422, а статистика 404.