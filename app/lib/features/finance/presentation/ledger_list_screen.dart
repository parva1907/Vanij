import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models/ledger_entry.dart';
import '../providers/ledger_providers.dart';

/// Paginated, filterable ledger list.
///
/// Riverpod providers consumed:
///   * `ledgerFilterControllerProvider` — mutable filter state
///   * `ledgerListControllerProvider`   — paginated entries for the filter
class LedgerListScreen extends ConsumerWidget {
  const LedgerListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final filter = ref.watch(ledgerFilterControllerProvider);
    final listAsync = ref.watch(ledgerListControllerProvider);
    final inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final dateFmt = DateFormat.yMMMd().add_jm();

    return Scaffold(
      appBar: AppBar(title: Text(l.financeLedgerTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(VanijRoutes.financeNew),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _TypeChip(
                  label: l.financeFilterAll,
                  selected: filter.type == null,
                  onTap: () => ref
                      .read(ledgerFilterControllerProvider.notifier)
                      .setType(null),
                ),
                const SizedBox(width: 8),
                _TypeChip(
                  label: l.financeTypeSale,
                  selected: filter.type == LedgerEntryType.sale,
                  onTap: () => ref
                      .read(ledgerFilterControllerProvider.notifier)
                      .setType(LedgerEntryType.sale),
                ),
                const SizedBox(width: 8),
                _TypeChip(
                  label: l.financeTypeExpense,
                  selected: filter.type == LedgerEntryType.expense,
                  onTap: () => ref
                      .read(ledgerFilterControllerProvider.notifier)
                      .setType(LedgerEntryType.expense),
                ),
                const SizedBox(width: 8),
                _TypeChip(
                  label: l.financeTypeRefund,
                  selected: filter.type == LedgerEntryType.refund,
                  onTap: () => ref
                      .read(ledgerFilterControllerProvider.notifier)
                      .setType(LedgerEntryType.refund),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: listAsync.when(
              data: (s) {
                if (s.entries.isEmpty) {
                  return Center(
                    child: Text(
                      l.emptyFinanceTitle,
                      style: const TextStyle(color: VanijColors.textSecondary),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(ledgerListControllerProvider.notifier).refresh(),
                  child: NotificationListener<ScrollEndNotification>(
                    onNotification: (n) {
                      if (n.metrics.pixels >= n.metrics.maxScrollExtent - 80 &&
                          s.hasMore) {
                        ref
                            .read(ledgerListControllerProvider.notifier)
                            .loadMore();
                      }
                      return false;
                    },
                    child: ListView.separated(
                      itemCount: s.entries.length + (s.hasMore ? 1 : 0),
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, indent: 60),
                      itemBuilder: (context, i) {
                        if (i == s.entries.length) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: s.loadingMore
                                  ? const CircularProgressIndicator()
                                  : TextButton(
                                      onPressed: () => ref
                                          .read(
                                            ledgerListControllerProvider
                                                .notifier,
                                          )
                                          .loadMore(),
                                      child: Text(l.inventoryLoadMore),
                                    ),
                            ),
                          );
                        }
                        final e = s.entries[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _colorFor(e.type),
                            child: Icon(
                              _iconFor(e.type),
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            inr.format(e.amount),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: e.type == LedgerEntryType.sale
                                  ? VanijColors.textPrimary
                                  : const Color(0xFFC62828),
                            ),
                          ),
                          subtitle: Text(
                            e.note?.isNotEmpty == true
                                ? '${e.note}  ·  ${dateFmt.format(e.date)}'
                                : dateFmt.format(e.date),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: e.upiRefEncrypted != null
                              ? const Icon(
                                  Icons.lock_outline,
                                  size: 16,
                                  color: VanijColors.textSecondary,
                                )
                              : null,
                        );
                      },
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(l.genericError)),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorFor(LedgerEntryType type) {
    switch (type) {
      case LedgerEntryType.sale:
        return VanijColors.primary;
      case LedgerEntryType.refund:
        return const Color(0xFFC62828);
      case LedgerEntryType.expense:
        return VanijColors.accent;
    }
  }

  IconData _iconFor(LedgerEntryType type) {
    switch (type) {
      case LedgerEntryType.sale:
        return Icons.trending_up;
      case LedgerEntryType.refund:
        return Icons.undo;
      case LedgerEntryType.expense:
        return Icons.trending_down;
    }
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: VanijColors.primary.withValues(alpha: 0.12),
      labelStyle: TextStyle(
        color: selected ? VanijColors.primary : VanijColors.textPrimary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }
}
