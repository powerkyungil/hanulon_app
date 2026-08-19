import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/support_repository.dart';
import '../domain/support_request.dart';

class SupportController extends AsyncNotifier<SupportOverview> {
  @override
  Future<SupportOverview> build() => _fetchOverview();

  Future<SupportOverview> _fetchOverview() async {
    final requests = await ref.read(supportRepositoryProvider).fetchRequests();
    return SupportOverview(requests: requests, synchronizedAt: DateTime.now());
  }

  Future<void> refreshOverview() async {
    state = AsyncData(await _fetchOverview());
  }

  Future<void> createRequest(SupportRequestInput input) async {
    final validation = input.validationMessage;
    if (validation != null) throw SupportValidationException(validation);
    await ref.read(supportRepositoryProvider).createRequest(input);
    await refreshOverview();
  }

  Future<void> updateStatus(int requestId, SupportRequestStatus status) async {
    await ref.read(supportRepositoryProvider).updateStatus(requestId, status);
    await refreshOverview();
  }

  Future<void> deleteRequest(int requestId) async {
    await ref.read(supportRepositoryProvider).deleteRequest(requestId);
    await refreshOverview();
  }

  Future<void> apply(int requestId) async {
    await ref.read(supportRepositoryProvider).apply(requestId);
    await refreshOverview();
  }

  Future<void> cancelApplication(int requestId, int applicationId) async {
    await ref
        .read(supportRepositoryProvider)
        .cancelApplication(requestId, applicationId);
    await refreshOverview();
  }

  Future<void> selectApplication(int requestId, int applicationId) async {
    await ref
        .read(supportRepositoryProvider)
        .selectApplication(requestId, applicationId);
    await refreshOverview();
  }
}

class SupportValidationException implements Exception {
  const SupportValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

final supportOverviewProvider =
    AsyncNotifierProvider<SupportController, SupportOverview>(
      SupportController.new,
    );
