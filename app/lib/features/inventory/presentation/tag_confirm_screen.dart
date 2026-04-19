import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models/vision_tag_draft.dart';
import '../providers/vision_providers.dart';
import 'widgets/filter_chips_bar.dart';

/// Human-in-the-loop confirmation screen for AI-suggested clothing tags.
///
/// The screen is the mandatory interstitial between the vision tagger
/// and any Firestore write — per the Vanij absolute security rule "never
/// auto-commit AI vision tags". The merchant can add, remove, or
/// replace any candidate before continuing into `InventoryFormScreen`.
///
/// Riverpod providers consumed:
///   • `visionTagControllerProvider(imageFile)` — drives the POST to
///     `/v1/vision/tag` and exposes loading / error / data states.
class TagConfirmScreen extends ConsumerStatefulWidget {
  const TagConfirmScreen({super.key, required this.imageFile});

  final File imageFile;

  @override
  ConsumerState<TagConfirmScreen> createState() => _TagConfirmScreenState();
}

class _TagConfirmScreenState extends ConsumerState<TagConfirmScreen> {
  // Edited, merchant-owned state. Seeded once with the AI suggestions.
  String? _category;
  String? _pattern;
  final Set<String> _colors = {};
  bool _seeded = false;

  void _seed(VisionTagDraft draft) {
    if (_seeded) return;
    _seeded = true;
    _category = kInventoryCategories.contains(draft.category.value)
        ? draft.category.value
        : kInventoryCategories.first;
    _pattern = draft.pattern?.value;
    _colors
      ..clear()
      ..addAll(draft.colors.map((c) => c.value));
  }

  void _onContinue() {
    // Persist the edits — never the raw AI draft — into the form.
    context.pushReplacement(
      VanijRoutes.inventoryNew,
      extra: InventoryDraftSeed(
        imageFile: widget.imageFile,
        category: _category,
        colors: _colors.toList(),
        pattern: _pattern,
      ),
    );
  }

  void _onSkip() {
    // Skip AI suggestions entirely — just pass the image through.
    context.pushReplacement(
      VanijRoutes.inventoryNew,
      extra: InventoryDraftSeed(imageFile: widget.imageFile),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(visionTagControllerProvider(widget.imageFile));

    return Scaffold(
      appBar: AppBar(title: Text(l.tagConfirmTitle)),
      body: SafeArea(
        child: async.when(
          loading: () =>
              _Loading(file: widget.imageFile, label: l.tagConfirmLoading),
          error: (err, _) => _ErrorState(
            message: err.toString(),
            onRetry: () => ref
                .read(visionTagControllerProvider(widget.imageFile).notifier)
                .retry(),
            onSkip: _onSkip,
          ),
          data: (draft) {
            _seed(draft);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ImagePreview(file: widget.imageFile),
                const SizedBox(height: 16),
                _BackendBadge(draft: draft),
                const SizedBox(height: 20),
                Text(
                  l.tagConfirmHeadline,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  l.tagConfirmSubheadline,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                _CategorySection(
                  label: l.inventoryFieldCategory,
                  selected: _category,
                  suggested: draft.category.value,
                  onChanged: (v) => setState(() => _category = v),
                ),
                const SizedBox(height: 20),
                _ColorsSection(
                  label: l.inventoryFieldColors,
                  selected: _colors,
                  suggested: draft.colors.map((c) => c.value).toSet(),
                  onToggle: (c) => setState(() {
                    if (!_colors.remove(c)) _colors.add(c);
                  }),
                ),
                const SizedBox(height: 20),
                _PatternSection(
                  label: l.inventoryFieldPattern,
                  selected: _pattern,
                  suggested: draft.pattern?.value,
                  onChanged: (v) => setState(() => _pattern = v),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: VanijColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _onContinue,
                  child: Text(l.tagConfirmContinue),
                ),
                TextButton(onPressed: _onSkip, child: Text(l.tagConfirmSkip)),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Payload carried into `InventoryFormScreen` via GoRouter's ``extra``.
///
/// Kept immutable + const-constructible so it composes cleanly with
/// other entry points (e.g. a future import-from-CSV flow) without
/// widening the form's public API.
class InventoryDraftSeed {
  const InventoryDraftSeed({
    required this.imageFile,
    this.category,
    this.colors = const [],
    this.pattern,
  });

  final File imageFile;
  final String? category;
  final List<String> colors;
  final String? pattern;
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.file});
  final File file;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Image.file(file, fit: BoxFit.cover),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.file, required this.label});
  final File file;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ImagePreview(file: file),
        const SizedBox(height: 24),
        const Center(
          child: CircularProgressIndicator(color: VanijColors.primary),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.onSkip,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VanijErrorBanner(message: message),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: Text(l.commonRetry)),
          TextButton(onPressed: onSkip, child: Text(l.tagConfirmSkip)),
        ],
      ),
    );
  }
}

class _BackendBadge extends StatelessWidget {
  const _BackendBadge({required this.draft});
  final VisionTagDraft draft;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: VanijColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${draft.backend} · ${draft.modelVersion}',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: VanijColors.primary),
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.label,
    required this.selected,
    required this.suggested,
    required this.onChanged,
  });

  final String label;
  final String? selected;
  final String suggested;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(label: label, suggested: suggested),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: selected,
          items: [
            for (final c in kInventoryCategories)
              DropdownMenuItem(value: c, child: Text(c)),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ColorsSection extends StatelessWidget {
  const _ColorsSection({
    required this.label,
    required this.selected,
    required this.suggested,
    required this.onToggle,
  });

  final String label;
  final Set<String> selected;
  final Set<String> suggested;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    // Union of the canonical palette + anything unusual the AI saw so
    // no suggestion disappears behind the scenes.
    final palette = <String>{...kInventoryColors, ...suggested}.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(
          label: label,
          suggested: suggested.isEmpty ? null : suggested.join(', '),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in palette)
              FilterChip(
                label: Text(c),
                selected: selected.contains(c),
                onSelected: (_) => onToggle(c),
                selectedColor: VanijColors.primary.withValues(alpha: 0.15),
                checkmarkColor: VanijColors.primary,
              ),
          ],
        ),
      ],
    );
  }
}

class _PatternSection extends StatelessWidget {
  const _PatternSection({
    required this.label,
    required this.selected,
    required this.suggested,
    required this.onChanged,
  });

  final String label;
  final String? selected;
  final String? suggested;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: selected ?? '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(label: label, suggested: suggested),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: (v) => onChanged(v.trim().isEmpty ? null : v.trim()),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.suggested});
  final String label;
  final String? suggested;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        if (suggested != null && suggested!.isNotEmpty)
          Text(
            l.tagConfirmAiSuggested(suggested!),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: VanijColors.primary),
          ),
      ],
    );
  }
}
