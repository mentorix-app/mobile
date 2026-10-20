import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/network/auth_tokens.dart';
import 'package:mentorix_app/core/network/session_expired_notifier.dart';
import 'package:mentorix_app/core/storage/token_storage.dart';
import 'package:mentorix_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:mentorix_app/features/auth/data/models/apple_deletion_proof.dart';
import 'package:mentorix_app/features/auth/data/models/invite_acceptance_model.dart';
import 'package:mentorix_app/features/auth/data/models/linked_trainer_model.dart';
import 'package:mentorix_app/features/auth/data/models/user_profile_model.dart';
import 'package:mentorix_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mentorix_app/features/auth/data/storage/pending_apple_name_storage.dart';
import 'package:mentorix_app/features/auth/domain/entities/social_credential.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';
import 'package:mentorix_app/features/auth/domain/providers/social_auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRemote implements AuthRemoteDataSource {
  int getMeCalls = 0;
  AuthFailure? getMeFailure;
  String meUserId = 'user-1';
  AuthFailure? appleFailure;
  String? lastAppleName;
  bool appleCalled = false;
  AuthFailure? logoutFailure;

  AuthTokens linkResult = const AuthTokens(
    accessToken: 'linked-access',
    refreshToken: 'linked-refresh',
    userId: 'user-2',
  );

  @override
  Future<UserProfileModel> getMe() async {
    getMeCalls++;
    final failure = getMeFailure;
    if (failure != null) throw failure;
    return UserProfileModel(
      userId: meUserId,
      email: 'a@b.c',
      name: 'N',
      telegramLinked: false,
    );
  }

  List<LinkedTrainerModel> trainers = const [];
  AuthFailure? trainersFailure;

  @override
  Future<List<LinkedTrainerModel>> getTrainers() async {
    final failure = trainersFailure;
    if (failure != null) throw failure;
    return trainers;
  }

  @override
  Future<AuthTokens> linkTelegram(String code) async => linkResult;

  @override
  Future<AuthTokens> signInWithApple(
    String idToken, {
    String? name,
    String? nonce,
  }) async {
    appleCalled = true;
    lastAppleName = name;
    final failure = appleFailure;
    if (failure != null) throw failure;
    return const AuthTokens(
      accessToken: 'apple-access',
      refreshToken: 'apple-refresh',
      userId: 'user-1',
    );
  }

  @override
  Future<AuthTokens> signInWithGoogle(String idToken) async =>
      const AuthTokens(
        accessToken: 'google-access',
        refreshToken: 'google-refresh',
        userId: 'user-1',
      );

  @override
  Future<void> logout(String refreshToken) async {
    final failure = logoutFailure;
    if (failure != null) throw failure;
  }

  @override
  Future<void> logoutAll() async {}

  @override
  Future<void> deleteAccount({AppleDeletionProof? apple}) async {}

  @override
  Future<void> updateName(String name) async {}

  @override
  Future<InviteAcceptanceModel> acceptInvite(String token) async =>
      const InviteAcceptanceModel(
        trainerId: 't',
        trainerDisplayName: 'T',
        alreadyLinked: false,
      );
}

class _FakeProvider implements SocialAuthProvider {
  _FakeProvider(this.credentials);

  final List<SocialCredential> credentials;

  @override
  bool get isAvailable => true;

  @override
  Future<SocialCredential> signIn({bool withNonce = false}) async => credentials.removeAt(0);

  @override
  Future<void> disconnect() async {}
}

