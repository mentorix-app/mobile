📝 Changelog (с abc09f0, develop) — часть 1/2: контракт

Stage: https://mentorix-api-stage.onrender.com. Все запросы с телом шлите с Content-Type: application/json. Ошибки: { "code": "...", "message": "..." } — ветвиться только по `code`, `message` не разбирается и не показывается (см. часть 3). Защищённые запросы: Authorization: Bearer <access_token>; без токена или с негодным — 401.

🔹 `POST /auth/google` — вход и регистрация. Тело: { id_token }. Ответ 200: { access_token, token_type, expires_at, user_id, email, refresh_token }. Первый вход создаёт учётную запись с ролью client. Ошибки: 400 (нет id_token, битый JSON), 401 `invalid_id_token` (токен не принят), 429 `rate_limited`, 503 `provider_not_configured` (вход ещё не настроен на сервере)

🔹 `POST /auth/apple` — то же для Apple. Тело: { id_token, name? }. id_token — identityToken. name — имя пользователя: Apple отдаёт его приложению только при первой авторизации; сохраняется при создании записи, дальше игнорируется; длиннее 100 символов обрезается без ошибки. Ответ и ошибки как у Google

🔹 `POST /auth/refresh` — тело { refresh_token }. Ответ 200 того же вида с новым refresh_token. Ошибки: 401 (токен неверный, просрочен, уже использован или не передан), 429

🔹 `POST /auth/logout` — тело { refresh_token }, ответ 204 всегда. `POST /auth/logout-all` (Bearer) — завершает все сессии пользователя, 204

🔹 `GET /auth/me` (Bearer) — { user_id, email, name, created_at, roles, subscription, telegram_linked }. Новое поле telegram_linked: boolean. subscription у клиента null. `PATCH /auth/me` — { name }, до 100 символов, иначе 400

🔹 `POST /auth/telegram/link` (Bearer) — тело { code }: 8 символов от бота, регистр и пробелы по краям не важны. Ответ 200: тот же формат, что у входа, с новыми токенами. Ошибки: 400 `invalid_link_code` (код неверный, просрочен или уже использован), 404 `user_not_found` (учётной записи больше нет), 409 `telegram_link_conflict` (этот Telegram принадлежит аккаунту, который нельзя объединить с текущим), 409 `telegram_already_linked` (у аккаунта уже привязан другой Telegram), 429 `rate_limited`, 503 (привязка временно недоступна)

🔹 `POST /client/invites/accept` (Bearer) — тело { token }: сам токен, inv_<токен> или вся ссылка-приглашение целиком. Ответ 200: { trainer_id, trainer_display_name, already_linked }. Ошибки: 404 `invite_not_found`, 410 `invite_expired`, 409 `invite_consumed` (использовано другим человеком), 409 `client_limit_reached` (у тренера нет свободных мест), 422 `self_invite` (своё приглашение), 422 `client_blocked` (тренер заблокировал клиента), 403 `admin_cannot_accept` (учётная запись администратора). `already_linked: true` — «уже у этого тренера», успех 200

🔹 Веб-кабинет не затронут — запросы без refresh_token в теле по-прежнему работают через cookie

Контракт: api/openapi.yaml (googleSignIn, appleSignIn, refresh, logout, telegramLink, clientAcceptInvite; схемы IDTokenRequest, AppleSignInRequest, RefreshRequest, TokenResponse, MeResponse, TelegramLinkRequest, ClientAcceptInviteRequest, ClientAcceptInviteResponse)


📝 Changelog — часть 2/2: сценарии и подводные камни

🔹 Сессия — access_token живёт около 15 минут (ориентируйтесь на expires_at), refresh_token 30 дней с момента последнего обновления. Оба храните в защищённом хранилище. Cookie приложению не нужны

🔹 `Content-Type: application/json` обязателен для refresh и logout — без него сервер не читает тело: refresh ответит 401 missing refresh token, а logout ответит 204, но сессию не завершит

🔹 Refresh одноразовый — после каждого обновления сохраняйте новый refresh_token, старый сразу перестаёт работать. Не запускайте два обновления параллельно: второе получит 401. Нужна одна очередь на обновление (общий Future или мьютекс в перехватчике). 401 на refresh означает: показать экран входа

🔹 `email` и `name` могут быть пустой строкой — почта, если провайдер её не подтвердил; имя, если его не было в токене Google или вы не передали name для Apple. Не делайте их обязательными в UI; имя можно задать через PATCH /auth/me

🔹 Порядок экранов после первого входа — 1) GET /auth/me; 2) если telegram_linked: false, спросить «Вы уже занимаетесь через Telegram?» и предложить привязку; 3) только потом приём приглашения. Если клиент сначала примет приглашение, привязать Telegram со старой учётной записью уже не получится (409)

