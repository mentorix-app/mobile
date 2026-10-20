import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/config/api_endpoints.dart';
import 'package:mentorix_app/core/network/session_expired_notifier.dart';
import 'package:mentorix_app/core/storage/token_storage.dart';
import 'package:mentorix_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:mentorix_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mentorix_app/features/auth/data/storage/pending_apple_name_storage.dart';
import 'package:mentorix_app/features/auth/domain/entities/social_credential.dart';
import 'package:mentorix_app/features/auth/domain/providers/social_auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_http_adapter.dart';
import '../../helpers/talker_capture.dart';

class _NoProvider implements SocialAuthProvider {
  @override
  bool get isAvailable => true;

  @override
  Future<SocialCredential> signIn() async =>
      throw UnimplementedError('не нужен в этом тесте');

  @override
  Future<void> disconnect() async {}
}

/// Токен приглашения чувствителен к регистру: в тело запроса он уходит без
/// изменений, обрезаются только пробелы и переносы по краям.
void main() {
  late FakeHttpAdapter adapter;
  late AuthRepositoryImpl repository;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    resetTalker();

    adapter = FakeHttpAdapter(
      (options) async => jsonBody({
        'trainer_id': 't1',
        'trainer_display_name': 'Trainer',
        'already_linked': false,
      }),
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;

    repository = AuthRepositoryImpl(
      remote: AuthRemoteDataSource(apiDio: dio),
      tokens: TokenStorage(const FlutterSecureStorage(), prefs),
      sessionExpired: SessionExpiredNotifier(),
      pendingAppleName: PendingAppleNameStorage(const FlutterSecureStorage()),
      google: _NoProvider(),
      apple: _NoProvider(),
    );
  });

  Object? sentToken() =>
      (adapter.requestsTo(ApiEndpoints.clientInviteAccept).single.data
          as Map<String, Object?>)['token'];

  test('смешанный регистр уходит в тело без изменений', () async {
    const link = 'https://t.me/mentorix_dev_bot?start=inv_doZWkvlx3';

    await repository.acceptInvite(link);

    expect(sentToken(), link);
  });

  test('токен без обёртки тоже не меняет регистр', () async {
    await repository.acceptInvite('inv_doZWkvlx3');

    expect(sentToken(), 'inv_doZWkvlx3');
  });

  test('пробелы и переносы по краям обрезаются, внутри — нет', () async {
    await repository.acceptInvite('  \n\tinv_doZWkvlx3 \r\n ');

    expect(sentToken(), 'inv_doZWkvlx3');
  });

  test('в лог пишутся длина и первые 4 символа, но не токен', () async {
    const link = 'https://t.me/mentorix_dev_bot?start=inv_doZWkvlx3';

    await repository.acceptInvite(' $link\n');

    final messages = loggedMessages();
    expect(
      messages,
      contains('[mentorix.invite] invite input len=${link.length} start=http'),
    );
    expect(messages.join('\n'), isNot(contains('doZWkvlx3')));
  });

  test('короткая строка в логе не роняет подсказку', () async {
    await repository.acceptInvite('ab');

    expect(
      loggedMessages(),
      contains('[mentorix.invite] invite input len=2 start=ab'),
    );
  });
}
