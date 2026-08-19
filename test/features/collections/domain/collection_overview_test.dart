import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/features/auth/domain/user_role.dart';
import 'package:odin_guild_app/features/collections/domain/collection_overview.dart';
import 'package:odin_guild_app/features/collections/domain/item_collection.dart';

void main() {
  test('미달성자 중 전투력이 높은 일반 대상자를 아이템 1순위로 계산한다', () {
    final overview = _overview(
      completedKeys: <String>{CollectionOverview.statusKey(1, 10)},
      excludedIds: <int>{2},
    );

    final priority = overview.priorityFor(10);

    expect(priority?.member.id, 3);
    expect(priority?.isExcluded, isFalse);
  });

  test('일반 대상자가 모두 달성하면 제외 길드원을 후순위로 계산한다', () {
    final overview = _overview(
      completedKeys: <String>{
        CollectionOverview.statusKey(1, 10),
        CollectionOverview.statusKey(3, 10),
      },
      excludedIds: <int>{2},
    );

    final priority = overview.priorityFor(10);

    expect(priority?.member.id, 2);
    expect(priority?.isExcluded, isTrue);
  });

  test('사용자별 컬렉션 달성률을 계산한다', () {
    final overview = _overview(
      completedKeys: <String>{CollectionOverview.statusKey(1, 10)},
      excludedIds: <int>{},
    );

    expect(overview.completedCount(1), 1);
    expect(overview.completionPercent(1), 50);
  });
}

CollectionOverview _overview({
  required Set<String> completedKeys,
  required Set<int> excludedIds,
}) {
  return CollectionOverview(
    collections: const <ItemCollection>[
      ItemCollection(
        id: 1,
        name: '전설 방어구',
        items: <CollectionItem>[
          CollectionItem(id: 10, part: '갑옷', enchantment: '강화 7'),
          CollectionItem(id: 11, part: '투구', enchantment: '강화 6'),
        ],
      ),
    ],
    members: const <CollectionMember>[
      CollectionMember(
        id: 1,
        nickname: '프레이야',
        combatPower: 150000,
        role: UserRole.master,
      ),
      CollectionMember(
        id: 2,
        nickname: '토르',
        combatPower: 140000,
        role: UserRole.admin,
      ),
      CollectionMember(
        id: 3,
        nickname: '로키',
        combatPower: 130000,
        role: UserRole.member,
      ),
    ],
    completedKeys: completedKeys,
    excludedMemberIds: excludedIds,
    synchronizedAt: DateTime(2026, 8, 11),
  );
}