🔹 Привязка Telegram, шаги — открыть https://t.me/<bot>?start=link (stage: `@mentorix_dev_bot`, прода пока нет — `TELEGRAM_BOT_NAME` в `config/stage.json`); пользователь нажимает «Старт», бот присылает код на 10 минут; пользователь возвращается в приложение и вводит код; POST /auth/telegram/link. Бот отвечает кодом только в личном чате

🔹 После привязки всегда заменяйте оба токена на пришедшие — user_id может измениться: если у этого Telegram уже была учётная запись, вход переносится на неё, а новая пустая удаляется. Старые токены перестают работать (404 на /auth/me, 401 на refresh). Сбросьте кэш профиля и перечитайте /auth/me

🔹 Код одноразовый — после любого ответа сервера, кроме 429 и 401, он потрачен. При 400 и 409 предложите получить новый код в боте

🔹 Приглашение тренера — это ссылка https://t.me/<bot>?start=inv_..., по тапу она открывает Telegram. В приложении нужно поле «Вставьте ссылку или код приглашения»; отправляйте вставленное как есть, бэкенд сам достанет токен. already_linked: true показывайте как успех

🔹 Лимит попыток — вход через Google/Apple и привязка Telegram делят один счётчик по IP, у refresh свой такой же (на stage поднят до 100 за 15 минут; превышение — 429 `rate_limited`). На 429 покажите «попробуйте позже», не повторяйте запрос автоматически

🔹 Идентификаторы входа на stage — заведены: Google `aud` = web client id и iOS client id; Apple — `com.mentorix.mobile` (iOS) и `com.mentorix.mobile.signin` (Services ID, Android). /auth/google и /auth/apple больше не отвечают 503 `provider_not_configured`

🔹 Чего на бэкенде ещё нет — экраны клиента (программа, тренировка, отметка выполнения, комментарии); отвязка Telegram; вход по почте и паролю для клиентов не планируется. Удаление учётной записи — есть, см. часть 3


📝 Часть 3: ответ бэкенда на вопросы (источник — `docs/backend_answers.md`, не менять)

🔹 Формат ошибки — любая ошибка API: `{ "code": "...", "message": "..." }`. Приложение ветвится **только по `code`**: он стабильный, `message` бэкенд вправе менять. `message` не разбирается и пользователю не показывается — только в debug-лог рядом со статусом. Если особого кода нет, в `code` — название статуса (`bad_request`, `not_found`, `conflict`, …): такие и вообще неизвестные коды приложение разбирает по HTTP-статусу и показывает общий текст

🔹 Коды ошибок и их разбор в приложении (`ApiErrorCodes`, `AuthErrorMapper`):

| Статус | `code` | Где | Failure в приложении |
|---|---|---|---|
| 401 | `missing_authorization` | защищённые | `SessionExpiredFailure` |
| 401 | `invalid_token` | защищённые | `SessionExpiredFailure` |
| 401 | `invalid_refresh_token` | refresh | `SessionExpiredFailure` |
| 401 | `invalid_id_token` | /auth/google, /auth/apple | `SocialTokenRejectedFailure` |
| 429 | `rate_limited` | любые | `TooManyRequestsFailure` |
| 404 | `user_not_found` | /auth/me, /client/trainers, telegram/link | `AccountNotFoundFailure` (на /auth/me и /client/trainers — конец сессии) |
| 503 | `provider_not_configured` | вход, привязка | `ServerUnavailableFailure` |
| 400 | `invalid_link_code` | telegram/link | `TelegramCodeInvalidFailure` |
| 409 | `telegram_link_conflict` | telegram/link | `TelegramLinkConflictFailure` |
| 409 | `telegram_already_linked` | telegram/link | `TelegramAlreadyLinkedFailure` |
| 404 | `invite_not_found` | invites/accept | `InviteNotFoundFailure` |
| 410 | `invite_expired` | invites/accept | `InviteExpiredFailure` |
| 409 | `invite_consumed` | invites/accept | `InviteAlreadyConsumedFailure` |
| 409 | `client_limit_reached` | invites/accept | `InviteClientLimitReachedFailure` |
| 422 | `self_invite`, `client_blocked` | invites/accept | `InviteNotAllowedFailure` |
| 403 | `admin_cannot_accept` | invites/accept | `AdminAccountFailure` |

Неизвестный `code`: 429 → `TooManyRequestsFailure`, 503 → `ServerUnavailableFailure`, 401 на входе → `SocialTokenRejectedFailure`, 401 в остальных местах → `SessionExpiredFailure`, 400 → `InvalidRequestFailure`, прочее → `UnknownFailure`.

🔹 Форматы — `expires_at` — строка ISO 8601 в UTC (`2026-10-12T06:15:00Z`), unix-время не приходит. `user_id` и `trainer_id` — UUID строкой, число — не тот ответ (`FormatException` → `UnknownFailure`)

