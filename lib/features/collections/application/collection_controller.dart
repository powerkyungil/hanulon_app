import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/collection_repository.dart';
import '../domain/collection_overview.dart';
import '../domain/item_collection.dart';

class CollectionController extends AsyncNotifier<CollectionOverview> {
  @override
  Future<CollectionOverview> build() {
    return ref.read(collectionRepositoryProvider).fetchOverview();
  }

  Future<void> refreshOverview() async {
    state = AsyncData(
      await ref.read(collectionRepositoryProvider).fetchOverview(),
    );
  }

  Future<void> toggleCompleted({
    required int userId,
    required int itemId,
  }) async {
    final current = state.value;
    if (current == null) return;
    final completed = !current.isCompleted(userId, itemId);
    state = AsyncData(
      current.withCompletion(
        userId: userId,
        itemId: itemId,
        completed: completed,
      ),
    );
    try {
      await ref
          .read(collectionRepositoryProvider)
          .setCompleted(userId: userId, itemId: itemId, completed: completed);
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> saveCollection(
    CollectionInput input, {
    int? collectionId,
  }) async {
    await ref
        .read(collectionRepositoryProvider)
        .saveCollection(input, collectionId: collectionId);
    await refreshOverview();
  }

  Future<void> deleteCollection(int collectionId) async {
    await ref.read(collectionRepositoryProvider).deleteCollection(collectionId);
    await refreshOverview();
  }

  Future<void> toggleExcluded(int userId) async {
    final current = state.value;
    if (current == null) return;
    final expected = !current.excludedMemberIds.contains(userId);
    state = AsyncData(current.withExcluded(userId, expected));
    try {
      final excluded = await ref
          .read(collectionRepositoryProvider)
          .toggleExcluded(userId);
      final latest = state.value;
      if (latest != null && excluded != expected) {
        state = AsyncData(latest.withExcluded(userId, excluded));
      }
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }
}

final collectionOverviewProvider =
    AsyncNotifierProvider<CollectionController, CollectionOverview>(
      CollectionController.new,
    );
