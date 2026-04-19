import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/security/phone_cipher.dart';
import '../../../l10n/app_localizations.dart';
import '../data/customer_repository.dart';
import '../data/models/customer.dart';
import '../providers/crm_providers.dart';

/// Form for creating or editing a [Customer]. Phone is AES-256-GCM
/// encrypted locally via [PhoneCipher] before any Firestore write —
/// plaintext `phone` is never sent.
///
/// Riverpod providers consumed:
///   * `customerRepositoryProvider`   — Firestore write target
///   * `phoneCipherProvider`          — AES-256 encryption for phone
///   * `customersListControllerProvider` — invalidated on success so
///     the list refreshes in lock-step
class AddCustomerScreen extends ConsumerStatefulWidget {
  const AddCustomerScreen({super.key, this.existing});

  /// When provided, the form pre-fills and behaves as an edit.
  /// `existing.phoneEncrypted` is decrypted on-screen; it never
  /// leaves the device.
  final Customer? existing;

  @override
  ConsumerState<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends ConsumerState<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();
  final _tags = TextEditingController();
  bool _submitting = false;
  bool _loadingPrefill = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _name.text = existing.name;
      _notes.text = existing.notes ?? '';
      _tags.text = existing.tags.join(', ');
      _prefillPhone(existing);
    }
  }

  Future<void> _prefillPhone(Customer existing) async {
    setState(() => _loadingPrefill = true);
    try {
      final cipher = ref.read(phoneCipherProvider);
      final plain = await cipher.decrypt(existing.phoneEncrypted);
      if (!mounted) return;
      _phone.text = plain;
    } catch (_) {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      setState(() => _submitError = l.crmCustomerDecryptFailed);
    } finally {
      if (mounted) setState(() => _loadingPrefill = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    _tags.dispose();
    super.dispose();
  }

  List<String> _parseTags(String raw) {
    return raw
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l = AppLocalizations.of(context);
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final notes = _notes.text.trim();
    final tags = _parseTags(_tags.text);
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final cipher = ref.read(phoneCipherProvider);
      final phoneEncrypted = await cipher.encrypt(phone);
      final repo = ref.read(customerRepositoryProvider);
      final existing = widget.existing;
      if (existing == null) {
        final draft = Customer(
          id: '',
          name: name,
          phoneEncrypted: phoneEncrypted,
          createdAt: DateTime.now(),
          tags: tags,
          notes: notes.isEmpty ? null : notes,
        );
        await repo.create(draft);
      } else {
        final updated = existing.copyWith(
          name: name,
          phoneEncrypted: phoneEncrypted,
          tags: tags,
          notes: notes.isEmpty ? null : notes,
        );
        await repo.update(existing.id, updated);
      }
      ref.invalidate(customersListControllerProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.crmCustomerSaved)));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitError = l.genericError);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? l.crmEditCustomer : l.crmAddCustomer),
      ),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _submitting || _loadingPrefill,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_submitError != null) ...[
                  _ErrorBanner(message: _submitError!),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l.crmCustomerFieldName,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return l.crmCustomerValidationNameRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]')),
                    LengthLimitingTextInputFormatter(20),
                  ],
                  decoration: InputDecoration(
                    labelText: l.crmCustomerFieldPhone,
                    helperText: l.crmCustomerFieldPhoneHint,
                  ),
                  validator: (v) {
                    final raw = (v ?? '').trim();
                    if (raw.isEmpty) {
                      return l.crmCustomerValidationPhoneRequired;
                    }
                    final digits = raw.replaceAll(RegExp(r'\D'), '');
                    if (digits.length < 7) {
                      return l.crmCustomerValidationPhoneInvalid;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tags,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l.crmCustomerFieldTags,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: l.crmCustomerFieldNotes,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: Text(_submitting ? l.commonSaving : l.inventorySave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE4E2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFB42318)),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
