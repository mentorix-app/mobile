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
    final name = freshName ?? await _pendingAppleName.read();

    final tokens = await _remote.signInWithApple(
      credential.idToken,
      name: name,
    );

    await _tokens.save(tokens);
    await _pendingAppleName.clear();
    _cachedProfile = null;
  }

  @override
  Future<UserProfile> getProfile({bool forceRefresh = false}) async {
    final cached = _cachedProfile;
    if (!forceRefresh && cached != null) return cached;

    final profile = await _endSessionIfAccountGone(_remote.getMe);
    _cachedProfile = profile;
    return profile;
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
    }

    await clearLocalSession();
    await _pendingAppleName.clear();
    await _google.disconnect();
  }

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
