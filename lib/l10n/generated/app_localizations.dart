import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// Application name, shown in the task switcher
  ///
  /// In en, this message translates to:
  /// **'Mentorix'**
  String get appTitle;

  /// Theme mode that follows the device setting
  ///
  /// In en, this message translates to:
  /// **'System theme'**
  String get themeModeSystem;

  /// No description provided for @themeModeLight.
  ///
  /// In en, this message translates to:
  /// **'Light theme'**
  String get themeModeLight;

  /// No description provided for @themeModeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark theme'**
  String get themeModeDark;

  /// No description provided for @retryAction.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retryAction;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get loginSubtitle;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get signInWithGoogle;

  /// No description provided for @signInWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get signInWithApple;

  /// No description provided for @telegramOfferTitle.
  ///
  /// In en, this message translates to:
  /// **'Do you already train via Telegram?'**
  String get telegramOfferTitle;

  /// No description provided for @telegramOfferBody.
  ///
  /// In en, this message translates to:
  /// **'Link it to continue with your existing account and data.'**
  String get telegramOfferBody;

  /// No description provided for @telegramLinkAction.
  ///
  /// In en, this message translates to:
  /// **'Link Telegram'**
  String get telegramLinkAction;

  /// No description provided for @telegramSkipAction.
  ///
  /// In en, this message translates to:
  /// **'No, skip'**
  String get telegramSkipAction;

  /// No description provided for @telegramCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get telegramCodeTitle;

  /// No description provided for @telegramCodeHint.
  ///
  /// In en, this message translates to:
  /// **'8-character code from the bot'**
  String get telegramCodeHint;

  /// No description provided for @inviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Trainer invitation'**
  String get inviteTitle;

  /// No description provided for @inviteBody.
  ///
  /// In en, this message translates to:
  /// **'Paste the invitation link or code you received from your trainer.'**
  String get inviteBody;

  /// No description provided for @inviteHint.
  ///
  /// In en, this message translates to:
  /// **'Link or code'**
  String get inviteHint;

  /// No description provided for @inviteAcceptAction.
  ///
  /// In en, this message translates to:
  /// **'Accept invitation'**
  String get inviteAcceptAction;

  /// No description provided for @inviteSkipAction.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get inviteSkipAction;

  /// No description provided for @inviteAccepted.
  ///
  /// In en, this message translates to:
  /// **'You are linked to {trainer}'**
  String inviteAccepted(String trainer);

  /// No description provided for @inviteAcceptedNoName.
  ///
  /// In en, this message translates to:
  /// **'Invitation accepted'**
  String get inviteAcceptedNoName;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTitle;

  /// No description provided for @homeSignedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {identity}'**
  String homeSignedInAs(String identity);

  /// No description provided for @logoutAction.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get logoutAction;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection or the server is waking up. Check your connection and try again.'**
  String get errorNetwork;

  /// No description provided for @errorServerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The service is temporarily unavailable. Try again later.'**
  String get errorServerUnavailable;

  /// No description provided for @errorTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a bit and try again.'**
  String get errorTooManyRequests;

  /// No description provided for @errorSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again.'**
  String get errorSessionExpired;

  /// No description provided for @errorSocialRejected.
  ///
  /// In en, this message translates to:
  /// **'Sign-in was not accepted. Try again.'**
  String get errorSocialRejected;

  /// No description provided for @errorSocialUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This sign-in method is not available right now.'**
  String get errorSocialUnavailable;

  /// No description provided for @errorInvalidRequest.
  ///
  /// In en, this message translates to:
  /// **'The request could not be processed. Check the entered data.'**
  String get errorInvalidRequest;

  /// No description provided for @errorTelegramCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'The code is incorrect, expired or already used.'**
  String get errorTelegramCodeInvalid;

  /// No description provided for @errorAccountNotFound.
  ///
  /// In en, this message translates to:
  /// **'The account no longer exists.'**
  String get errorAccountNotFound;

  /// No description provided for @errorTelegramConflict.
  ///
  /// In en, this message translates to:
  /// **'These accounts cannot be merged, or another Telegram is already linked.'**
  String get errorTelegramConflict;

  /// No description provided for @errorInviteNotFound.
  ///
  /// In en, this message translates to:
  /// **'Invitation not found. Check the link or code.'**
  String get errorInviteNotFound;

  /// No description provided for @errorInviteExpired.
  ///
  /// In en, this message translates to:
  /// **'This invitation has expired. Ask your trainer for a new one.'**
  String get errorInviteExpired;

  /// No description provided for @errorInviteConsumed.
  ///
  /// In en, this message translates to:
  /// **'This invitation was already used by someone else.'**
  String get errorInviteConsumed;

  /// No description provided for @errorInviteClientLimit.
  ///
  /// In en, this message translates to:
  /// **'Your trainer has no free spots at the moment.'**
  String get errorInviteClientLimit;

  /// No description provided for @errorInviteConflict.
  ///
  /// In en, this message translates to:
  /// **'This invitation cannot be accepted right now.'**
  String get errorInviteConflict;

  /// No description provided for @errorInviteNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'This invitation cannot be accepted with your account.'**
  String get errorInviteNotAllowed;

  /// No description provided for @errorAdminAccount.
  ///
  /// In en, this message translates to:
  /// **'Administrator accounts cannot accept invitations.'**
  String get errorAdminAccount;

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get errorUnknown;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
