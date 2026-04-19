import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ledger_repository.dart';
import '../data/models/ledger_entry.dart';

/// Immutable state for the paginated ledger list screen.
class LedgerListState {
  const LedgerListState({
    required this.entries,
    required this.lastDoc,
    required this.hasMore,
    required this.loadingMore,
    this.error,
  });

  final List<LedgerEntry> entries;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;
  final bool loadingMore;
  final Object? error;

  LedgerListState copyWith({
    List<LedgerEntry>? entries,
    DocumentSnapshot<Map<String, dynamic>>? lastDoc,
    bool? hasMore,
    bool? loadingMore,
    Object? error,
    bool clearLastDoc = false,
    bool clearError = false,
  }) {
    return LedgerListState(
      entries: entries ?? this.entries,
      lastDoc: clearLastDoc ? null : (lastDoc ?? this.lastDoc),
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Current filter (type + date range) that drives the ledger list.
class LedgerFilterController extends Notifier<LedgerFilter> {
  @override
  LedgerFilter build() => const LedgerFilter();

  void setType(LedgerEntryType? type) {
    state = type == null
        ? state.copyWith(clearType: true)
        : state.copyWith(type: type);
  }

  void setRange(DateTime? from, DateTime? to) {
    state = LedgerFilter(type: state.type, from: from, to: to);
  }

  void reset() => state = const LedgerFilter();
}

final ledgerFilterControllerProvider =
    NotifierProvider<LedgerFilterController, LedgerFilter>(
      LedgerFilterController.new,
    );

/// Paginated ledger list, reactive to [ledgerFilterControllerProvider].
class LedgerListController extends AsyncNotifier<LedgerListState> {
  @override
  Future<LedgerListState> build() async {
    final filter = ref.watch(ledgerFilterControllerProvider);
    final repo = ref.read(ledgerRepositoryProvider);
    final page = await repo.fetchPage(filter: filter);
    return LedgerListState(
      entries: page.entries,
      lastDoc: page.lastDoc,
      hasMore: page.hasMore,
      loadingMore: false,
    );
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true, clearError: true));
    try {
      final filter = ref.read(ledgerFilterControllerProvider);
      final repo = ref.read(ledgerRepositoryProvider);
      final page = await repo.fetchPage(
        filter: filter,
        startAfter: current.lastDoc,
      );
      state = AsyncData(
        LedgerListState(
          entries: [...current.entries, ...page.entries],
          lastDoc: page.lastDoc ?? current.lastDoc,
          hasMore: page.hasMore,
          loadingMore: false,
        ),
      );
    } catch (e) {
      state = AsyncData(current.copyWith(loadingMore: false, error: e));
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }
}

final ledgerListControllerProvider =
    AsyncNotifierProvider<LedgerListController, LedgerListState>(
      LedgerListController.new,
    );

/// Summary of a fetched date range — used by the dashboard and by
/// downstream chart widgets.
class LedgerRangeSummary {
  const LedgerRangeSummary({
    required this.entries,
    required this.salesTotal,
    required this.refundTotal,
    required this.expenseTotal,
  });

  final List<LedgerEntry> entries;
  final double salesTotal;
  final double refundTotal;
  final double expenseTotal;

  double get revenue => salesTotal - refundTotal;
  double get profit => salesTotal - refundTotal - expenseTotal;

  factory LedgerRangeSummary.fromEntries(List<LedgerEntry> entries) {
    var sales = 0.0, refunds = 0.0, expenses = 0.0;
    for (final e in entries) {
      switch (e.type) {
        case LedgerEntryType.sale:
          sales += e.amount;
          break;
        case LedgerEntryType.refund:
          refunds += e.amount;
          break;
        case LedgerEntryType.expense:
          expenses += e.amount;
          break;
      }
    }
    return LedgerRangeSummary(
      entries: entries,
      salesTotal: sales,
      refundTotal: refunds,
      expenseTotal: expenses,
    );
  }
}

DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// Today's summary (midnight → now). Refreshes whenever the ledger
/// list controller invalidates.
final todaySummaryProvider = FutureProvider<LedgerRangeSummary>((ref) async {
  // Re-run whenever the list controller mutates (e.g. after a create).
  ref.watch(ledgerListControllerProvider);
  final now = DateTime.now();
  final from = _startOfDay(now);
  final to = from.add(const Duration(days: 1));
  final repo = ref.watch(ledgerRepositoryProvider);
  final entries = await repo.fetchRange(from: from, to: to);
  return LedgerRangeSummary.fromEntries(entries);
});

/// Rolling 7-day summary, inclusive of today.
final weekSummaryProvider = FutureProvider<LedgerRangeSummary>((ref) async {
  ref.watch(ledgerListControllerProvider);
  final now = DateTime.now();
  final to = _startOfDay(now).add(const Duration(days: 1));
  final from = to.subtract(const Duration(days: 7));
  final repo = ref.watch(ledgerRepositoryProvider);
  final entries = await repo.fetchRange(from: from, to: to);
  return LedgerRangeSummary.fromEntries(entries);
});

/// Bucketed daily totals for the rolling-7-day window. Oldest first.
final weekDailyRevenueProvider = FutureProvider<List<DailyRevenue>>((
  ref,
) async {
  final summary = await ref.watch(weekSummaryProvider.future);
  final now = DateTime.now();
  final todayStart = _startOfDay(now);
  final buckets = <DateTime, double>{
    for (var i = 6; i >= 0; i--) todayStart.subtract(Duration(days: i)): 0.0,
  };
  for (final e in summary.entries) {
    final bucket = _startOfDay(e.date);
    if (buckets.containsKey(bucket)) {
      buckets[bucket] = (buckets[bucket] ?? 0) + e.signedAmount;
    }
  }
  return buckets.entries
      .map((kv) => DailyRevenue(day: kv.key, revenue: kv.value))
      .toList();
});

class DailyRevenue {
  const DailyRevenue({required this.day, required this.revenue});
  final DateTime day;
  final double revenue;
}

/// Top items by sale count over the same rolling 7-day window.
/// Grouped on `itemRef` (missing refs are ignored — only tracked sales
/// with a linked inventory item count).
class TopItem {
  const TopItem({
    required this.itemRef,
    required this.count,
    required this.revenue,
  });

  final String itemRef;
  final int count;
  final double revenue;
}

final weekTopItemsProvider = FutureProvider<List<TopItem>>((ref) async {
  final summary = await ref.watch(weekSummaryProvider.future);
  final byRef = <String, _TopAccumulator>{};
  for (final e in summary.entries) {
    if (e.type != LedgerEntryType.sale) continue;
    final ref = e.itemRef;
    if (ref == null || ref.isEmpty) continue;
    final acc = byRef.putIfAbsent(ref, _TopAccumulator.new);
    acc.count += 1;
    acc.revenue += e.amount;
  }
  final list = byRef.entries
      .map(
        (kv) => TopItem(
          itemRef: kv.key,
          count: kv.value.count,
          revenue: kv.value.revenue,
        ),
      )
      .toList();
  list.sort((a, b) => b.count.compareTo(a.count));
  return list.take(5).toList();
});

class _TopAccumulator {
  int count = 0;
  double revenue = 0;
}
