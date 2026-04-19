import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/inventory_repository.dart';
import '../data/models/inventory_item.dart';

/// Filter + search state. Held at app scope so swiping between tabs
/// preserves the merchant's current filter.
class InventoryFilterState {
  const InventoryFilterState({
    this.filter = const InventoryFilter(),
    this.search = '',
  });

  final InventoryFilter filter;
  final String search;

  InventoryFilterState copyWith({InventoryFilter? filter, String? search}) {
    return InventoryFilterState(
      filter: filter ?? this.filter,
      search: search ?? this.search,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is InventoryFilterState &&
      other.filter == filter &&
      other.search == search;

  @override
  int get hashCode => Object.hash(filter, search);
}

class InventoryFilterController extends Notifier<InventoryFilterState> {
  @override
  InventoryFilterState build() => const InventoryFilterState();

  void setCategory(String? category) {
    state = state.copyWith(
      filter: state.filter.copyWith(
        category: category,
        clearCategory: category == null,
      ),
    );
  }

  void setColor(String? color) {
    state = state.copyWith(
      filter: state.filter.copyWith(color: color, clearColor: color == null),
    );
  }

  void setLowStockOnly(bool value) {
    state = state.copyWith(filter: state.filter.copyWith(lowStockOnly: value));
  }

  void setSearch(String value) {
    state = state.copyWith(search: value);
  }

  void clearAll() {
    state = const InventoryFilterState();
  }
}

final inventoryFilterControllerProvider =
    NotifierProvider<InventoryFilterController, InventoryFilterState>(
      InventoryFilterController.new,
    );

/// Pagination-aware list state: accumulates pages as the user scrolls.
class InventoryListState {
  const InventoryListState({
    required this.items,
    required this.hasMore,
    required this.lastDoc,
    this.isLoadingMore = false,
  });

  final List<InventoryItem> items;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool isLoadingMore;

  InventoryListState copyWith({
    List<InventoryItem>? items,
    bool? hasMore,
    DocumentSnapshot<Map<String, dynamic>>? lastDoc,
    bool? isLoadingMore,
  }) {
    return InventoryListState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      lastDoc: lastDoc ?? this.lastDoc,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class InventoryListController extends AsyncNotifier<InventoryListState> {
  @override
  Future<InventoryListState> build() async {
    // Rebuild whenever the filter changes (search is applied client-side
    // on the already-loaded page, so it does NOT re-trigger a query).
    final filter = ref.watch(
      inventoryFilterControllerProvider.select((s) => s.filter),
    );
    final repo = ref.watch(inventoryRepositoryProvider);
    final page = await repo.fetchPage(filter: filter);
    return InventoryListState(
      items: page.items,
      hasMore: page.hasMore,
      lastDoc: page.lastDoc,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final filter = ref.read(inventoryFilterControllerProvider).filter;
      final repo = ref.read(inventoryRepositoryProvider);
      final page = await repo.fetchPage(
        filter: filter,
        startAfter: current.lastDoc,
      );
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...page.items],
          hasMore: page.hasMore,
          lastDoc: page.lastDoc ?? current.lastDoc,
          isLoadingMore: false,
        ),
      );
    } on Object catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final filter = ref.read(inventoryFilterControllerProvider).filter;
      final repo = ref.read(inventoryRepositoryProvider);
      final page = await repo.fetchPage(filter: filter);
      return InventoryListState(
        items: page.items,
        hasMore: page.hasMore,
        lastDoc: page.lastDoc,
      );
    });
  }
}

final inventoryListControllerProvider =
    AsyncNotifierProvider<InventoryListController, InventoryListState>(
      InventoryListController.new,
    );

/// Search-applied view derived from the loaded page. Search is narrow
/// and case-insensitive; full-text across the whole catalogue is a
/// later-sprint concern (Algolia / Typesense).
final visibleInventoryItemsProvider = Provider<List<InventoryItem>>((ref) {
  final list = ref.watch(inventoryListControllerProvider).value;
  final search = ref
      .watch(inventoryFilterControllerProvider)
      .search
      .trim()
      .toLowerCase();
  if (list == null) return const [];
  if (search.isEmpty) return list.items;
  return list.items
      .where((it) => it.name.toLowerCase().contains(search))
      .toList();
});

/// One-shot mutation controller: create / update / delete. Returns
/// [AsyncValue] so screens can bind button states without setState.
class InventoryMutationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Creates or updates an inventory item.
  ///
  ///  - [itemId] == null               → Firestore auto-generates an ID
  ///                                      (kept for callers that don't
  ///                                      care about the ID up-front).
  ///  - [itemId] != null && [isNew]    → write at the caller-supplied
  ///                                      ID via `doc(id).set(...)`. Safe
  ///                                      to retry — the second attempt
  ///                                      overwrites the first instead
  ///                                      of creating a duplicate.
  ///  - [itemId] != null && ![isNew]   → update the existing document.
  Future<String> save({
    required InventoryItem draft,
    String? itemId,
    bool isNew = false,
  }) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final String id;
      if (itemId == null) {
        id = await repo.create(draft);
      } else if (isNew) {
        await repo.createWithId(itemId, draft);
        id = itemId;
      } else {
        await repo.update(draft);
        id = itemId;
      }
      ref.invalidate(inventoryListControllerProvider);
      state = const AsyncData(null);
      return id;
    } on Object catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> delete(String itemId) async {
    state = const AsyncLoading();
    try {
      await ref.read(inventoryRepositoryProvider).delete(itemId);
      ref.invalidate(inventoryListControllerProvider);
      state = const AsyncData(null);
    } on Object catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final inventoryMutationControllerProvider =
    AsyncNotifierProvider<InventoryMutationController, void>(
      InventoryMutationController.new,
    );
