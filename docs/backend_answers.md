Apple на Android: скажи, какой будет адрес Return URL, я пропишу его в Services ID.

Адрес: https://mentorix-api-stage.onrender.com/auth/apple/callback
Я его уже сделал. Он принимает POST от Apple и отвечает редиректом на intent://callback?<все параметры Apple>#Intent;package=com.mentorix.mobile;scheme=signinwithapple;end
Пропиши его в Services ID и передавай в redirectUri, clientId = com.mentorix.mobile.signin. Сессию этот адрес не создаёт: после возврата приложение само шлёт id_token в POST /auth/apple.
Все твои идентификаторы Google и Apple я добавил на stage. Для Google принимаю aud = web client id и iOS client id. Для Apple принимаю com.mentorix.mobile и com.mentorix.mobile.signin.
Одна просьба: передавай в getAppleIDCredential свежий случайный state и сравнивай его с credential.state перед отправкой токена. Пакет state передаёт, но сам не сверяет.


1. Можно добавить в ошибки поле code? Сейчас два разных 409 у приглашения и два у привязки Telegram различаются только текстом message. Если текст поменяется, приложение сломается.

Добавил, во всём API. Любая ошибка теперь выглядит так: {"code": "...", "message": "..."}. Ветвись по code, он стабильный. message я могу менять.
Приглашение (POST /client/invites/accept):
409 invite_consumed - приглашение уже использовал другой человек
409 client_limit_reached - у тренера закончились места по тарифу
ещё бывают 404 invite_not_found, 410 invite_expired, 422 self_invite, 422 client_blocked, 403 admin_cannot_accept
Привязка Telegram (POST /auth/telegram/link):
409 telegram_link_conflict - этот Telegram принадлежит аккаунту, который нельзя объединить с текущим
409 telegram_already_linked - у аккаунта уже привязан другой Telegram
400 invalid_link_code - код неверный, просрочен или уже использован
Общие: 401 missing_authorization, 401 invalid_token, 401 invalid_id_token, 401 invalid_refresh_token, 429 rate_limited, 404 user_not_found.
Если особого кода нет, в code будет название статуса: bad_request, not_found, conflict и так далее.


2. Формат expires_at: unix-секунды или ISO 8601? И какого типа user_id: число или UUID?

expires_at - строка ISO 8601 в UTC, например 2026-10-12T06:15:00Z.
user_id и trainer_id - UUID строкой.


3. Удаление аккаунта: без него App Store не пропустит. Кроме того, Apple требует при удалении отзывать токены пользователя, для этого нужны ключ .p8 и authorization_code. Слать authorization_code в /auth/apple уже сейчас? И когда примерно будет удаление?

Удаление уже сделал, оно на stage: DELETE /auth/me с заголовком Authorization: Bearer <access_token>. Успех - 204 без тела.
authorization_code в /auth/apple слать не нужно. Я ничего от Apple не храню, код мне нужен свежий, в момент удаления.

Если у аккаунта нет входа через Apple, тело не нужно.

Если вход через Apple есть, перед вызовом ещё раз покажи окно Sign in with Apple и отправь:
Content-Type: application/json
{
  "apple_id_token": "<identityToken>",
  "apple_authorization_code": "<authorizationCode>",
  "apple_redirect_uri": "https://mentorix-api-stage.onrender.com/auth/apple/callback"
}
apple_redirect_uri только на Android, тот же адрес, что в redirectUri. На iOS это поле не шли.
Код одноразовый и живёт 5 минут, бери его прямо перед вызовом.
Content-Type: application/json обязателен, когда есть тело. В Dart http.delete(body: String) по умолчанию шлёт text/plain, на это я отвечу 400.

Ответы:
204 - удалён, чисти токены
404 user_not_found - уже удалён, считай успехом
422 apple_authorization_required - у аккаунта есть вход через Apple, а полей нет. Покажи окно Apple и повтори
401 invalid_id_token - токен Apple не прошёл проверку, покажи окно заново
403 apple_account_mismatch - вошли не тем Apple-аккаунтом
400 invalid_apple_authorization_code - код просрочен или уже использован, покажи окно заново
502 apple_revocation_failed - Apple не подтвердил отзыв, попробуй позже. На Android первым делом проверь apple_redirect_uri
503 provider_not_configured - у меня на сервере ещё нет ключа Apple. Сейчас так отвечают все аккаунты со входом через Apple, скоро уберу
409 account_deletion_unavailable - у аккаунта есть роль тренера или администратора, покажи "обратитесь в поддержку"

