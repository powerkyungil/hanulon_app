import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/core/config/env.dart';

void main() {
  test('API 주소를 주입하지 않으면 HTTPS 운영 서버를 사용한다', () {
    expect(AppEnvironment.apiBaseUrl, 'https://api.hanul-on.cloud');
  });
}
