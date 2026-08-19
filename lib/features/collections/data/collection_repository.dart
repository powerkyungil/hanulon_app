import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_paths.dart';
import '../../../core/network/api_client.dart';
import '../../auth/domain/user_role.dart';
import '../domain/collection_overview.dart';
import '../domain/item_collection.dart';

abstract interface class CollectionRepository {
  Future<CollectionOverview> fetchOverview();

  Future<void> saveCollection(CollectionInput input, {int? collectionId});

  Future<void> deleteCollection(int collectionId);

  Future<void> setCompleted({
    required int userId,
    required int itemId,
    required bool completed,
  });

  Future<bool> toggleExcluded(int userId);
}

class ApiCollectionRepository implements CollectionRepository {
  const ApiCollectionRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<CollectionOverview> fetchOverview() async {
    final responses = await Future.wait<Object>(<Future<Object>>[
      _apiClient.get<List<ItemCollection>>(
        ApiPaths.collections,
        decode: _decodeCollections,
      ),
      _apiClient.get<List<CollectionMember>>(
        ApiPaths.members,
        decode: _decodeMembers,
      ),
      _apiClient.get<Set<String>>(
        ApiPaths.collectionCompletions,
        decode: _decodeStatuses,
      ),
      _apiClient.get<Set<int>>(
        ApiPaths.collectionExclusions,
        decode: _decodeExcluded,
      ),
    ]);
    return CollectionOverview(
      collections: responses[0] as List<ItemCollection>,
      members: responses[1] as List<CollectionMember>,
      completedKeys: responses[2] as Set<String>,
      excludedMemberIds: responses[3] as Set<int>,
      synchronizedAt: DateTime.now(),
    );
  }

  @override
  Future<void> saveCollection(CollectionInput input, {int? collectionId}) {
    if (collectionId == null) {
      return _apiClient.post<void>(
        ApiPaths.collections,
        data: input.toJson(),
        decode: (_) {},
      );
    }
    return _apiClient.put<void>(
      ApiPaths.collection(collectionId),
      data: input.toJson(),
      decode: (_) {},
    );
  }

  @override
  Future<void> deleteCollection(int collectionId) {
    return _apiClient.delete<void>(
      ApiPaths.collection(collectionId),
      decode: (_) {},
    );
  }

  @override
  Future<void> setCompleted({
    required int userId,
    required int itemId,
    required bool completed,
  }) {
    return _apiClient.put<void>(
      ApiPaths.collectionCompletions,
      data: <String, dynamic>{
        'userId': userId,
        'collectionItemId': itemId,
        'completed': completed,
      },
      decode: (_) {},
    );
  }

  @override
  Future<bool> toggleExcluded(int userId) {
    return _apiClient.post<bool>(
      ApiPaths.toggleCollectionExclusion,
      data: <String, int>{'userId': userId},
      decode: (data) => _decodeMutationStatus(data) == 'added',
    );
  }

  static List<ItemCollection> _decodeCollections(Object? data) {
    return _listPayload(data, '컬렉션 응답 형식이 올바르지 않습니다.').map((value) {
      final json = _asJson(value);
      final items = json['items'];
      return ItemCollection(
        id: _int(json['id']),
        name: json['name']?.toString() ?? '이름 없음',
        items: items is List<dynamic>
            ? items.map((itemValue) {
                final item = _asJson(itemValue);
                return CollectionItem(
                  id: _int(item['id']),
                  part: item['part']?.toString() ?? '',
                  enchantment: item['enchantment']?.toString() ?? '',
                );
              }).toList()
            : const <CollectionItem>[],
      );
    }).toList();
  }

  static List<CollectionMember> _decodeMembers(Object? data) {
    final members = _listPayload(data, '길드원 응답 형식이 올바르지 않습니다.')
        .map((value) {
          final json = _asJson(value);
          return CollectionMember(
            id: _int(json['id']),
            nickname: json['nickname']?.toString() ?? '',
            combatPower: _int(_value(json, 'combatPower', 'combat_power')),
            role: UserRole.fromApi(json['role']?.toString()),
          );
        })
        .where((member) => member.nickname.trim().isNotEmpty)
        .toList();
    members.sort((a, b) => b.combatPower.compareTo(a.combatPower));
    return members;
  }

  static Set<String> _decodeStatuses(Object? data) {
    return _listPayload(data, '아이템 달성 상태 응답 형식이 올바르지 않습니다.').map((value) {
      final json = _asJson(value);
      return CollectionOverview.statusKey(
        _int(_value(json, 'userId', 'user_id')),
        _int(_value(json, 'collectionItemId', 'collection_item_id')),
      );
    }).toSet();
  }

  static Set<int> _decodeExcluded(Object? data) {
    return _listPayload(
      data,
      '제외 멤버 응답 형식이 올바르지 않습니다.',
    ).map(_int).where((id) => id > 0).toSet();
  }

  static String _decodeMutationStatus(Object? data) {
    final json = _asJson(data);
    final payload = json['data'];
    final mutation = payload is Map<String, dynamic> ? payload : json;
    final status = mutation['status']?.toString();
    if (status == 'added' || status == 'removed') return status!;
    throw const FormatException('아이템 현황 변경 응답 형식이 올바르지 않습니다.');
  }

  static List<dynamic> _listPayload(Object? data, String message) {
    if (data is List<dynamic>) return data;
    if (data is Map<String, dynamic> && data['data'] is List<dynamic>) {
      return data['data'] as List<dynamic>;
    }
    throw FormatException(message);
  }

  static Map<String, dynamic> _asJson(Object? value) {
    if (value is Map<String, dynamic>) return value;
    throw const FormatException('아이템 현황 응답 형식이 올바르지 않습니다.');
  }

  static Object? _value(
    Map<String, dynamic> json,
    String camelCaseKey,
    String legacyKey,
  ) {
    return json.containsKey(camelCaseKey)
        ? json[camelCaseKey]
        : json[legacyKey];
  }

  static int _int(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

final collectionRepositoryProvider = Provider<CollectionRepository>((ref) {
  return ApiCollectionRepository(ref.watch(apiClientProvider));
});
