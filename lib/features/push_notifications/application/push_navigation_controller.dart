import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/boss_push_payload.dart';

class PushNavigationController extends Notifier<BossPushPayload?> {
  @override
  BossPushPayload? build() => null;

  void openSchedule(BossPushPayload payload) => state = payload;

  void clear() => state = null;
}

final pushNavigationControllerProvider =
    NotifierProvider<PushNavigationController, BossPushPayload?>(
      PushNavigationController.new,
    );
