import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_paths.dart';
import '../../../core/network/api_client.dart';
import '../domain/support_request.dart';

abstract interface class SupportRepository {
  Future<List<SupportRequest>> fetchRequests();

  Future<void> createRequest(SupportRequestInput input);

  Future<void> updateStatus(int requestId, SupportRequestStatus status);

  Future<void> deleteRequest(int requestId);

  Future<void> apply(int requestId, {String memo = ''});

  Future<void> cancelApplication(int requestId, int applicationId);

  Future<void> selectApplication(int requestId, int applicationId);
}

class ApiSupportRepository implements SupportRepository {
  const ApiSupportRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<SupportRequest>> fetchRequests() {
    return _apiClient.get<List<SupportRequest>>(
      ApiPaths.supportRequests,
      decode: (data) {
        final payload = _payload(data);
        if (payload is! List<dynamic>) {
          throw const FormatException('손지원 요청 목록 형식이 올바르지 않습니다.');
        }
        return payload.map(_decodeRequest).toList();
      },
    );
  }

  @override
  Future<void> createRequest(SupportRequestInput input) {
    return _apiClient.post<void>(
      ApiPaths.supportRequests,
      data: <String, String>{
        'requestedTime': input.requestedTime.trim(),
        'memo': input.memo.trim(),
      },
      decode: (_) {},
    );
  }

  @override
  Future<void> updateStatus(int requestId, SupportRequestStatus status) {
    return _apiClient.put<void>(
      ApiPaths.supportRequestStatus(requestId),
      data: <String, String>{'status': status.apiValue},
      decode: (_) {},
    );
  }

  @override
  Future<void> deleteRequest(int requestId) {
    return _apiClient.delete<void>(
      ApiPaths.supportRequest(requestId),
      decode: (_) {},
    );
  }

  @override
  Future<void> apply(int requestId, {String memo = ''}) {
    return _apiClient.post<void>(
      ApiPaths.supportApplications(requestId),
      data: <String, String>{'memo': memo.trim()},
      decode: (_) {},
    );
  }

  @override
  Future<void> cancelApplication(int requestId, int applicationId) {
    return _apiClient.delete<void>(
      ApiPaths.supportApplication(requestId, applicationId),
      decode: (_) {},
    );
  }

  @override
  Future<void> selectApplication(int requestId, int applicationId) {
    return _apiClient.post<void>(
      ApiPaths.selectSupportApplication(requestId, applicationId),
      decode: (_) {},
    );
  }

  static SupportRequest _decodeRequest(Object? data) {
    if (data is! Map<String, dynamic>) {
      throw const FormatException('손지원 요청 항목 형식이 올바르지 않습니다.');
    }
    final rawApplications = data['applications'];
    final applications = rawApplications is List<dynamic>
        ? rawApplications.map(_decodeApplication).toList()
        : const <SupportApplication>[];
    return SupportRequest(
      id: _int(data['id']),
      requesterId: _int(data['requesterId'] ?? data['requester_id']),
      requestedTime:
          (data['requestedTime'] ?? data['requested_time'])?.toString() ?? '',
      memo: data['memo']?.toString() ?? '',
      status: SupportRequestStatus.fromApi(data['status']),
      selectedApplicationId: _nullableInt(
        data['selectedApplicationId'] ?? data['selected_application_id'],
      ),
      createdAt: _date(data['createdAt'] ?? data['created_at']),
      updatedAt: _date(data['updatedAt'] ?? data['updated_at']),
      nickname: data['nickname']?.toString() ?? '',
      occupation: data['occupation']?.toString() ?? '',
      mainClass: (data['mainClass'] ?? data['main_class'])?.toString() ?? '',
      combatPower: _int(data['combatPower'] ?? data['combat_power']),
      applications: applications,
    );
  }

  static SupportApplication _decodeApplication(Object? data) {
    if (data is! Map<String, dynamic>) {
      throw const FormatException('손지원 신청 항목 형식이 올바르지 않습니다.');
    }
    return SupportApplication(
      id: _int(data['id']),
      requestId: _int(data['requestId'] ?? data['request_id']),
      applicantId: _int(data['applicantId'] ?? data['applicant_id']),
      memo: data['memo']?.toString() ?? '',
      status: SupportApplicationStatus.fromApi(data['status']),
      createdAt: _date(data['createdAt'] ?? data['created_at']),
      nickname: data['nickname']?.toString() ?? '',
      occupation: data['occupation']?.toString() ?? '',
      mainClass: (data['mainClass'] ?? data['main_class'])?.toString() ?? '',
      combatPower: _int(data['combatPower'] ?? data['combat_power']),
    );
  }

  static int _int(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _nullableInt(Object? value) {
    if (value == null || value.toString().trim().isEmpty) return null;
    return _int(value);
  }

  static DateTime? _date(Object? value) {
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        value.toInt(),
        isUtc: true,
      ).toLocal();
    }
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    final normalized = raw.contains('T') ? raw : raw.replaceFirst(' ', 'T');
    final hasTimeZone =
        normalized.endsWith('Z') ||
        RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(normalized);
    return DateTime.tryParse(
      hasTimeZone ? normalized : '${normalized}Z',
    )?.toLocal();
  }

  static Object? _payload(Object? data) {
    if (data case final Map<String, dynamic> json
        when json.containsKey('data')) {
      return json['data'];
    }
    return data;
  }
}

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return ApiSupportRepository(ref.watch(apiClientProvider));
});
