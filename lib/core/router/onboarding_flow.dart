import 'package:mentorix_app/core/router/route_names.dart';
import 'package:mentorix_app/core/storage/storage_keys.dart';
import 'package:mentorix_app/features/auth/domain/entities/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Порядок экранов после входа (`docs/auth_api.md`): профиль → если
/// `telegram_linked == false`, предложение привязать Telegram → если
/// `GET /client/trainers` вернул пустой `items`, приглашение.
///
/// Приглашение нельзя принимать раньше привязки Telegram: после него
/// привязать Telegram к старой учётной записи уже не получится (409).
///
/// Пройденные шаги хранятся в `shared_preferences` отдельно для каждого
/// `user_id`: это не секрет, а `user_id` может поменяться после привязки.
class OnboardingFlow {
  OnboardingFlow(this._prefs);

  final SharedPreferences _prefs;

  /// [hasTrainer] — `items` из `GET /client/trainers` не пуст: приглашение
  /// такому клиенту не показывается.
  String nextRoute(UserProfile profile, {required bool hasTrainer}) {
    final id = profile.userId;

    final offerDone =
        _prefs.getBool(StorageKeys.onboardingTelegramOfferDone(id)) ?? false;
    final inviteDone =
        _prefs.getBool(StorageKeys.onboardingInviteDone(id)) ?? false;

    if (!profile.telegramLinked && !offerDone) {
      return RouteNames.telegramOffer;
    }
    if (!hasTrainer && !inviteDone) return RouteNames.invite;
    return RouteNames.home;
  }

  Future<void> skipTelegramOffer(String userId) =>
      _prefs.setBool(StorageKeys.onboardingTelegramOfferDone(userId), true);

  /// Аккаунт удалён: его отметки о пройденных шагах больше не нужны.
  Future<void> forget(String userId) async {
    await _prefs.remove(StorageKeys.onboardingTelegramOfferDone(userId));
    await _prefs.remove(StorageKeys.onboardingInviteDone(userId));
  }

  /// Приглашение принято или пропущено.
  Future<void> completeInvite(String userId) =>
      _prefs.setBool(StorageKeys.onboardingInviteDone(userId), true);
}
