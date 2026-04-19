import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/inventory_providers.dart';
import 'widgets/filter_chips_bar.dart';
import 'widgets/inventory_card.dart';

/// Paginated, filterable, searchable inventory list.
///
/// Riverpod providers consumed:
///   • `inventoryListControllerProvider` — pagination state + load more.
///   • `inventoryFilterControllerProvider` — category/colour/low-stock + search.
///   • `visibleInventoryItemsProvider`    — filter/search-applied view.
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_maybeLoadMore);
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 320) {
      ref.read(inventoryListControllerProvider.notifier).loadMore();
    }
  }

  /// Kick off the AI-assisted add flow: pick an image, route through
  /// `TagConfirmScreen`, and let the merchant confirm suggestions
  /// before landing on `InventoryFormScreen`. Never auto-commits.
  Future<void> _addWithAi() async {
    final picker = ImagePicker();
    final shot = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2560,
      imageQuality: 95,
    );
    if (shot == null || !mounted) return;
    context.push(VanijRoutes.inventoryTagConfirm, extra: File(shot.path));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(inventoryListControllerProvider);
    final visible = ref.watch(visibleInventoryItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.navInventory),
        actions: [
          IconButton(
            tooltip: l.inventoryAddWithAi,
            icon: const Icon(Icons.auto_awesome_outlined),
            onPressed: _addWithAi,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(VanijRoutes.inventoryNew),
        backgroundColor: VanijColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(l.inventoryAddItem),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => ref
                  .read(inventoryFilterControllerProvider.notifier)
                  .setSearch(v),
              decoration: InputDecoration(
                hintText: l.inventorySearchHint,
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          const FilterChipsBar(),
          Expanded(
            child: RefreshIndicator(
              color: VanijColors.primary,
              onRefresh: () =>
                  ref.read(inventoryListControllerProvider.notifier).refresh(),
              child: async.when(
                loading: () => const _SkeletonList(),
                error: (e, _) => _ErrorState(
                  message: e.toString(),
                  onRetry: () => ref
                      .read(inventoryListControllerProvider.notifier)
                      .refresh(),
                ),
                data: (state) {
                  if (visible.isEmpty) {
                    final filterOrSearchActive =
                        !state.items.any((_) => true) ||
                        ref
                            .read(inventoryFilterControllerProvider)
                            .search
                            .isNotEmpty ||
                        !ref
                            .read(inventoryFilterControllerProvider)
                            .filter
                            .isEmpty;
                    return _EmptyState(
                      title: state.items.isEmpty
                          ? l.emptyInventoryTitle
                          : l.inventoryNoResults,
                      subtitle: filterOrSearchActive
                          ? l.inventoryNoResults
                          : l.emptyInventorySubtitle,
                    );
                  }
                  return ListView.builder(
                    controller: _scrollCtrl,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: visible.length + (state.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= visible.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: VanijColors.primary,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      }
                      final item = visible[index];
                      return InventoryCard(
                        item: item,
                        onTap: () =>
                            context.push('${VanijRoutes.inventory}/${item.id}'),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 64),
        const Icon(
          Icons.shopping_bag_outlined,
          size: 48,
          color: VanijColors.primary,
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: VanijColors.textSecondary),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        VanijErrorBanner(message: message),
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(l.commonRetry),
          ),
        ),
      ],
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 6,
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemBuilder: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: VanijCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: VanijColors.backgroundTint,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: double.infinity,
                      color: VanijColors.backgroundTint,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 120,
                      color: VanijColors.backgroundTint,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 12,
                      width: 80,
                      color: VanijColors.backgroundTint,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