🔹 `GET /client/trainers` (Bearer) — `{ "items": [{ "trainer_id", "trainer_display_name", "linked_at" }] }`. `items` всегда массив; пустой — тренера нет, показывать экран приглашения; непустой — экран приглашения пропускается. `trainer_display_name` может быть пустой строкой. Вызывается **после** `GET /auth/me`: порядок после входа — `/auth/me` → `/client/trainers` → экраны (Telegram → приглашение). Ошибки: 404 `user_not_found`, 429. Приглашение, которое пользователь «отложил», повторно не навязывается (локальный флаг по `user_id`)

🔹 Apple на Android — веб-поток. Return URL: `https://mentorix-api-stage.onrender.com/auth/apple/callback` (принимает POST от Apple и отвечает редиректом на `intent://callback?<параметры Apple>#Intent;package=com.mentorix.mobile;scheme=signinwithapple;end`; сессию не создаёт — после возврата приложение само шлёт `id_token` в POST /auth/apple). `clientId` = `com.mentorix.mobile.signin`. В приложении: `WebAuthenticationOptions(clientId, redirectUri)` из `config/stage.json` (`APPLE_SERVICE_ID`, `APPLE_REDIRECT_URI`), активити `SignInWithAppleCallback` в `AndroidManifest.xml` (схема `signinwithapple`, путь `callback`). Кнопка Apple показывается и на Android

🔹 Apple `state` — перед каждым входом приложение генерирует случайный `state` (32 байта, `Random.secure`, base64url), передаёт в `getAppleIDCredential` и сверяет с `credential.state` до отправки токена. Не совпал или не вернулся — токен на сервер не уходит, пользователю «не удалось проверить ответ Apple». Пакет сам `state` не сверяет. Nonce бэкенд не проверяет — генерировать не нужно

🔹 Привязка Telegram — клиент открывает бота командой `/start link`, бот отвечает кодом из 8 символов на 10 минут, код вводится в приложении и уходит в `POST /auth/telegram/link`. Бот для stage — `@mentorix_dev_bot`

🔹 Один человек — две учётные записи — вход через Google, а затем через Apple с той же почтой создаёт две записи. Обрабатывать ничего не нужно: объединение будет на сервере, контракт входа не меняется

🔹 Тренер в приложении — вход тренера своим Google или Apple создаёт отдельный клиентский аккаунт с `roles: ["client"]`, тренерский не затрагивается. Если он привяжет Telegram своего тренерского аккаунта, вход переедет на него, в `roles` будут `trainer` и `client`. Обрабатывать ничего не нужно

🔹 `DELETE /auth/me` (Bearer) — удаление аккаунта, **требование App Store, в приложении пока не реализовано** (см. `docs/ROADMAP.md`). Без тела — если у аккаунта нет входа через Apple. Если вход через Apple есть, перед вызовом снова показать окно Sign in with Apple и отправить `Content-Type: application/json` и `{ "apple_id_token": "<identityToken>", "apple_authorization_code": "<authorizationCode>", "apple_redirect_uri": "<тот же, что redirectUri>" }`; `apple_redirect_uri` — только на Android, на iOS поле не слать. Код одноразовый, живёт 5 минут — брать прямо перед вызовом. Сценарий: сначала без тела; на 422 `apple_authorization_required` показать окно Apple и повторить с телом

| Статус | `code` | Что делать |
|---|---|---|
| 204 | — | удалён, очистить токены |
| 404 | `user_not_found` | уже удалён, считать успехом |
| 422 | `apple_authorization_required` | показать окно Apple, повторить с телом |
| 401 | `invalid_id_token` | токен Apple не прошёл проверку, показать окно заново |
| 403 | `apple_account_mismatch` | вошли не тем Apple-аккаунтом |
| 400 | `invalid_apple_authorization_code` | код просрочен или использован, показать окно заново |
| 502 | `apple_revocation_failed` | Apple не подтвердил отзыв, попробовать позже (на Android проверить `apple_redirect_uri`) |
| 503 | `provider_not_configured` | на сервере ещё нет ключа Apple; сейчас так отвечают все аккаунты со входом через Apple |
| 409 | `account_deletion_unavailable` | роль тренера или администратора — «обратитесь в поддержку» |

После удаления refresh-токен не работает; выданный access живёт до 15 минут, но `GET /auth/me` по нему отвечает 404. Повторный вход тем же Google или Apple создаёт новый пустой аккаунт.

🔹 Открыто, нужно от нас бэкенду — 1) отчёт о прогоне на устройствах (Google iOS и Android, Apple iOS, Apple Android с возвратом в приложение, удаление аккаунта): что прошло, что нет, код ответа и время запроса — в debug-логе приложения каждая строка запроса содержит время (UTC), метод, путь, статус и `code`; 2) формат ссылки для возврата из бота в приложение после привязки Telegram: бэкенд предлагает `https://<домен>/link?code=XXXX` (universal link на iOS и app link на Android; кнопки Telegram принимают только https), либо при своей схеме `mentorix://` — промежуточный адрес на сервере с редиректом
