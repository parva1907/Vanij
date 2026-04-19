import 'package:cloud_firestore/cloud_firestore.dart';

/// A single inventory item held by a merchant.
///
/// Fields mirror the Vanij spec exactly — `name, category, color[],
/// pattern, size[], quantity{}, price, costPrice, imageUrl` — plus
/// derived `lowStock` (denormalised for the composite index) and audit
/// timestamps.
///
/// `quantity` is a map of size → count. `lowStock` is `true` when **any**
/// size has `count < 3` (per the spec). The flag is denormalised so
/// Firestore can serve the "low-stock" filter from its composite index
/// instead of us filtering client-side, which would violate the
/// "never client-side filtering" rule.
class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.colors,
    required this.sizes,
    required this.quantity,
    required this.price,
    required this.costPrice,
    required this.imageUrl,
    required this.pattern,
    required this.lowStock,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String category;
  final List<String> colors;
  final List<String> sizes;
  final Map<String, int> quantity;
  final double price;
  final double costPrice;
  final String imageUrl;
  final String? pattern;
  final bool lowStock;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Low-stock threshold per spec: any size with fewer than 3 units.
  static const int lowStockThreshold = 3;

  static bool computeLowStock(Map<String, int> quantity) {
    if (quantity.isEmpty) return true;
    return quantity.values.any((q) => q < lowStockThreshold);
  }

  factory InventoryItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawQty = (data['quantity'] as Map?) ?? const {};
    final qty = <String, int>{
      for (final e in rawQty.entries) e.key.toString(): _toInt(e.value),
    };
    return InventoryItem(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      category: (data['category'] as String?) ?? '',
      colors: _stringList(data['color']),
      sizes: _stringList(data['size']),
      quantity: qty,
      price: _toDouble(data['price']),
      costPrice: _toDouble(data['costPrice']),
      imageUrl: (data['imageUrl'] as String?) ?? '',
      pattern: data['pattern'] as String?,
      lowStock: (data['lowStock'] as bool?) ?? computeLowStock(qty),
      createdAt: _toDate(data['createdAt']),
      updatedAt: _toDate(data['updatedAt']),
    );
  }

  /// Firestore payload. Always includes `updatedAt: serverTimestamp()`
  /// and (on create) `createdAt: serverTimestamp()` so listing is
  /// deterministic and index-friendly.
  Map<String, dynamic> toFirestore({required bool isCreate}) {
    return <String, dynamic>{
      'name': name,
      'category': category,
      'color': colors,
      'size': sizes,
      'pattern': pattern,
      'quantity': quantity,
      'price': price,
      'costPrice': costPrice,
      'imageUrl': imageUrl,
      'lowStock': computeLowStock(quantity),
      if (isCreate) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  int get totalQuantity => quantity.values.fold<int>(0, (a, b) => a + b);

  InventoryItem copyWith({
    String? name,
    String? category,
    List<String>? colors,
    List<String>? sizes,
    Map<String, int>? quantity,
    double? price,
    double? costPrice,
    String? imageUrl,
    String? pattern,
  }) {
    return InventoryItem(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      colors: colors ?? this.colors,
      sizes: sizes ?? this.sizes,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      imageUrl: imageUrl ?? this.imageUrl,
      pattern: pattern ?? this.pattern,
      lowStock: computeLowStock(quantity ?? this.quantity),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

double _toDouble(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

int _toInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

List<String> _stringList(Object? v) {
  if (v is List) return v.map((e) => e.toString()).toList();
  return const [];
}

DateTime _toDate(Object? v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return DateTime.fromMillisecondsSinceEpoch(0);
}
