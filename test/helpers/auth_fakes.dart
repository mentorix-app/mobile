import 'package:mentorix_app/features/auth/domain/entities/invite_acceptance.dart';
import 'package:mentorix_app/features/auth/domain/entities/user_profile.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';
import 'package:mentorix_app/features/auth/domain/repositories/auth_repository.dart';

const testProfile = UserProfile(
  userId: 'user-1',
  email: 'user@example.com',
  name: 'Test User',
  telegramLinked: true,
);

const unlinkedProfile = UserProfile(
  userId: 'user-1',
  email: 'user@example.com',
  name: 'Test User',
  telegramLinked: false,
);

class FakeAuthRepository implements AuthRepository {
  bool hasSession = false;
  UserProfile profile = testProfile;

  /// Если задан — `restoreSession` и `getProfile` бросают его.
  AuthFailure? restoreFailure;
  AuthFailure? profileFailure;

  /// Если задан — `linkTelegram` бросает его (код при этом считается принятым
  /// сервером к отправке: он попадает в [linkedCodes]).
  AuthFailure? linkFailure;

  int clearCalls = 0;
  int logoutCalls = 0;
  final List<String> linkedCodes = [];
  final List<String> acceptedInvites = [];

  @override
  bool get isGoogleSignInAvailable => true;

  /// Apple есть только на iOS и macOS; по умолчанию кнопки Apple нет.
  bool appleAvailable = false;

  @override
  bool get isAppleSignInAvailable => appleAvailable;

  @override
  Future<bool> restoreSession() async {
    final failure = restoreFailure;
    if (failure != null) throw failure;
    return hasSession;
  }

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signInWithApple() async {}

  @override
  Future<UserProfile> getProfile({bool forceRefresh = false}) async {
    final failure = profileFailure;
    if (failure != null) throw failure;
    return profile;
  }

  @override
  Future<UserProfile> updateName(String name) async => profile;

  @override
  Future<void> linkTelegram(String code) async {
    linkedCodes.add(code);
    final failure = linkFailure;
    if (failure != null) throw failure;
    // После привязки /auth/me вернёт telegram_linked: true.
    profile = testProfile;
  }

  @override
  Future<InviteAcceptance> acceptInvite(String tokenOrLink) async {
    acceptedInvites.add(tokenOrLink);
    return const InviteAcceptance(
      trainerId: 'trainer-1',
      trainerDisplayName: 'Coach',
      alreadyLinked: false,
    );
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    hasSession = false;
  }

  @override
  Future<void> logoutAll() async {
    hasSession = false;
  }

  @override
  Future<void> clearLocalSession() async {
    clearCalls++;
    hasSession = false;
  }
}
