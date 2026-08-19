import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_paths.dart';
import '../../../core/network/api_client.dart';
import '../domain/content_group.dart';

abstract interface class ContentGroupRepository {
  Future<List<ContentGroup>> fetchGroups();

  Future<ContentGroup> createGroup(String name);

  Future<void> renameGroup(int groupId, String name);

  Future<void> deleteGroup(int groupId);

  Future<void> saveMembers(int groupId, List<int> memberIds);
}

class ApiContentGroupRepository implements ContentGroupRepository {
  const ApiContentGroupRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<ContentGroup>> fetchGroups() {
    return _apiClient.get<List<ContentGroup>>(
      ApiPaths.contentGroups,
      decode: (data) {
        return _listPayload(
          data,
          '콘텐츠 그룹 응답 형식이 올바르지 않습니다.',
        ).map(_decodeGroup).toList();
      },
    );
  }

  @override
  Future<ContentGroup> createGroup(String name) {
    return _apiClient.post<ContentGroup>(
      ApiPaths.contentGroups,
      data: <String, String>{'name': name.trim()},
      decode: (data) => _decodeEnvelopeGroup(data, fallbackName: name.trim()),
    );
  }

  @override
  Future<void> renameGroup(int groupId, String name) {
    return _apiClient.put<void>(
      ApiPaths.contentGroup(groupId),
      data: <String, String>{'name': name.trim()},
      decode: (_) {},
    );
  }

  @override
  Future<void> deleteGroup(int groupId) {
    return _apiClient.delete<void>(
      ApiPaths.contentGroup(groupId),
      decode: (_) {},
    );
  }

  @override
  Future<void> saveMembers(int groupId, List<int> memberIds) {
    return _apiClient.put<void>(
      ApiPaths.contentGroupMembers(groupId),
      data: <String, List<int>>{'userIds': memberIds},
      decode: (_) {},
    );
  }

  static ContentGroup _decodeGroup(Object? data, {String fallbackName = ''}) {
    if (data is! Map<String, dynamic>) {
      throw const FormatException('콘텐츠 그룹 항목 형식이 올바르지 않습니다.');
    }
    return ContentGroup(
      id: _int(data['id']),
      name: data['name']?.toString().trim().isNotEmpty == true
          ? data['name'].toString().trim()
          : fallbackName,
      memberIds: _memberIds(data['memberIds'] ?? data['member_ids']),
    );
  }

  static ContentGroup _decodeEnvelopeGroup(
    Object? data, {
    String fallbackName = '',
  }) {
    if (data is Map<String, dynamic> && data['data'] != null) {
      return _decodeGroup(data['data'], fallbackName: fallbackName);
    }
    return _decodeGroup(data, fallbackName: fallbackName);
  }

  static List<dynamic> _listPayload(Object? data, String message) {
    if (data is List<dynamic>) return data;
    if (data is Map<String, dynamic> && data['data'] is List<dynamic>) {
      return data['data'] as List<dynamic>;
    }
    throw FormatException(message);
  }

  static List<int> _memberIds(Object? value) {
    if (value is List<dynamic>) {
      return value.map(_int).where((id) => id > 0).toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      return value.split(',').map(_int).where((id) => id > 0).toList();
    }
    return const <int>[];
  }

  static int _int(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

final contentGroupRepositoryProvider = Provider<ContentGroupRepository>((ref) {
  return ApiContentGroupRepository(ref.watch(apiClientProvider));
});
