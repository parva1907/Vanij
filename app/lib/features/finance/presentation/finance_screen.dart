import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../data/csv_export_service.dart';
import '../providers/ledger_providers.dart';
import 'widgets/weekly_chart.dart';

/// Finance dashboard: today's revenue, weekly P&L, top items, CSV export.
///
/// Riverpod providers consumed:
///   * `todaySummaryProvider`        — today's sales − refunds
///   * `weekSummaryProvider`         — rolling 7-day P&L
///   * `weekDailyRevenueProvider`    — per-day buckets for the chart
///   * `weekTopItemsProvider`        — top items by sale count
///   * `csvExportServiceProvider`    — date-range CSV export
class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final today = ref.watch(todaySummaryProvider);
    final week = ref.watch(weekSummaryProvider);
    final days = ref.watch(weekDailyRevenueProvider);
    final topItems = ref.watch(weekTopItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.navFinance),
        actions: [
          IconButton(
            tooltip: l.financeExportCsv,
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () => _exportLast30Days(context, ref),
          ),
          IconButton(
            tooltip: l.financeViewLedger,
            icon: const Icon(Icons.list_alt),
            onPressed: () => context.push(VanijRoutes.financeLedger),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(VanijRoutes.financeNew),
        icon: const Icon(Icons.add),
        label: Text(l.financeAddEntry),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(ledgerListControllerProvider);
          await ref.read(todaySummaryProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            VanijCard(
              padding: const EdgeInsets.all(16),
              child: today.when(
                data: (s) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.financeToday,
                      style: const TextStyle(
                        color: VanijColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      inr.format(s.revenue),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.financeTodayBreakdown(
                        inr.format(s.salesTotal),
                        inr.format(s.refundTotal),
                        inr.format(s.expenseTotal),
                      ),
                      style: const TextStyle(
                        color: VanijColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                loading: () => const SizedBox(
                  height: 60,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text(l.genericError),
              ),
            ),
            const SizedBox(height: 16),
            VanijCard(
              padding: const EdgeInsets.all(16),
              child: week.when(
                data: (s) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.financeWeekPnl,
                      style: const TextStyle(
                        color: VanijColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      inr.format(s.profit),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: s.profit >= 0
                            ? VanijColors.primary
                            : const Color(0xFFC62828),
                      ),
                    ),
                    const SizedBox(height: 12),
                    days.when(
                      data: (d) => WeeklyRevenueChart(days: d),
                      loading: () => const SizedBox(
                        height: 120,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Text(l.genericError),
                    ),
                  ],
                ),
                loading: () => const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text(l.genericError),
              ),
            ),
            const SizedBox(height: 16),
            VanijCard(
              padding: const EdgeInsets.all(16),
              child: topItems.when(
                data: (items) {
                  if (items.isEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.financeTopItems,
                          style: const TextStyle(
                            color: VanijColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l.financeTopItemsEmpty,
                          style: const TextStyle(
                            color: VanijColors.textSecondary,
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.financeTopItems,
                        style: const TextStyle(
                          color: VanijColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final item in items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.inventory_2_outlined,
                                size: 18,
                                color: VanijColors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.itemRef,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${item.count} · ${inr.format(item.revenue)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
                loading: () => const SizedBox(
                  height: 60,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text(l.genericError),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Future<void> _exportLast30Days(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final now = DateTime.now();
    final to = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    final from = to.subtract(const Duration(days: 30));
    final service = ref.read(csvExportServiceProvider);
    navigator.overlay?.insert(
      OverlayEntry(builder: (_) => Container(color: Colors.black26)),
    );
    try {
      final file = await service.exportRange(from: from, to: to);
      await Share.shareXFiles([
        XFile(file.path),
      ], subject: l.financeExportCsvSubject);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.genericError)));
    }
  }
}
