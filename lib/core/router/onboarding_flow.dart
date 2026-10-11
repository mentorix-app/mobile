import 'package:mentorix_app/core/router/route_names.dart';
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

    if (!profile.telegramLinked && !(_prefs.getBool(_offerKey(id)) ?? false)) {
      return RouteNames.telegramOffer;
    }
    if (!(_prefs.getBool(_inviteKey(id)) ?? false)) {
      return RouteNames.invite;
    }
    return RouteNames.home;
  }

  Future<void> skipTelegramOffer(String userId) =>
      _prefs.setBool(_offerKey(userId), true);

  /// Приглашение принято или пропущено.
  Future<void> completeInvite(String userId) =>
      _prefs.setBool(_inviteKey(userId), true);

  String _offerKey(String userId) => 'onboarding_telegram_offer_done_$userId';

  String _inviteKey(String userId) => 'onboarding_invite_done_$userId';
}
