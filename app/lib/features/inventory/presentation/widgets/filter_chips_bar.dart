import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../providers/inventory_providers.dart';

/// Predefined Indian retail-clothing categories. Ordered by typical
/// Sprint-1 merchant volume.
const List<String> kInventoryCategories = [
  'Saree',
  'Kurta',
  'Lehenga',
  'Salwar',
  'Shirt',
  'Trouser',
  'Dupatta',
  'Accessory',
];

/// Common fabric colours.
const List<String> kInventoryColors = [
  'Red',
  'Green',
  'Blue',
  'Yellow',
  'Pink',
  'White',
  'Black',
  'Gold',
  'Silver',
  'Multicolour',
];

/// Horizontally scrolling chip row: category filter, colour filter,
/// low-stock toggle. Reads/writes `inventoryFilterControllerProvider`.
class FilterChipsBar extends ConsumerWidget {
  const FilterChipsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final filter = ref.watch(inventoryFilterControllerProvider).filter;
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _DropdownChip<String>(
            label: l.inventoryFilterCategory,
            value: filter.category,
            options: kInventoryCategories,
            onChanged: (v) => ref
                .read(inventoryFilterControllerProvider.notifier)
                .setCategory(v),
          ),
          const SizedBox(width: 8),
          _DropdownChip<String>(
            label: l.inventoryFilterColor,
            value: filter.color,
            options: kInventoryColors,
            onChanged: (v) => ref
                .read(inventoryFilterControllerProvider.notifier)
                .setColor(v),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(l.inventoryLowStockChip),
            selected: filter.lowStockOnly,
            selectedColor: VanijColors.accent.withValues(alpha: 0.25),
            backgroundColor: Colors.white,
            side: BorderSide(
              color: filter.lowStockOnly
                  ? VanijColors.accent
                  : VanijColors.divider,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            onSelected: (v) => ref
                .read(inventoryFilterControllerProvider.notifier)
                .setLowStockOnly(v),
          ),
        ],
      ),
    );
  }
}

class _DropdownChip<T> extends StatelessWidget {
  const _DropdownChip({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<T> options;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isActive = value != null;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () async {
        final picked = await showModalBottomSheet<_ChipPick<T>>(
          context: context,
          builder: (_) => _OptionSheet<T>(
            title: label,
            options: options,
            selected: value,
            allLabel: l.inventoryFilterAll,
          ),
        );
        if (picked != null) onChanged(picked.value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? VanijColors.primary.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive ? VanijColors.primary : VanijColors.divider,
          ),
        ),
        child: Row(
          children: [
            Text(
              isActive ? '$label: $value' : label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? VanijColors.primary : VanijColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: isActive ? VanijColors.primary : VanijColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionSheet<T> extends StatelessWidget {
  const _OptionSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.allLabel,
  });

  final String title;
  final List<T> options;
  final T? selected;
  final String allLabel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ListTile(
            title: Text(allLabel),
            trailing: selected == null
                ? const Icon(Icons.check, color: VanijColors.primary)
                : null,
            onTap: () => Navigator.of(context).pop(const _ChipPick(null)),
          ),
          for (final opt in options)
            ListTile(
              title: Text(opt.toString()),
              trailing: selected == opt
                  ? const Icon(Icons.check, color: VanijColors.primary)
                  : null,
              onTap: () => Navigator.of(context).pop(_ChipPick(opt)),
            ),
        ],
      ),
    );
  }
}

class _ChipPick<T> {
  const _ChipPick(this.value);
  final T? value;
}
