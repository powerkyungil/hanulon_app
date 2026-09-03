import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_paths.dart';
import '../../../core/network/api_client.dart';

abstract interface class PushTokenRepository {
  Future<void> register({required String token, required String deviceId});

  Future<void> delete({required String token});
}

class ApiPushTokenRepository implements PushTokenRepository {
  const ApiPushTokenRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<void> register({required String token, required String deviceId}) {
    return _apiClient.put<void>(
      ApiPaths.pushTokens,
      data: <String, String>{
        'token': token,
        'platform': 'ANDROID',
        'deviceId': deviceId,
      },
      decode: (_) {},
    );
  }

  @override
  Future<void> delete({required String token}) {
    return _apiClient.delete<void>(
      ApiPaths.pushTokens,
      data: <String, String>{'token': token},
      decode: (_) {},
    );
  }
}

final pushTokenRepositoryProvider = Provider<PushTokenRepository>(
  (ref) => ApiPushTokenRepository(ref.watch(apiClientProvider)),
);
