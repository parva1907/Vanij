import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../providers/ledger_providers.dart';

/// A lightweight 7-bar chart for weekly signed revenue (sales - refunds
/// - expenses). Built from primitives — no heavy charting lib — per
/// the "lightweight first" rule.
class WeeklyRevenueChart extends StatelessWidget {
  const WeeklyRevenueChart({super.key, required this.days});

  final List<DailyRevenue> days;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return const SizedBox(height: 120);
    }
    final maxAbs = days
        .map((d) => d.revenue.abs())
        .fold<double>(0, (a, b) => a > b ? a : b);
    final label = DateFormat.E();
    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in days)
            Expanded(
              child: _Bar(
                heightFraction: maxAbs == 0 ? 0 : (d.revenue.abs() / maxAbs),
                positive: d.revenue >= 0,
                dayLabel: label.format(d.day),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.heightFraction,
    required this.positive,
    required this.dayLabel,
  });

  final double heightFraction;
  final bool positive;
  final String dayLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                height: 100 * heightFraction.clamp(0, 1),
                decoration: BoxDecoration(
                  color: positive ? VanijColors.primary : VanijColors.accent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            dayLabel,
            style: const TextStyle(
              fontSize: 11,
              color: VanijColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
