import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import 'models/ledger_entry.dart';

/// Page size for ledger list reads — same discipline as inventory.
/// Every query must `.limit()` — never unbounded (per spec).
const int kLedgerPageSize = 30;

/// Filter bundle for the ledger list screen.
class LedgerFilter {
  const LedgerFilter({this.type, this.from, this.to});

  /// `null` = all types.
  final LedgerEntryType? type;

  /// Inclusive start of the range (midnight local).
  final DateTime? from;

  /// Inclusive end of the range (next midnight, exclusive server-side).
  final DateTime? to;

  bool get isEmpty => type == null && from == null && to == null;

  LedgerFilter copyWith({
    LedgerEntryType? type,
    DateTime? from,
    DateTime? to,
    bool clearType = false,
    bool clearFrom = false,
    bool clearTo = false,
  }) {
    return LedgerFilter(
      type: clearType ? null : (type ?? this.type),
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LedgerFilter &&
      other.type == type &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(type, from, to);
}

class LedgerPage {
  const LedgerPage({
    required this.entries,
    required this.lastDoc,
    required this.hasMore,
  });

  final List<LedgerEntry> entries;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;
}

class LedgerRepository {
  LedgerRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  }) : _firestore = firestore,
       _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('LedgerRepository requires a signed-in user.');
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return _firestore.collection('merchants').doc(uid).collection('ledger');
  }

  Query<Map<String, dynamic>> _applyFilter(
    Query<Map<String, dynamic>> base,
    LedgerFilter filter,
  ) {
    var q = base;
    if (filter.type != null) {
      q = q.where('type', isEqualTo: filter.type!.wireName);
    }
    if (filter.from != null) {
      q = q.where(
        'date',
        isGreaterThanOrEqualTo: Timestamp.fromDate(filter.from!),
      );
    }
    if (filter.to != null) {
      q = q.where('date', isLessThan: Timestamp.fromDate(filter.to!));
    }
    return q.orderBy('date', descending: true);
  }

  /// Reads one paginated, server-filtered page of ledger entries.
  Future<LedgerPage> fetchPage({
    required LedgerFilter filter,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    final uid = _requireUid();
    var q = _applyFilter(_collection(uid), filter).limit(kLedgerPageSize);
    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }
    final snap = await q.get();
    final entries = snap.docs.map(LedgerEntry.fromDoc).toList();
    return LedgerPage(
      entries: entries,
      lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
      hasMore: snap.docs.length == kLedgerPageSize,
    );
  }

  /// Reads **all** entries in a date range — used for dashboard P&L
  /// aggregation and CSV export. Still bounded by [maxEntries] so a
  /// runaway range (e.g. "last 5 years") can't drag the app down.
  Future<List<LedgerEntry>> fetchRange({
    required DateTime from,
    required DateTime to,
    int maxEntries = 1000,
  }) async {
    final uid = _requireUid();
    final q = _applyFilter(
      _collection(uid),
      LedgerFilter(from: from, to: to),
    ).limit(maxEntries);
    final snap = await q.get();
    return snap.docs.map(LedgerEntry.fromDoc).toList();
  }

  /// Append a new ledger entry. No update / delete API on purpose —
  /// the collection is append-only per Firestore rules.
  Future<String> create(LedgerEntry draft) async {
    final uid = _requireUid();
    final ref = _collection(uid).doc();
    await ref.set(draft.toFirestore());
    return ref.id;
  }
}

final ledgerRepositoryProvider = Provider<LedgerRepository>((ref) {
  return LedgerRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});
