import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/inventory_item.dart';

/// Single-row card used in the inventory list. Thumbnail on the left,
/// name / category / price on the right, low-stock chip on the bottom.
class InventoryCard extends StatelessWidget {
  const InventoryCard({super.key, required this.item, required this.onTap});

  final InventoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rupees = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: VanijCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Thumbnail(url: item.imageUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.category,
                        style: const TextStyle(
                          fontSize: 13,
                          color: VanijColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            rupees.format(item.price),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: VanijColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${item.totalQuantity}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: VanijColors.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          if (item.lowStock)
                            _LowStockChip(label: l.inventoryLowStockChip),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    const size = 64.0;
    if (url.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: VanijColors.backgroundTint,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: VanijColors.divider),
        ),
        child: const Icon(
          Icons.image_outlined,
          color: VanijColors.textSecondary,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, _) => Container(
          width: size,
          height: size,
          color: VanijColors.backgroundTint,
        ),
        errorWidget: (context, _, _) => Container(
          width: size,
          height: size,
          color: VanijColors.backgroundTint,
          child: const Icon(Icons.broken_image_outlined, size: 20),
        ),
      ),
    );
  }
}

class _LowStockChip extends StatelessWidget {
  const _LowStockChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: VanijColors.accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: VanijColors.accent),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF8B5A00),
        ),
      ),
    );
  }
}
