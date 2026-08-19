import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/siege_repository.dart';
import '../domain/siege_record.dart';

class SiegeController extends AsyncNotifier<SiegeOverview> {
  @override
  Future<SiegeOverview> build() => _fetchOverview();

  Future<SiegeOverview> _fetchOverview() async {
    final records = await ref.read(siegeRepositoryProvider).fetchRecords();
    return SiegeOverview(records: records, synchronizedAt: DateTime.now());
  }

  Future<void> refreshOverview() async {
    state = AsyncData(await _fetchOverview());
  }

  Future<void> saveMine(SiegeInput input) async {
    _validate(input);
    await ref.read(siegeRepositoryProvider).saveMine(input);
    await refreshOverview();
  }

  Future<void> saveMember(int userId, SiegeInput input) async {
    _validate(input);
    await ref.read(siegeRepositoryProvider).saveMember(userId, input);
    await refreshOverview();
  }

  Future<void> resetAll() async {
    await ref.read(siegeRepositoryProvider).resetAll();
    await refreshOverview();
  }

  static void _validate(SiegeInput input) {
    final message = input.validationMessage;
    if (message != null) throw SiegeValidationException(message);
  }
}

class SiegeValidationException implements Exception {
  const SiegeValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

final siegeOverviewProvider =
    AsyncNotifierProvider<SiegeController, SiegeOverview>(SiegeController.new);
