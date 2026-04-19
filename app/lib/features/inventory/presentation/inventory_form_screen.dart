import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../data/image_upload_service.dart';
import '../data/inventory_repository.dart';
import '../data/models/inventory_item.dart';
import '../providers/inventory_providers.dart';
import 'widgets/filter_chips_bar.dart';

/// Create / edit form. Pass [itemId] = null for create.
///
/// Riverpod providers consumed:
///   • `inventoryRepositoryProvider`       — load item on edit.
///   • `inventoryMutationControllerProvider` — save / delete.
///   • `imageUploadServiceProvider`        — upload WebP photo.
class InventoryFormScreen extends ConsumerStatefulWidget {
  const InventoryFormScreen({super.key, this.itemId});
  final String? itemId;

  bool get isEdit => itemId != null;

  @override
  ConsumerState<InventoryFormScreen> createState() =>
      _InventoryFormScreenState();
}

class _InventoryFormScreenState extends ConsumerState<InventoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _patternCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _costCtrl = TextEditingController();

  String _category = kInventoryCategories.first;
  final Set<String> _colors = {};
  final Map<String, int> _quantity = {};

  File? _pickedImage;
  String _existingImageUrl = '';
  bool _uploading = false;
  bool _loadingExisting = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) {
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    setState(() => _loadingExisting = true);
    try {
      final item = await ref
          .read(inventoryRepositoryProvider)
          .getById(widget.itemId!);
      _nameCtrl.text = item.name;
      _patternCtrl.text = item.pattern ?? '';
      _priceCtrl.text = item.price.toStringAsFixed(2);
      _costCtrl.text = item.costPrice.toStringAsFixed(2);
      _category = kInventoryCategories.contains(item.category)
          ? item.category
          : kInventoryCategories.first;
      _colors
        ..clear()
        ..addAll(item.colors);
      _quantity
        ..clear()
        ..addAll(item.quantity);
      _existingImageUrl = item.imageUrl;
    } on Object catch (e) {
      _loadError = e.toString();
    } finally {
      if (mounted) setState(() => _loadingExisting = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _patternCtrl.dispose();
    _priceCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      maxWidth: 2560,
      imageQuality: 95,
    );
    if (file == null) return;
    setState(() => _pickedImage = File(file.path));
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (_quantity.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.inventoryValidationNeedAtLeastOneSize)),
      );
      return;
    }
    if (_pickedImage == null && _existingImageUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.inventoryValidationImageRequired)),
      );
      return;
    }

    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    final cost = double.tryParse(_costCtrl.text.trim()) ?? 0;

    String imageUrl = _existingImageUrl;
    String? idToUploadAgainst = widget.itemId;
    final mutation = ref.read(inventoryMutationControllerProvider.notifier);

    try {
      if (widget.itemId == null) {
        // Create a placeholder item first so we have an ID for the blob path.
        final placeholder = InventoryItem(
          id: '',
          name: _nameCtrl.text.trim(),
          category: _category,
          colors: _colors.toList(),
          sizes: _quantity.keys.toList(),
          quantity: Map.of(_quantity),
          price: price,
          costPrice: cost,
          imageUrl: '',
          pattern: _patternCtrl.text.trim().isEmpty
              ? null
              : _patternCtrl.text.trim(),
          lowStock: InventoryItem.computeLowStock(_quantity),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        idToUploadAgainst = await mutation.save(draft: placeholder);
      }

      if (_pickedImage != null) {
        setState(() => _uploading = true);
        imageUrl = await ref
            .read(imageUploadServiceProvider)
            .uploadInventoryImage(
              sourceFile: _pickedImage!,
              itemId: idToUploadAgainst!,
            );
      }

      final finalItem = InventoryItem(
        id: idToUploadAgainst!,
        name: _nameCtrl.text.trim(),
        category: _category,
        colors: _colors.toList(),
        sizes: _quantity.keys.toList(),
        quantity: Map.of(_quantity),
        price: price,
        costPrice: cost,
        imageUrl: imageUrl,
        pattern: _patternCtrl.text.trim().isEmpty
            ? null
            : _patternCtrl.text.trim(),
        lowStock: InventoryItem.computeLowStock(_quantity),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await mutation.save(draft: finalItem, itemId: idToUploadAgainst);

      if (!mounted) return;
      context.pop();
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.inventoryDeleteConfirmTitle),
        content: Text(l.inventoryDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l.inventoryDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(inventoryMutationControllerProvider.notifier)
          .delete(widget.itemId!);
      if (!mounted) return;
      context.pop();
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mutation = ref.watch(inventoryMutationControllerProvider);
    final isBusy = mutation.isLoading || _uploading;

    if (_loadingExisting) {
      return Scaffold(
        appBar: AppBar(title: Text(l.inventoryEditItem)),
        body: const Center(
          child: CircularProgressIndicator(color: VanijColors.primary),
        ),
      );
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.inventoryEditItem)),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: VanijErrorBanner(message: _loadError!),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? l.inventoryEditItem : l.inventoryAddItem),
        actions: [
          if (widget.isEdit)
            IconButton(
              tooltip: l.inventoryDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: isBusy ? null : _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ImagePickerTile(
                picked: _pickedImage,
                existingUrl: _existingImageUrl,
                onCamera: () => _pickImage(ImageSource.camera),
                onGallery: () => _pickImage(ImageSource.gallery),
                uploading: _uploading,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(labelText: l.inventoryFieldName),
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l.inventoryValidationNameRequired
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: InputDecoration(
                  labelText: l.inventoryFieldCategory,
                ),
                items: [
                  for (final c in kInventoryCategories)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _patternCtrl,
                decoration: InputDecoration(labelText: l.inventoryFieldPattern),
              ),
              const SizedBox(height: 16),
              Text(
                l.inventoryFieldColors,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in kInventoryColors)
                    FilterChip(
                      label: Text(c),
                      selected: _colors.contains(c),
                      onSelected: (v) => setState(
                        () => v ? _colors.add(c) : _colors.remove(c),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              _SizeQuantityEditor(
                quantity: _quantity,
                onChanged: (q) => setState(() {
                  _quantity
                    ..clear()
                    ..addAll(q);
                }),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceCtrl,
                      decoration: InputDecoration(
                        labelText: l.inventoryFieldPrice,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (v) {
                        final parsed = double.tryParse((v ?? '').trim());
                        return (parsed == null || parsed < 0)
                            ? l.inventoryValidationPriceInvalid
                            : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _costCtrl,
                      decoration: InputDecoration(
                        labelText: l.inventoryFieldCostPrice,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (v) {
                        final parsed = double.tryParse((v ?? '').trim());
                        return (parsed == null || parsed < 0)
                            ? l.inventoryValidationCostPriceInvalid
                            : null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: isBusy ? null : _submit,
                icon: isBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  isBusy
                      ? (_uploading
                            ? l.inventoryUploadingImage
                            : l.commonSaving)
                      : l.inventorySave,
                ),
              ),
              const SizedBox(height: 12),
              if (mutation.hasError)
                VanijErrorBanner(message: mutation.error!.toString()),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePickerTile extends StatelessWidget {
  const _ImagePickerTile({
    required this.picked,
    required this.existingUrl,
    required this.onCamera,
    required this.onGallery,
    required this.uploading,
  });

  final File? picked;
  final String existingUrl;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget preview;
    if (picked != null) {
      preview = Image.file(picked!, fit: BoxFit.cover);
    } else if (existingUrl.isNotEmpty) {
      preview = CachedNetworkImage(imageUrl: existingUrl, fit: BoxFit.cover);
    } else {
      preview = Container(
        color: VanijColors.backgroundTint,
        child: const Center(child: Icon(Icons.camera_alt_outlined, size: 36)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                preview,
                if (uploading)
                  const ColoredBox(
                    color: Color(0x66000000),
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: uploading ? null : onCamera,
                icon: const Icon(Icons.camera_alt_outlined),
                label: Text(l.inventoryChooseFromCamera),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: uploading ? null : onGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(l.inventoryChooseFromGallery),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SizeQuantityEditor extends StatefulWidget {
  const _SizeQuantityEditor({required this.quantity, required this.onChanged});

  final Map<String, int> quantity;
  final ValueChanged<Map<String, int>> onChanged;

  @override
  State<_SizeQuantityEditor> createState() => _SizeQuantityEditorState();
}

class _SizeQuantityEditorState extends State<_SizeQuantityEditor> {
  static const List<String> _commonSizes = [
    'XS',
    'S',
    'M',
    'L',
    'XL',
    'XXL',
    'Free',
  ];

  final _customSizeCtrl = TextEditingController();

  @override
  void dispose() {
    _customSizeCtrl.dispose();
    super.dispose();
  }

  void _setQty(String size, int qty) {
    final next = Map<String, int>.from(widget.quantity);
    if (qty <= 0) {
      next.remove(size);
    } else {
      next[size] = qty;
    }
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final visibleSizes = <String>{..._commonSizes, ...widget.quantity.keys};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.inventoryFieldSizes,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        for (final size in visibleSizes)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  child: Text(
                    size,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: TextFormField(
                    initialValue: widget.quantity[size]?.toString() ?? '0',
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l.inventoryFieldQuantity,
                    ),
                    onChanged: (v) =>
                        _setQty(size, int.tryParse(v.trim()) ?? 0),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customSizeCtrl,
                decoration: const InputDecoration(labelText: 'Custom size'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              color: VanijColors.primary,
              onPressed: () {
                final s = _customSizeCtrl.text.trim();
                if (s.isEmpty) return;
                _setQty(s, widget.quantity[s] ?? 1);
                _customSizeCtrl.clear();
              },
            ),
          ],
        ),
      ],
    );
  }
}
