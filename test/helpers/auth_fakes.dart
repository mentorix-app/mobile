import 'dart:async';

import 'package:mentorix_app/features/auth/domain/entities/invite_acceptance.dart';
import 'package:mentorix_app/features/auth/domain/entities/linked_trainer.dart';
import 'package:mentorix_app/features/auth/domain/entities/user_profile.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';
import 'package:mentorix_app/features/auth/domain/repositories/auth_repository.dart';

const testProfile = UserProfile(
  userId: 'user-1',
  email: 'user@example.com',
  name: 'Test User',
  telegramLinked: true,
);

const testTrainer = LinkedTrainer(
  trainerId: 'trainer-1',
  trainerDisplayName: 'Coach',
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

  /// `GET /client/trainers`: пустой список — тренера нет (экран приглашения).
  List<LinkedTrainer> trainers = const [];
  AuthFailure? trainersFailure;
  int trainersCalls = 0;

  /// Если задан — `linkTelegram` бросает его (код при этом считается принятым
  /// сервером к отправке: он попадает в [linkedCodes]).
  AuthFailure? linkFailure;

  /// Если задан — вход через Google и Apple бросает его.
  AuthFailure? signInFailure;

  /// Если задан — `acceptInvite` бросает его.
  AuthFailure? inviteFailure;

  /// Если задан — `deleteAccount` бросает его.
  AuthFailure? deleteFailure;

  /// Если задан — вход и привязка Telegram ждут его завершения (экран остаётся
  /// в состоянии загрузки).
  Completer<void>? gate;

  int clearCalls = 0;

  /// Значение `confirmWithApple` каждого вызова `deleteAccount`.
  final List<bool> deleteCalls = [];
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
  Future<void> signInWithGoogle() async {
    await gate?.future;
    final failure = signInFailure;
    if (failure != null) throw failure;
  }

  @override
  Future<void> signInWithApple() async {
    final failure = signInFailure;
    if (failure != null) throw failure;
  }

  @override
  Future<UserProfile> getProfile({bool forceRefresh = false}) async {
    final failure = profileFailure;
    if (failure != null) throw failure;
    return profile;
  }

  @override
  Future<List<LinkedTrainer>> getTrainers() async {
    trainersCalls++;
    final failure = trainersFailure;
    if (failure != null) throw failure;
    return trainers;
  }

  @override
  Future<UserProfile> updateName(String name) async => profile;

  @override
  Future<void> linkTelegram(String code) async {
    linkedCodes.add(code);
    await gate?.future;
    final failure = linkFailure;
    if (failure != null) throw failure;
    // После привязки /auth/me вернёт telegram_linked: true.
    profile = testProfile;
  }

  @override
  Future<InviteAcceptance> acceptInvite(String tokenOrLink) async {
    acceptedInvites.add(tokenOrLink);
    await gate?.future;
    final failure = inviteFailure;
    if (failure != null) throw failure;
    return const InviteAcceptance(
      trainerId: 'trainer-1',
      trainerDisplayName: 'Coach',
      alreadyLinked: false,
    );
  }

  @override
  Future<void> deleteAccount({bool confirmWithApple = false}) async {
    deleteCalls.add(confirmWithApple);
    await gate?.future;
    final failure = deleteFailure;
    if (failure != null) throw failure;
    hasSession = false;
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

/// Профиль с заданными ролями из `GET /auth/me`.
UserProfile profileWithRoles(List<String> roles) => UserProfile(
  userId: 'user-1',
  email: 'user@example.com',
  name: 'Test User',
  telegramLinked: true,
  roles: roles,
);

/// То же, но Telegram не привязан: клиента ведёт на предложение привязать.
UserProfile unlinkedProfileWithRoles(List<String> roles) => UserProfile(
  userId: 'user-1',
  email: 'user@example.com',
  name: 'Test User',
  telegramLinked: false,
  roles: roles,
);
