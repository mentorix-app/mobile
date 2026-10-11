// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Mentorix';

  @override
  String get themeModeSystem => 'Системная тема';

  @override
  String get themeModeLight => 'Светлая тема';

  @override
  String get themeModeDark => 'Тёмная тема';

  @override
  String get retryAction => 'Повторить';

  @override
  String get continueAction => 'Продолжить';

  @override
  String get loginTitle => 'Вход';

  @override
  String get loginSubtitle => 'Войдите, чтобы продолжить';

  @override
  String get signInWithGoogle => 'Продолжить с Google';

  @override
  String get signInWithApple => 'Продолжить с Apple';

  @override
  String get telegramOfferTitle => 'Вы уже занимаетесь через Telegram?';

  @override
  String get telegramOfferBody =>
      'Привяжите его, чтобы продолжить со старой учётной записью и данными.';

  @override
  String get telegramLinkAction => 'Привязать Telegram';

  @override
  String get telegramSkipAction => 'Нет, пропустить';

  @override
  String get telegramCodeTitle => 'Введите код';

  @override
  String get telegramCodeHint => '8 символов от бота';

  @override
  String get inviteTitle => 'Приглашение тренера';

  @override
  String get inviteBody =>
      'Вставьте ссылку или код приглашения, который прислал тренер.';

  @override
  String get inviteHint => 'Ссылка или код';

  @override
  String get inviteAcceptAction => 'Принять приглашение';

  @override
  String get inviteSkipAction => 'Позже';

  @override
  String inviteAccepted(String trainer) {
    return 'Вы привязаны к тренеру: $trainer';
  }

  @override
  String get inviteAcceptedNoName => 'Приглашение принято';

  @override
  String get homeTitle => 'Главная';

  @override
  String homeSignedInAs(String identity) {
    return 'Вы вошли как $identity';
  }

  @override
  String get logoutAction => 'Выйти';

  @override
  String get errorNetwork =>
      'Нет соединения или сервер просыпается. Проверьте связь и повторите.';

  @override
  String get errorServerUnavailable =>
      'Сервис временно недоступен. Попробуйте позже.';

  @override
  String get errorTooManyRequests =>
      'Слишком много попыток. Подождите немного и повторите.';

  @override
  String get errorSessionExpired => 'Сессия закончилась. Войдите снова.';

  @override
  String get errorSocialRejected => 'Вход не принят. Попробуйте ещё раз.';

  @override
  String get errorSocialUnavailable => 'Этот способ входа сейчас недоступен.';

  @override
  String get errorInvalidRequest =>
      'Не удалось обработать запрос. Проверьте введённые данные.';

  @override
  String get errorTelegramCodeInvalid =>
      'Код неверный, просрочен или уже использован.';

  @override
  String get errorAccountNotFound => 'Учётной записи больше нет.';

  @override
  String get errorTelegramConflict =>
      'Эти записи нельзя объединить, либо к ним уже привязан другой Telegram.';

  @override
  String get errorInviteNotFound =>
      'Приглашение не найдено. Проверьте ссылку или код.';

  @override
  String get errorInviteExpired =>
      'Срок приглашения истёк. Попросите у тренера новое.';

  @override
  String get errorInviteConsumed =>
      'Это приглашение уже использовал другой человек.';

  @override
  String get errorInviteClientLimit => 'У тренера сейчас нет свободных мест.';

  @override
  String get errorInviteConflict => 'Сейчас это приглашение принять нельзя.';

  @override
  String get errorInviteNotAllowed =>
      'С вашей учётной записью это приглашение принять нельзя.';

  @override
  String get errorAdminAccount =>
      'Учётная запись администратора не может принимать приглашения.';

  @override
  String get errorUnknown => 'Что-то пошло не так. Попробуйте ещё раз.';
}
