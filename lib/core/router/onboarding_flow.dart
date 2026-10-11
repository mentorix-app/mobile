import 'package:mentorix_app/core/router/route_names.dart';
import 'package:mentorix_app/core/storage/storage_keys.dart';
import 'package:mentorix_app/features/auth/domain/entities/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Порядок экранов после входа (`docs/auth_api.md`): профиль → если
/// `telegram_linked == false`, предложение привязать Telegram → приглашение.
///
/// Приглашение нельзя принимать раньше привязки Telegram: после него
/// привязать Telegram к старой учётной записи уже не получится (409).
///
/// Пройденные шаги хранятся в `shared_preferences` отдельно для каждого
/// `user_id`: это не секрет, а `user_id` может поменяться после привязки.
class OnboardingFlow {
  OnboardingFlow(this._prefs);

  final SharedPreferences _prefs;

  String nextRoute(UserProfile profile) {
    final id = profile.userId;

    final offerDone =
        _prefs.getBool(StorageKeys.onboardingTelegramOfferDone(id)) ?? false;
    final inviteDone =
        _prefs.getBool(StorageKeys.onboardingInviteDone(id)) ?? false;

    if (!profile.telegramLinked && !offerDone) {
      return RouteNames.telegramOffer;
    }
    if (!inviteDone) return RouteNames.invite;
    return RouteNames.home;
  }

  Future<void> skipTelegramOffer(String userId) =>
      _prefs.setBool(StorageKeys.onboardingTelegramOfferDone(userId), true);

  /// Приглашение принято или пропущено.
  Future<void> completeInvite(String userId) =>
      _prefs.setBool(StorageKeys.onboardingInviteDone(userId), true);
}