void main() {
  late TokenStorage tokens;
  late _FakeRemote remote;
  late SessionExpiredNotifier sessionExpired;
  late int sessionExpiredEvents;

  AuthRepositoryImpl createRepository({
    List<SocialCredential> apple = const [],
  }) {
    return AuthRepositoryImpl(
      remote: remote,
      tokens: tokens,
      sessionExpired: sessionExpired,
      pendingAppleName: PendingAppleNameStorage(const FlutterSecureStorage()),
      google: _FakeProvider([const SocialCredential(idToken: 'g')]),
      apple: _FakeProvider([...apple]),
    );
  }

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    tokens = TokenStorage(
      const FlutterSecureStorage(),
      await SharedPreferences.getInstance(),
    );
    remote = _FakeRemote();
    sessionExpired = SessionExpiredNotifier();
    sessionExpiredEvents = 0;
    sessionExpired.stream.listen((_) => sessionExpiredEvents++);
  });

  group('привязка Telegram', () {
    test('заменяет оба токена и user_id', () async {
      await tokens.save(
        const AuthTokens(
          accessToken: 'old-access',
          refreshToken: 'old-refresh',
          userId: 'user-1',
        ),
      );
      final repository = createRepository();

      await repository.linkTelegram('  abcd1234 ');

      expect(await tokens.readAccessToken(), 'linked-access');
      expect(await tokens.readRefreshToken(), 'linked-refresh');
      expect(await tokens.readUserId(), 'user-2');
    });

    test('сбрасывает кеш профиля: следующий getProfile идёт в сеть', () async {
      final repository = createRepository();

      await repository.getProfile();
      await repository.getProfile();
      expect(remote.getMeCalls, 1, reason: 'второй вызов — из кеша');

      await repository.linkTelegram('abcd1234');
      remote.meUserId = 'user-2';
      final profile = await repository.getProfile();

      expect(remote.getMeCalls, 2);
      expect(profile.userId, 'user-2');
    });
  });

  group('имя из Apple', () {
    test('сохраняется до успешного ответа и используется при повторе', () async {
      final repository = createRepository(
        apple: const [
          SocialCredential(idToken: 'a1', name: 'Ivan Petrov'),
          // Второй раз Apple имя уже не отдаёт.
          SocialCredential(idToken: 'a2'),
        ],
      );

      remote.appleFailure = const NetworkFailure();
      await expectLater(
        repository.signInWithApple(),
        throwsA(isA<NetworkFailure>()),
      );
      expect(
        await PendingAppleNameStorage(const FlutterSecureStorage()).read(),
        'Ivan Petrov',
        reason: 'запрос упал — имя нельзя терять',
      );

      remote.appleFailure = null;
      await repository.signInWithApple();

      expect(remote.lastAppleName, 'Ivan Petrov');
      expect(
        await PendingAppleNameStorage(const FlutterSecureStorage()).read(),
        'Ivan Petrov',
        reason: 'вход принят, но имя ещё может понадобиться для PATCH',
      );

      // /auth/me показал, что имя на сервере есть: хранить больше нечего.
      await repository.getProfile(forceRefresh: true);
      expect(
        await PendingAppleNameStorage(const FlutterSecureStorage()).read(),
        isNull,
      );
      expect(await tokens.readRefreshToken(), 'apple-refresh');
    });

    test('без имени в запрос оно не попадает', () async {
      final repository = createRepository(
        apple: const [SocialCredential(idToken: 'a1')],
      );

      await repository.signInWithApple();

      expect(remote.appleCalled, isTrue);
      expect(remote.lastAppleName, isNull);
    });
  });

  group('учётной записи больше нет (404 на /auth/me)', () {
    test('токены очищены, о конце сессии сообщено, ошибка наружу', () async {
      await tokens.save(
        const AuthTokens(
          accessToken: 'old-access',
          refreshToken: 'old-refresh',
          userId: 'user-1',
        ),
      );
      remote.getMeFailure = const AccountNotFoundFailure();
      final repository = createRepository();

      await expectLater(
        repository.getProfile(forceRefresh: true),
        throwsA(isA<AccountNotFoundFailure>()),
      );
      await Future<void>.delayed(Duration.zero);

      expect(await tokens.readAccessToken(), isNull);
      expect(await tokens.readRefreshToken(), isNull);
      expect(sessionExpiredEvents, 1);
    });

    test('прочие ошибки профиля сессию не завершают', () async {
      await tokens.save(
        const AuthTokens(
          accessToken: 'a',
          refreshToken: 'r',
          userId: 'user-1',
        ),
      );
      remote.getMeFailure = const NetworkFailure();
      final repository = createRepository();

      await expectLater(
        repository.getProfile(forceRefresh: true),
        throwsA(isA<NetworkFailure>()),
      );
      await Future<void>.delayed(Duration.zero);

      expect(await tokens.readRefreshToken(), 'r');
      expect(sessionExpiredEvents, 0);
    });
  });

  group('выход', () {
    test('локальная сессия очищается, даже если сервер недоступен', () async {
      await tokens.save(
        const AuthTokens(
          accessToken: 'a',
          refreshToken: 'r',
          userId: 'user-1',
        ),
      );
      remote.logoutFailure = const NetworkFailure();
      final repository = createRepository();

      await repository.logout();

      expect(await tokens.readRefreshToken(), isNull);
      expect(await tokens.readAccessToken(), isNull);
    });
  });
}
