import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import 'models/customer.dart';

/// Page size for customer list reads — same .limit() discipline as
/// inventory / ledger (spec: never unbounded).
const int kCustomersPageSize = 30;

class CustomersPage {
  const CustomersPage({
    required this.customers,
    required this.lastDoc,
    required this.hasMore,
  });

  final List<Customer> customers;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;
}

class CustomerRepository {
  CustomerRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  }) : _firestore = firestore,
       _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('CustomerRepository requires a signed-in user.');
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return _firestore.collection('merchants').doc(uid).collection('customers');
  }

  /// Fetches one paginated page ordered by most-recent activity (new
  /// messages bubble to the top). Falls back to `createdAt` for brand
  /// new customers that don't yet have a `lastMessageAt`.
  Future<CustomersPage> fetchPage({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    final uid = _requireUid();
    // Server-side order by `updatedAt` desc so newly-added, renamed,
    // or recently-chatted customers surface first.
    var q = _collection(
      uid,
    ).orderBy('updatedAt', descending: true).limit(kCustomersPageSize);
    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }
    final snap = await q.get();
    final customers = snap.docs.map(Customer.fromDoc).toList();
    return CustomersPage(
      customers: customers,
      lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
      hasMore: snap.docs.length == kCustomersPageSize,
    );
  }

  /// Read a single customer by id (used by the chat screen).
  Future<Customer?> getById(String customerId) async {
    final uid = _requireUid();
    final doc = await _collection(uid).doc(customerId).get();
    if (!doc.exists) return null;
    return Customer.fromDoc(doc);
  }

  /// Streams the customer doc — the chat screen watches it so edits
  /// (e.g. rename) reflect live.
  Stream<Customer?> watchById(String customerId) {
    final uid = _requireUid();
    return _collection(uid).doc(customerId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Customer.fromDoc(doc);
    });
  }

  /// Append a new customer. Returns the new document id. Caller is
  /// responsible for ensuring `draft.phoneEncrypted` is the output of
  /// [PhoneCipher.encrypt] (plaintext is banned by rules).
  Future<String> create(Customer draft) async {
    final uid = _requireUid();
    final ref = _collection(uid).doc();
    await ref.set(draft.toCreatePayload());
    return ref.id;
  }

  /// Update an existing customer's name / notes / tags (phone edits
  /// still go through [PhoneCipher]).
  Future<void> update(String customerId, Customer draft) async {
    final uid = _requireUid();
    await _collection(uid).doc(customerId).update(draft.toUpdatePayload());
  }

  /// Delete a customer. Messages subcollection survives; callers can
  /// iterate and delete before removing the parent if full GC is
  /// required (out of scope for Sprint 6).
  Future<void> delete(String customerId) async {
    final uid = _requireUid();
    await _collection(uid).doc(customerId).delete();
  }
}

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});
