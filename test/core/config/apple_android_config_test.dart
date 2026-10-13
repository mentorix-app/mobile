import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/config/api_endpoints.dart';
import 'package:mentorix_app/core/config/social_auth_config.dart';

/// Веб-поток Apple на Android: значения для `webAuthenticationOptions` берутся
/// из `config/stage.json`, а возврат в приложение ловит активити из манифеста.
void main() {
  late Map<String, dynamic> stage;
  late String manifest;

  setUpAll(() {
    stage =
        jsonDecode(File('config/stage.json').readAsStringSync())
            as Map<String, dynamic>;
    manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
  });

  test('stage.json: Services ID и redirect URI из ответа бэкенда', () {
    expect(stage['APPLE_SERVICE_ID'], 'com.mentorix.mobile.signin');
    expect(
      stage['APPLE_REDIRECT_URI'],
      '${stage['API_BASE_URL']}${ApiEndpoints.authAppleCallback}',
    );
  });

  test('Services ID — не bundle id приложения', () {
    // Совпадение с bundle id означало бы, что веб-поток идёт с идентификатором
    // приложения, а не с Services ID.
    expect(stage['APPLE_SERVICE_ID'], isNot('com.mentorix.mobile'));
    expect(stage['APPLE_SERVICE_ID'], startsWith('com.mentorix.mobile.'));
  });

  test('плейсхолдеры отличаются от реальных значений', () {
    expect(
      SocialAuthConfig.isRealClientId(
        stage['APPLE_SERVICE_ID'] as String,
        SocialAuthConfig.appleServiceIdPlaceholder,
      ),
      isTrue,
    );
    expect(
      SocialAuthConfig.isRealClientId(
        SocialAuthConfig.appleRedirectUriPlaceholder,
        SocialAuthConfig.appleRedirectUriPlaceholder,
      ),
      isFalse,
    );
  });

  test('AndroidManifest: SignInWithAppleCallback со схемой signinwithapple', () {
    final activity = RegExp(
      r'<activity\s+android:name="com\.aboutyou\.dart_packages\.'
      r'sign_in_with_apple\.SignInWithAppleCallback"(.*?)</activity>',
      dotAll: true,
    ).firstMatch(manifest);

    expect(activity, isNotNull, reason: 'нет активити SignInWithAppleCallback');
    final body = activity!.group(1)!;
    expect(body, contains('android:exported="true"'));
    expect(body, contains('android.intent.action.VIEW'));
    expect(body, contains('android.intent.category.BROWSABLE'));
    expect(body, contains('android:scheme="signinwithapple"'));
    expect(body, contains('android:path="callback"'));
  });
}
