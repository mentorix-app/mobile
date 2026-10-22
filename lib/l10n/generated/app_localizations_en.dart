// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Mentorix';

  @override
  String get themeModeSystem => 'System theme';

  @override
  String get themeModeLight => 'Light theme';

  @override
  String get themeModeDark => 'Dark theme';

  @override
  String get retryAction => 'Try again';

  @override
  String get continueAction => 'Continue';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get loginSubtitle => 'Sign in to continue';

  @override
  String get signInWithGoogle => 'Continue with Google';

  @override
  String get signInWithApple => 'Continue with Apple';

  @override
  String get loginTelegramHint =>
      'Already training via Telegram? Sign in with Google or Apple, then link Telegram on the next step.';

  @override
  String get telegramOfferTitle => 'Do you already train via Telegram?';

  @override
  String get telegramOfferBody =>
      'Link it to continue with your existing account and data.';

  @override
  String get telegramLinkAction => 'Link Telegram';

  @override
  String get telegramSkipAction => 'No, skip';

  @override
  String get telegramCodeTitle => 'Enter the code';

  @override
  String get telegramCodeHint => '8-character code from the bot';

  @override
  String get telegramStep1 => 'Open the bot and tap Start.';

  @override
  String get telegramStep2 =>
      'The bot will send you a code valid for 10 minutes.';

  @override
  String get telegramStep3 => 'Come back here and enter the code.';

  @override
  String get telegramOpenBotAction => 'Open bot';

  @override
  String get telegramCodeSpentHint =>
      'The code was already used or has expired. Get a new one in the bot.';

  @override
  String get inviteTitle => 'Trainer invitation';

  @override
  String get inviteBody =>
      'Paste the invitation link or code you received from your trainer.';

  @override
  String get inviteHint => 'Link or code';

  @override
  String get inviteAcceptAction => 'Accept invitation';

  @override
  String get inviteSkipAction => 'Later';

  @override
  String inviteAccepted(String trainer) {
    return 'You are linked to $trainer';
  }

  @override
  String get inviteAcceptedNoName => 'Invitation accepted';

  @override
  String get trainersTitle => 'My trainers';

  @override
  String get trainerDefaultName => 'Trainer';

  @override
  String get trainersEmptyTitle => 'No trainer yet';

  @override
  String get trainersEmptyBody =>
      'Enter your trainer\'s invitation link or code to see your program.';

  @override
  String get trainersEmptyAction => 'Enter invitation';

  @override
  String get logoutAction => 'Sign out';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileOpenAction => 'Profile';

  @override
  String get profileNameLabel => 'Name';

  @override
  String get profileEmailLabel => 'Email';

  @override
  String get profileValueEmpty => 'Not set';

  @override
  String get deleteAccountAction => 'Delete account';

  @override
  String get deleteAccountDialogTitle => 'Delete account?';

  @override
  String get deleteAccountDialogBody =>
      'Everything will be deleted: your link with the trainer, programs, workout marks and trainer comments, and the Telegram link. The account and its data cannot be restored.';

  @override
  String get deleteAccountConfirmAction => 'Delete permanently';

  @override
  String get errorNetwork =>
      'No connection or the server is waking up. Check your connection and try again.';

  @override
  String get errorServerUnavailable =>
      'The service is temporarily unavailable. Try again later.';

  @override
  String get errorTooManyRequests =>
      'Too many attempts. Wait a bit and try again.';

  @override
  String get errorSessionExpired =>
      'Your session has expired. Please sign in again.';

  @override
  String get errorSocialRejected => 'Sign-in failed. Try again.';

  @override
  String get errorSocialUnavailable =>
      'This sign-in method is not available right now.';

  @override
  String get errorGoogleNotConfigured =>
      'Google sign-in is not configured: run with --dart-define-from-file=config/stage.json';

  @override
  String get errorAppleNotConfigured =>
      'Apple sign-in is not configured: run with --dart-define-from-file=config/stage.json';

  @override
  String get errorAppleStateMismatch =>
      'Could not verify Apple\'s response. Try signing in again.';

  @override
  String get errorAppleConfirmationRetry =>
      'Could not confirm your Apple sign-in. Try again: the Apple window will open once more.';

  @override
  String get errorAppleAccountMismatch =>
      'You signed in with a different Apple ID than the one this account was created with. Choose the same Apple ID.';

  @override
  String get errorAccountDeletionUnavailable =>
      'This account cannot be deleted from the app. Please contact support.';

  @override
  String get errorAccountDeletionFailed =>
      'Could not delete the account. Try again later.';

  @override
  String get errorInvalidRequest =>
      'The request could not be processed. Check the entered data.';

  @override
  String get errorTelegramCodeInvalid =>
      'The code is incorrect, expired or already used.';

  @override
  String get errorAccountNotFound => 'The account no longer exists.';

  @override
  String get errorTelegramConflict =>
      'This Telegram is already linked to another account, and the two cannot be merged.';

  @override
  String get errorTelegramAlreadyLinked =>
      'Another Telegram is already linked to your account.';

  @override
  String get errorInviteNotFound =>
      'Invitation not found. Check the link or code.';

  @override
  String get errorInviteExpired =>
      'This invitation has expired. Ask your trainer for a new one.';

  @override
  String get errorInviteConsumed =>
      'This invitation was already used by someone else.';

  @override
  String get errorInviteClientLimit =>
      'Your trainer has no free spots at the moment.';

  @override
  String get errorInviteNotAllowed =>
      'This invitation cannot be accepted with your account.';

  @override
  String get errorAdminAccount =>
      'Administrator accounts cannot accept invitations.';

  @override
  String get errorWorkoutNotLinked =>
      'You are no longer linked to this trainer.';

  @override
  String get errorWorkoutBlocked =>
      'Your trainer has restricted your access to the program.';

  @override
  String get errorWorkoutDayNotFound => 'This day is no longer in the program.';

  @override
  String get errorWorkoutAlreadyCompleted =>
      'This day is already marked as done.';

  @override
  String get errorWorkoutProgramChanged =>
      'Your trainer has updated the program. Check the day and send your result again.';

  @override
  String get errorWorkoutInvalidResult =>
      'The result was not accepted. It must not be empty or longer than 1000 characters.';

  @override
  String get errorUnknown => 'Something went wrong. Try again.';

  @override
  String get errorOpenTelegram => 'Could not open Telegram.';

  @override
  String get trainerWebOnlyTitle =>
      'Trainer tools are in the web dashboard for now';

  @override
  String get trainerOpenDashboardAction => 'Open dashboard';

  @override
  String get adminWebOnlyTitle =>
      'Administration is only available in the web dashboard';

  @override
  String get errorOpenDashboard => 'Could not open the browser.';

  @override
  String get programTitle => 'Program';

  @override
  String get programNotAssignedTitle => 'No program assigned';

  @override
  String get programNotAssignedBody =>
      'Your trainer hasn\'t assigned a program yet. Pull down to refresh.';

  @override
  String weekLabel(int number) {
    return 'Week $number';
  }

  @override
  String dayLabel(int number) {
    return 'Day $number';
  }

  @override
  String get dayRest => 'Rest day';

  @override
  String get dayCompleted => 'Completed';

  @override
  String programProgress(int done, int total) {
    return 'Completed $done of $total';
  }

  @override
  String get programFinished =>
      'Program completed. Your trainer will assign the next one.';

  @override
  String programDayExercises(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count exercises',
      one: '1 exercise',
    );
    return '$_temp0';
  }

  @override
  String get blockTypeSingle => 'Single';

  @override
  String get blockTypeEmom => 'EMOM';

  @override
  String get blockTypeAmrap => 'AMRAP';

  @override
  String get blockTypeForTime => 'For Time';

  @override
  String get blockTypeIntervals => 'Intervals';

  @override
  String get blockTypeChipper => 'Chipper';

  @override
  String get blockTypeLadder => 'Ladder';

  @override
  String get blockTypeDeathBy => 'Death By';

  @override
  String get blockTypeSuperset => 'Superset';

  @override
  String get blockTypeComplex => 'Complex';

  @override
  String get blockTypeSkillWork => 'Skill Work';

  @override
  String get blockTypeStrength => 'Strength';

  @override
  String get blockTypeConditioning => 'Conditioning';

  @override
  String get blockTypeGymnastics => 'Gymnastics';

  @override
  String get blockTypeWeightlifting => 'Weightlifting';

  @override
  String get blockTypeUnknown => 'Block';
}
