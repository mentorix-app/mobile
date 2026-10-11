📝 Changelog (с abc09f0, develop) — часть 1/2: контракт

Stage: https://mentorix-api-stage.onrender.com. Все запросы с телом шлите с Content-Type: application/json. Ошибки: { "message": "..." }. Защищённые запросы: Authorization: Bearer <access_token>; без токена или с негодным — 401.

🔹 `POST /auth/google` — вход и регистрация. Тело: { id_token }. Ответ 200: { access_token, token_type, expires_at, user_id, email, refresh_token }. Первый вход создаёт учётную запись с ролью client. Ошибки: 400 (нет id_token, битый JSON), 401 (токен не принят), 429, 503 (вход ещё не настроен на сервере)

🔹 `POST /auth/apple` — то же для Apple. Тело: { id_token, name? }. id_token — identityToken. name — имя пользователя: Apple отдаёт его приложению только при первой авторизации; сохраняется при создании записи, дальше игнорируется; длиннее 100 символов обрезается без ошибки. Ответ и ошибки как у Google

🔹 `POST /auth/refresh` — тело { refresh_token }. Ответ 200 того же вида с новым refresh_token. Ошибки: 401 (токен неверный, просрочен, уже использован или не передан), 429

🔹 `POST /auth/logout` — тело { refresh_token }, ответ 204 всегда. `POST /auth/logout-all` (Bearer) — завершает все сессии пользователя, 204

🔹 `GET /auth/me` (Bearer) — { user_id, email, name, created_at, roles, subscription, telegram_linked }. Новое поле telegram_linked: boolean. subscription у клиента null. `PATCH /auth/me` — { name }, до 100 символов, иначе 400

🔹 `POST /auth/telegram/link` (Bearer) — тело { code }: 8 символов от бота, регистр и пробелы по краям не важны. Ответ 200: тот же формат, что у входа, с новыми токенами. Ошибки: 400 (код неверный, просрочен или уже использован), 404 (учётной записи больше нет), 409 (записи нельзя объединить, либо к этой уже привязан другой Telegram — текст в message), 429, 503 (привязка временно недоступна)

🔹 `POST /client/invites/accept` (Bearer) — тело { token }: сам токен, inv_<токен> или вся ссылка-приглашение целиком. Ответ 200: { trainer_id, trainer_display_name, already_linked }. Ошибки: 404 (приглашение не найдено), 410 (срок истёк), 409 — два случая, различаются по message: invite already consumed (использовано другим человеком) и client limit reached (у тренера нет свободных мест); 422 (своё приглашение или тренер заблокировал клиента), 403 (учётная запись администратора)

🔹 Веб-кабинет не затронут — запросы без refresh_token в теле по-прежнему работают через cookie

Контракт: api/openapi.yaml (googleSignIn, appleSignIn, refresh, logout, telegramLink, clientAcceptInvite; схемы IDTokenRequest, AppleSignInRequest, RefreshRequest, TokenResponse, MeResponse, TelegramLinkRequest, ClientAcceptInviteRequest, ClientAcceptInviteResponse)


📝 Changelog — часть 2/2: сценарии и подводные камни

🔹 Сессия — access_token живёт около 15 минут (ориентируйтесь на expires_at), refresh_token 30 дней с момента последнего обновления. Оба храните в защищённом хранилище. Cookie приложению не нужны

🔹 `Content-Type: application/json` обязателен для refresh и logout — без него сервер не читает тело: refresh ответит 401 missing refresh token, а logout ответит 204, но сессию не завершит

🔹 Refresh одноразовый — после каждого обновления сохраняйте новый refresh_token, старый сразу перестаёт работать. Не запускайте два обновления параллельно: второе получит 401. Нужна одна очередь на обновление (общий Future или мьютекс в перехватчике). 401 на refresh означает: показать экран входа

🔹 `email` и `name` могут быть пустой строкой — почта, если провайдер её не подтвердил; имя, если его не было в токене Google или вы не передали name для Apple. Не делайте их обязательными в UI; имя можно задать через PATCH /auth/me

🔹 Порядок экранов после первого входа — 1) GET /auth/me; 2) если telegram_linked: false, спросить «Вы уже занимаетесь через Telegram?» и предложить привязку; 3) только потом приём приглашения. Если клиент сначала примет приглашение, привязать Telegram со старой учётной записью уже не получится (409)
