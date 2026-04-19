import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import 'models/inventory_item.dart';

/// Size of each inventory page. Low enough that a cold start never
/// pulls the entire catalogue.
const int kInventoryPageSize = 20;

/// Immutable filter bundle read by [InventoryRepository.watchPage].
class InventoryFilter {
  const InventoryFilter({this.category, this.color, this.lowStockOnly = false});

  final String? category;
  final String? color;
  final bool lowStockOnly;

  bool get isEmpty => category == null && color == null && !lowStockOnly;

  InventoryFilter copyWith({
    String? category,
    String? color,
    bool? lowStockOnly,
    bool clearCategory = false,
    bool clearColor = false,
  }) {
    return InventoryFilter(
      category: clearCategory ? null : (category ?? this.category),
      color: clearColor ? null : (color ?? this.color),
      lowStockOnly: lowStockOnly ?? this.lowStockOnly,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is InventoryFilter &&
      other.category == category &&
      other.color == color &&
      other.lowStockOnly == lowStockOnly;

  @override
  int get hashCode => Object.hash(category, color, lowStockOnly);
}

/// Result of a single page read.
class InventoryPage {
  const InventoryPage({
    required this.items,
    required this.lastDoc,
    required this.hasMore,
  });

  final List<InventoryItem> items;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;
}

class InventoryRepository {
  InventoryRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  }) : _firestore = firestore,
       _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('InventoryRepository requires a signed-in user.');
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return _firestore.collection('merchants').doc(uid).collection('inventory');
  }

  /// Reads one paginated, server-filtered page. Every query is bounded
  /// by [kInventoryPageSize] — never unbounded.
  Future<InventoryPage> fetchPage({
    required InventoryFilter filter,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    final uid = _requireUid();
    Query<Map<String, dynamic>> q = _collection(uid);
    if (filter.category != null && filter.category!.isNotEmpty) {
      q = q.where('category', isEqualTo: filter.category);
    }
    if (filter.color != null && filter.color!.isNotEmpty) {
      q = q.where('color', arrayContains: filter.color);
    }
    if (filter.lowStockOnly) {
      q = q.where('lowStock', isEqualTo: true);
    }
    q = q.orderBy('updatedAt', descending: true).limit(kInventoryPageSize);
    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }
    final snap = await q.get();
    final items = snap.docs.map(InventoryItem.fromDoc).toList();
    return InventoryPage(
      items: items,
      lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
      hasMore: snap.docs.length == kInventoryPageSize,
    );
  }

  Future<InventoryItem> getById(String itemId) async {
    final uid = _requireUid();
    final snap = await _collection(uid).doc(itemId).get();
    if (!snap.exists) {
      throw StateError('Inventory item $itemId not found.');
    }
    return InventoryItem.fromDoc(snap);
  }

  Future<String> create(InventoryItem draft) async {
    final uid = _requireUid();
    final ref = _collection(uid).doc();
    await ref.set(draft.toFirestore(isCreate: true));
    return ref.id;
  }

  /// Creates the document at an explicit [itemId]. Used by the inventory
  /// form so the image upload path and Firestore document share the
  /// same stable ID — retrying a failed save is idempotent instead of
  /// leaving orphaned placeholder documents behind.
  Future<void> createWithId(String itemId, InventoryItem draft) async {
    final uid = _requireUid();
    await _collection(uid).doc(itemId).set(draft.toFirestore(isCreate: true));
  }

  Future<void> update(InventoryItem item) async {
    final uid = _requireUid();
    await _collection(
      uid,
    ).doc(item.id).update(item.toFirestore(isCreate: false));
  }

  Future<void> delete(String itemId) async {
    final uid = _requireUid();
    await _collection(uid).doc(itemId).delete();
  }
}

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});
