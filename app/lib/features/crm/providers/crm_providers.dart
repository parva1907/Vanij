import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_repository.dart';
import '../data/customer_repository.dart';
import '../data/models/chat_message.dart';
import '../data/models/customer.dart';

/// Immutable state for the paginated customers list.
class CustomersListState {
  const CustomersListState({
    this.customers = const <Customer>[],
    this.lastDoc,
    this.hasMore = true,
    this.loadingMore = false,
  });

  final List<Customer> customers;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;
  final bool loadingMore;

  CustomersListState copyWith({
    List<Customer>? customers,
    DocumentSnapshot<Map<String, dynamic>>? lastDoc,
    bool? hasMore,
    bool? loadingMore,
  }) {
    return CustomersListState(
      customers: customers ?? this.customers,
      lastDoc: lastDoc ?? this.lastDoc,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}

/// AsyncNotifier for the paginated customers list — mirrors the
/// inventory / ledger pagination pattern.
class CustomersListController extends AsyncNotifier<CustomersListState> {
  @override
  Future<CustomersListState> build() async {
    final repo = ref.read(customerRepositoryProvider);
    final page = await repo.fetchPage();
    return CustomersListState(
      customers: page.customers,
      lastDoc: page.lastDoc,
      hasMore: page.hasMore,
    );
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final repo = ref.read(customerRepositoryProvider);
      final page = await repo.fetchPage(startAfter: current.lastDoc);
      state = AsyncData(
        current.copyWith(
          customers: [...current.customers, ...page.customers],
          lastDoc: page.lastDoc ?? current.lastDoc,
          hasMore: page.hasMore,
          loadingMore: false,
        ),
      );
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(customerRepositoryProvider);
      final page = await repo.fetchPage();
      return CustomersListState(
        customers: page.customers,
        lastDoc: page.lastDoc,
        hasMore: page.hasMore,
      );
    });
  }
}

final customersListControllerProvider =
    AsyncNotifierProvider<CustomersListController, CustomersListState>(
      CustomersListController.new,
    );

/// Client-side name-contains filter. Firestore doesn't offer a
/// case-insensitive "contains" query, so for Sprint 6 we filter the
/// already-fetched page locally. A proper search index (Algolia /
/// Typesense) lands in a later sprint.
class CustomersSearchQuery extends Notifier<String> {
  @override
  String build() => '';

  // ignore: use_setters_to_change_properties
  void set(String value) => state = value;

  void clear() => state = '';
}

final customersSearchQueryProvider =
    NotifierProvider<CustomersSearchQuery, String>(CustomersSearchQuery.new);

final filteredCustomersProvider = Provider<List<Customer>>((ref) {
  final state = ref.watch(customersListControllerProvider);
  final q = ref.watch(customersSearchQueryProvider).trim().toLowerCase();
  final list = state.asData?.value.customers ?? const <Customer>[];
  if (q.isEmpty) return list;
  return list.where((c) => c.name.toLowerCase().contains(q)).toList();
});

/// Live customer doc for the chat screen — reflects renames / note
/// edits immediately.
final customerByIdProvider = StreamProvider.family<Customer?, String>((
  ref,
  customerId,
) {
  return ref.read(customerRepositoryProvider).watchById(customerId);
});

/// Live message history for a given customer. Newest-first.
final chatHistoryProvider = StreamProvider.family<List<ChatMessage>, String>((
  ref,
  customerId,
) {
  return ref.read(chatRepositoryProvider).watchRecent(customerId);
});
