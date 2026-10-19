import 'package:mentorix_app/core/logging/debug_log.dart';
import 'package:mentorix_app/core/network/session_expired_notifier.dart';
import 'package:mentorix_app/core/storage/token_storage.dart';
import 'package:mentorix_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:mentorix_app/features/auth/data/models/apple_deletion_proof.dart';
import 'package:mentorix_app/features/auth/data/storage/pending_apple_name_storage.dart';
import 'package:mentorix_app/features/auth/domain/entities/invite_acceptance.dart';
import 'package:mentorix_app/features/auth/domain/entities/linked_trainer.dart';
import 'package:mentorix_app/features/auth/domain/entities/user_profile.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';
import 'package:mentorix_app/features/auth/domain/providers/social_auth_provider.dart';
import 'package:mentorix_app/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required TokenStorage tokens,
    required SessionExpiredNotifier sessionExpired,
    required PendingAppleNameStorage pendingAppleName,
    required SocialAuthProvider google,
    required SocialAuthProvider apple,
  }) : _remote = remote,
       _tokens = tokens,
       _sessionExpired = sessionExpired,
       _pendingAppleName = pendingAppleName,
       _google = google,
       _apple = apple;

  final AuthRemoteDataSource _remote;
  final TokenStorage _tokens;
  final SessionExpiredNotifier _sessionExpired;
  final PendingAppleNameStorage _pendingAppleName;
  final SocialAuthProvider _google;
  final SocialAuthProvider _apple;

  UserProfile? _cachedProfile;

  /// Задан после входа через Apple и снимается первым успешным `GET /auth/me`.
  /// `name` — имя, известное Apple (из этого входа или сохранённое после
  /// неудачной попытки): если на сервере имя пустое, его нужно записать
  /// через `PATCH /auth/me`.
  ({String? name})? _appleNameFollowUp;

  /// `PATCH /auth/me`: имя длиннее — 400.
  static const _maxNameLength = 100;

  @override
  bool get isGoogleSignInAvailable => _google.isAvailable;

  @override
  bool get isAppleSignInAvailable => _apple.isAvailable;

  @override
  Future<bool> restoreSession() async {
    await _tokens.ensureFreshInstall();
    return _tokens.hasSession();
  }

  @override
  Future<void> signInWithGoogle() async {
    final credential = await _google.signIn();
    final tokens = await _remote.signInWithGoogle(credential.idToken);

    await _tokens.save(tokens);
    _cachedProfile = null;
  }

  @override
  Future<void> signInWithApple() async {
    final credential = await _apple.signIn();

    // Имя приходит только в первый раз: сначала сохраняем, а убираем — только
    // после ответа бэкенда. Повторная попытка возьмёт его из хранилища.
    final freshName = credential.name;
    if (freshName != null) await _pendingAppleName.save(freshName);
    final pendingName = freshName == null
        ? await _pendingAppleName.read()
        : null;
    final name = freshName ?? pendingName;

    final tokens = await _remote.signInWithApple(
      credential.idToken,
      name: name,
    );

    await _tokens.save(tokens);
    _cachedProfile = null;

    // Бэкенд берёт `name` только при создании записи. Если запись уже была и
    // имя в ней пустое, /auth/me это покажет, и имя уйдёт через PATCH. Поэтому
    // из хранилища имя убирается там же, а не здесь.
    _appleNameFollowUp = (name: name);
  }

  @override
  Future<UserProfile> getProfile({bool forceRefresh = false}) async {
    final cached = _cachedProfile;
    if (!forceRefresh && cached != null) return cached;

    final fetched = await _endSessionIfAccountGone(_remote.getMe);
    final profile = await _applyAppleNameFallback(fetched);
    _cachedProfile = profile;
    return profile;
  }

  /// После входа через Apple: если имя в профиле пустое, а Apple имя дала,
  /// записывает его через `PATCH /auth/me` и перечитывает профиль.
  ///
  /// Существующее имя не перезаписывается. Сбой PATCH вход не ломает: имя
  /// остаётся в [PendingAppleNameStorage] до следующей попытки входа. Выполняется
  /// один раз за вход.
  Future<UserProfile> _applyAppleNameFallback(UserProfile profile) async {
    final followUp = _appleNameFollowUp;
    if (followUp == null) return profile;
    _appleNameFollowUp = null;

    final name = followUp.name;

    if (profile.name.isNotEmpty) {
      if (name != null) {
        _nameFallbackTrace('skipped (server has name)');
        await _pendingAppleName.clear();
      }
      return profile;
    }

    if (name == null) {
      _nameFallbackTrace('skipped (no name from Apple)');
      return profile;
    }

    final limited = name.runes.length > _maxNameLength
        ? String.fromCharCodes(name.runes.take(_maxNameLength))
        : name;

    try {
      await _remote.updateName(limited);
    } on AuthFailure catch (failure) {
      // Вход состоялся: пользователь входит с пустым именем, имя ждёт
      // следующей попытки в хранилище.
      _nameFallbackTrace(
        'failed (${failure.runtimeType}'
        '${failure.details != null ? ' ${failure.details!.summary}' : ''})',
      );
      return profile;
    }

    _nameFallbackTrace('PATCH sent');
    await _pendingAppleName.clear();

    try {
      return await _remote.getMe();
    } on AuthFailure {
      // Имя записано, профиль перечитать не вышло — показываем с именем.
      return UserProfile(
        userId: profile.userId,
        email: profile.email,
        name: limited,
        telegramLinked: profile.telegramLinked,
        createdAt: profile.createdAt,
        roles: profile.roles,
      );
    }
  }

  @override
  Future<UserProfile> updateName(String name) async {
    await _endSessionIfAccountGone(() => _remote.updateName(name));
    // Тело ответа PATCH в контракте не описано — берём актуальный профиль.
    return getProfile(forceRefresh: true);
  }

  @override
  Future<List<LinkedTrainer>> getTrainers() =>
      _endSessionIfAccountGone(_remote.getTrainers);

  @override
  Future<void> linkTelegram(String code) async {
    final tokens = await _remote.linkTelegram(code.trim());

    // Заменяем оба токена: старые уже недействительны, а user_id мог поменяться.
    await _tokens.save(tokens);
    _cachedProfile = null;
  }

  @override
  Future<InviteAcceptance> acceptInvite(String tokenOrLink) {
    return _remote.acceptInvite(tokenOrLink.trim());
  }

  @override
  Future<void> deleteAccount({bool confirmWithApple = false}) async {
    try {
      if (confirmWithApple) {
        await _deleteWithApple();
      } else {
        try {
          await _remote.deleteAccount();
        } on AppleAuthorizationRequiredFailure {
          await _deleteWithApple();
        }
      }
    } on AccountNotFoundFailure {
      // `user_not_found`: аккаунт уже удалён — для пользователя это успех.
      _trace('404 user_not_found: account already deleted, treated as success');
    }

    await clearLocalSession();
    await _pendingAppleName.clear();
    await _google.disconnect();
  }

  void _trace(String step) => DebugLog.write('mentorix.delete', step);

  void _nameFallbackTrace(String result) =>
      DebugLog.write('mentorix.apple', 'name fallback: $result');

  /// Окно Apple показывается здесь, а не заранее: `authorization_code`
  /// одноразовый и живёт 5 минут, поэтому берётся прямо перед запросом.
  Future<void> _deleteWithApple() async {
    final credential = await _apple.signIn();

    final code = credential.authorizationCode;
    if (code == null) throw const SocialSignInUnavailableFailure();

    await _remote.deleteAccount(
      apple: AppleDeletionProof(
        idToken: credential.idToken,
        authorizationCode: code,
        redirectUri: credential.webRedirectUri,
      ),
    );
  }

  @override
  Future<void> logout() async {
    try {
      final refreshToken = await _tokens.readRefreshToken();
      if (refreshToken != null) await _remote.logout(refreshToken);
    } on AuthFailure {
      // Сервер недоступен — локально выходим всё равно.
    } finally {
      await clearLocalSession();
    }
  }

  @override
  Future<void> logoutAll() async {
    try {
      await _remote.logoutAll();
    } on AuthFailure {
      // см. logout
    } finally {
      await clearLocalSession();
    }
  }

  /// `user_not_found` на запросах профиля и тренеров — учётной записи больше
  /// нет (после переноса на старую запись прежние токены отвечают именно так, а
  /// не 401). Это конец сессии, как при 401 на refresh: токены очищаются,
  /// `SessionCubit` уводит на вход.
  Future<T> _endSessionIfAccountGone<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AccountNotFoundFailure {
      await clearLocalSession();
      _sessionExpired.notify();
      rethrow;
    }
  }

  @override
  Future<void> clearLocalSession() async {
    _cachedProfile = null;
    await _tokens.clear();
  }
}