Самый простой сценарий: вызови DELETE /auth/me без тела. Если пришёл 422 apple_authorization_required, покажи окно Apple и повтори с телом.

Удаляю всё, что относится к клиенту: связи с тренерами, назначения программ, отметки тренировок с комментариями тренера, сессии, способы входа, привязку Telegram.
После удаления refresh token перестаёт работать. Выданный раньше access token живёт до 15 минут, но GET /auth/me по нему отвечает 404. Повторный вход тем же Google или Apple создаёт новый пустой аккаунт.
Проверить отзыв у Apple можно так: приложение исчезает из списка "Вход с Apple" в настройках Apple ID, а следующий вход снова спрашивает имя и почту.


4. Проверяешь ли nonce в токенах Google и Apple? Если да, буду генерировать на клиенте.

Нет, не проверяю. Генерировать не нужно. Если добавлю проверку, скажу заранее.


5. Как понять, что клиент уже привязан к тренеру? На новом устройстве приложение не знает этого и снова покажет экран приглашения. Может, поле в /auth/me? И already_linked — это «уже у этого тренера» или «уже у какого-то»?

Сделал отдельный эндпоинт: GET /client/trainers с Bearer-токеном. Ответ:
{"items": [{"trainer_id": "...", "trainer_display_name": "...", "linked_at": "..."}]}
items всегда массив. Пустой массив значит, что тренера нет, показывай экран приглашения. trainer_display_name может быть пустой строкой.
После входа вызывай сначала GET /auth/me, потом GET /client/trainers.
already_linked значит «уже у этого тренера», то есть у того, кто выдал именно это приглашение. Это успех с кодом 200, не ошибка.


6. Если человек вошёл через Google, а потом через Apple с той же почтой — это одна учётка или две?

Сейчас две. Тебе ничего обрабатывать не нужно. Объединение сделаю на сервере позже, контракт входа от этого не поменяется.


7. Лимит 20 попыток за 15 минут по IP: на stage можно поднять? Мы тестируем с одного Wi-Fi и быстро в него упрёмся.

Поднял до 100 попыток за 15 минут. При превышении отвечаю 429 rate_limited.


8. Тренеры будут работать только в веб-кабинете, приложение только для клиентов. Что будет, если тренер войдёт в приложение своим Google или Apple аккаунтом? Ему добавится роль client, или приложению нужно это как-то обработать?

Создастся отдельный клиентский аккаунт с roles: ["client"]. Его тренерский аккаунт в кабинете не затрагивается, роль ему не добавляется. Обрабатывать ничего не нужно.
Если он потом привяжет в приложении Telegram своего тренерского аккаунта, вход переедет в тренерский аккаунт, и в roles будут trainer и client.


9. Имена ботов для stage и прода - это наш Mentorix Dev?

Для stage это @mentorix_dev_bot. Прода пока нет, есть только stage.
Привязка Telegram работает так: клиент открывает бота командой /start link, бот отвечает кодом из 8 символов, код живёт 10 минут, его нужно ввести в приложении и отправить в POST /auth/telegram/link.


10. Не срочно: может ли бот после привязки сразу вернуть пользователя в приложение диплинком с кодом, чтобы не вводить его руками?

Может, сделаю. Мне нужна от тебя ссылка, которую открывает приложение. Кнопки в Telegram принимают только https, поэтому лучше universal link на iOS и app link на Android вида https://<домен>/link?code=XXXX.
Если у тебя только своя схема вида mentorix://, скажи, я сделаю промежуточный адрес на сервере, который перенаправит в приложение.


Что мне нужно от тебя:
1. Прогон на устройствах: вход через Google на iOS и Android, вход через Apple на iOS, вход через Apple на Android с возвратом в приложение, удаление аккаунта. Напиши, что прошло, а что нет, с кодом ответа и временем запроса, я посмотрю логи.
2. Формат ссылки для пункта 10.