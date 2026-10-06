import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/deputy_auth_repository.dart';
import '../domain/deputy_account.dart';

class DeputyAccountController extends AsyncNotifier<List<DeputyAccount>> {
  @override
  Future<List<DeputyAccount>> build() {
    return ref.read(deputyAuthRepositoryProvider).fetchAccounts();
  }

  Future<void> refreshAccounts() async {
    state = await AsyncValue.guard(
      ref.read(deputyAuthRepositoryProvider).fetchAccounts,
    );
  }

  Future<void> createAccount({
    required String username,
    required String password,
    required String nickname,
  }) async {
    await ref
        .read(deputyAuthRepositoryProvider)
        .createAccount(
          username: username,
          password: password,
          nickname: nickname,
        );
    await refreshAccounts();
  }

  Future<void> resetPassword(int accountId, String password) async {
    await ref
        .read(deputyAuthRepositoryProvider)
        .resetPassword(accountId, password);
    await refreshAccounts();
  }

  Future<void> setActive(int accountId, bool isActive) async {
    await ref.read(deputyAuthRepositoryProvider).setActive(accountId, isActive);
    await refreshAccounts();
  }
}

final deputyAccountControllerProvider =
    AsyncNotifierProvider<DeputyAccountController, List<DeputyAccount>>(
      DeputyAccountController.new,
    );
