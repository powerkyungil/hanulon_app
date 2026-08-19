import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/core/time/server_clock.dart';

void main() {
  test('서버 시각과 로컬 시각의 offset을 적용한다', () {
    final clock = ServerClock();
    final local = DateTime.fromMillisecondsSinceEpoch(1_000);

    clock.synchronize(serverEpochMilliseconds: 6_000, localNow: local);

    expect(clock.offset, const Duration(seconds: 5));
    expect(clock.now(localNow: local).millisecondsSinceEpoch, 6_000);
  });
}
