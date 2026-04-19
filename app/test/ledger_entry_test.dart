import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanij/features/finance/data/models/ledger_entry.dart';
import 'package:vanij/features/finance/providers/ledger_providers.dart';

void main() {
  group('LedgerEntry.toFirestore', () {
    test('omits plaintext upiRef key', () {
      final entry = LedgerEntry(
        id: '',
        type: LedgerEntryType.sale,
        amount: 499.50,
        date: DateTime(2025, 4, 18, 14, 30),
        createdAt: DateTime(2025, 4, 18, 14, 30),
        note: 'Cotton kurta sale',
        upiRefEncrypted: 'Y2lwaGVydGV4dA==',
      );
      final payload = entry.toFirestore();
      expect(
        payload.containsKey('upiRef'),
        isFalse,
        reason: 'plaintext upiRef would be rejected by Firestore rules',
      );
      expect(payload['upiRefEncrypted'], 'Y2lwaGVydGV4dA==');
      expect(payload['type'], 'sale');
      expect(payload['amount'], 499.50);
      expect(payload['date'], isA<Timestamp>());
    });

    test('skips optional fields when unset', () {
      final entry = LedgerEntry(
        id: '',
        type: LedgerEntryType.expense,
        amount: 120.0,
        date: DateTime(2025, 4, 1),
        createdAt: DateTime(2025, 4, 1),
      );
      final payload = entry.toFirestore();
      expect(payload.containsKey('note'), isFalse);
      expect(payload.containsKey('itemRef'), isFalse);
      expect(payload.containsKey('upiRefEncrypted'), isFalse);
    });
  });

  group('signedCashFlow', () {
    test('sale contributes positive, refund and expense negative', () {
      expect(signedCashFlow(LedgerEntryType.sale, 100), 100);
      expect(signedCashFlow(LedgerEntryType.refund, 100), -100);
      expect(signedCashFlow(LedgerEntryType.expense, 100), -100);
    });
  });

  group('LedgerRangeSummary', () {
    test('sums sales / refunds / expenses independently', () {
      final summary = LedgerRangeSummary.fromEntries([
        _mkEntry(LedgerEntryType.sale, 500),
        _mkEntry(LedgerEntryType.sale, 300),
        _mkEntry(LedgerEntryType.refund, 200),
        _mkEntry(LedgerEntryType.expense, 150),
      ]);
      expect(summary.salesTotal, 800);
      expect(summary.refundTotal, 200);
      expect(summary.expenseTotal, 150);
      expect(summary.revenue, 600);
      expect(summary.profit, 450);
    });
  });
}

LedgerEntry _mkEntry(LedgerEntryType type, double amount) {
  final now = DateTime(2025, 4, 18, 10);
  return LedgerEntry(
    id: '',
    type: type,
    amount: amount,
    date: now,
    createdAt: now,
  );
}
