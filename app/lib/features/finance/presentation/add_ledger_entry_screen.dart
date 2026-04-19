import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/security/ledger_cipher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../data/ledger_repository.dart';
import '../data/models/ledger_entry.dart';
import '../providers/ledger_providers.dart';

/// Append-only form for a single ledger entry.
///
/// Riverpod providers consumed:
///   * `ledgerRepositoryProvider` — Firestore write target
///   * `ledgerCipherProvider`     — AES-256 encryption for UPI refs
///   * `ledgerListControllerProvider` — invalidated on success so the
///     dashboard and list refresh in lock-step
class AddLedgerEntryScreen extends ConsumerStatefulWidget {
  const AddLedgerEntryScreen({super.key});

  @override
  ConsumerState<AddLedgerEntryScreen> createState() =>
      _AddLedgerEntryScreenState();
}

class _AddLedgerEntryScreenState extends ConsumerState<AddLedgerEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _upi = TextEditingController();
  final _itemRef = TextEditingController();
  LedgerEntryType _type = LedgerEntryType.sale;
  DateTime _date = DateTime.now();
  bool _submitting = false;
  String? _submitError;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _upi.dispose();
    _itemRef.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _date.hour,
          _date.minute,
        );
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l = AppLocalizations.of(context);
    final amount = double.parse(_amount.text.trim());
    final note = _note.text.trim();
    final upi = _upi.text.trim();
    final itemRef = _itemRef.text.trim();
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final cipher = ref.read(ledgerCipherProvider);
      final upiRefEncrypted = upi.isEmpty ? null : await cipher.encrypt(upi);
      final entry = LedgerEntry(
        id: '',
        type: _type,
        amount: amount,
        date: _date,
        createdAt: DateTime.now(),
        note: note.isEmpty ? null : note,
        itemRef: itemRef.isEmpty ? null : itemRef,
        upiRefEncrypted: upiRefEncrypted,
      );
      await ref.read(ledgerRepositoryProvider).create(entry);
      ref.invalidate(ledgerListControllerProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.financeEntrySaved)));
      context.pop();
    } catch (e) {
      setState(() => _submitError = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return Scaffold(
      appBar: AppBar(title: Text(l.financeAddEntry)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_submitError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ErrorBanner(message: _submitError!),
              ),
            Text(
              l.financeEntryType,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SegmentedButton<LedgerEntryType>(
              segments: [
                ButtonSegment(
                  value: LedgerEntryType.sale,
                  label: Text(l.financeTypeSale),
                ),
                ButtonSegment(
                  value: LedgerEntryType.expense,
                  label: Text(l.financeTypeExpense),
                ),
                ButtonSegment(
                  value: LedgerEntryType.refund,
                  label: Text(l.financeTypeRefund),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              decoration: InputDecoration(
                labelText: l.financeFieldAmount,
                prefixText: '₹ ',
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return l.financeValidationAmountRequired;
                final d = double.tryParse(t);
                if (d == null || d < 0) {
                  return l.financeValidationAmountInvalid;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l.financeFieldDate,
                  border: const OutlineInputBorder(),
                ),
                child: Text(DateFormat.yMMMMd().format(_date)),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _note,
              decoration: InputDecoration(
                labelText: l.financeFieldNote,
                border: const OutlineInputBorder(),
              ),
              maxLength: 200,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _itemRef,
              decoration: InputDecoration(
                labelText: l.financeFieldItemRef,
                helperText: l.financeFieldItemRefHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _upi,
              decoration: InputDecoration(
                labelText: l.financeFieldUpiRef,
                helperText: l.financeFieldUpiRefHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      '${l.inventorySave}  ${inr.format(double.tryParse(_amount.text.trim()) ?? 0)}',
                    ),
            ),
          ],
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
        color: const Color(0xFFFDECEA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE57373)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFC62828)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: VanijColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
