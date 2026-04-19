import 'package:cloud_firestore/cloud_firestore.dart';

/// Kind of ledger movement. Matches the enum enforced by the Firestore
/// rules in `firebase/firestore.rules`.
enum LedgerEntryType {
  sale,
  expense,
  refund;

  String get wireName => name;

  static LedgerEntryType fromWire(String raw) {
    return LedgerEntryType.values.firstWhere(
      (t) => t.wireName == raw,
      orElse: () => LedgerEntryType.sale,
    );
  }
}

/// Signed contribution of an entry to merchant cash flow.
///  * sale    → +amount
///  * refund  → -amount
///  * expense → -amount
double signedCashFlow(LedgerEntryType type, double amount) {
  switch (type) {
    case LedgerEntryType.sale:
      return amount;
    case LedgerEntryType.refund:
    case LedgerEntryType.expense:
      return -amount;
  }
}

/// An immutable ledger row.
///
/// `upiRefEncrypted` holds AES-256-GCM ciphertext (base64) of the UPI
/// reference. Plaintext `upiRef` is never stored — Firestore rules
/// reject any write that contains the `upiRef` key. Decryption is
/// performed on-device via [LedgerCipher] only when the merchant
/// opens an entry or exports a CSV.
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.createdAt,
    this.note,
    this.itemRef,
    this.upiRefEncrypted,
  });

  final String id;
  final LedgerEntryType type;
  final double amount;
  final DateTime date;
  final DateTime createdAt;
  final String? note;

  /// Document id of an optional `inventory` item this entry refers to
  /// (a sale of a specific SKU, an expense for a specific item, etc.).
  final String? itemRef;

  /// Encrypted UPI reference — base64 AES-256-GCM envelope produced by
  /// [LedgerCipher.encrypt].
  final String? upiRefEncrypted;

  double get signedAmount => signedCashFlow(type, amount);

  factory LedgerEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return LedgerEntry(
      id: doc.id,
      type: LedgerEntryType.fromWire((data['type'] as String?) ?? 'sale'),
      amount: _toDouble(data['amount']),
      date: _toDate(data['date']),
      createdAt: _toDate(data['createdAt']),
      note: data['note'] as String?,
      itemRef: data['itemRef'] as String?,
      upiRefEncrypted: data['upiRefEncrypted'] as String?,
    );
  }

  /// Firestore payload. [date] is stored as a Firestore [Timestamp]
  /// so composite indexes (`type+date desc`, `date desc`) work
  /// server-side.
  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'type': type.wireName,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'createdAt': FieldValue.serverTimestamp(),
      if (note != null && note!.isNotEmpty) 'note': note,
      if (itemRef != null && itemRef!.isNotEmpty) 'itemRef': itemRef,
      if (upiRefEncrypted != null && upiRefEncrypted!.isNotEmpty)
        'upiRefEncrypted': upiRefEncrypted,
    };
  }
}

double _toDouble(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

DateTime _toDate(Object? v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return DateTime.fromMillisecondsSinceEpoch(0);
}
