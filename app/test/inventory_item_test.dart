import 'package:flutter_test/flutter_test.dart';
import 'package:vanij/features/inventory/data/models/inventory_item.dart';

void main() {
  group('InventoryItem.computeLowStock', () {
    test('returns true when any size has < 3 units', () {
      expect(InventoryItem.computeLowStock({'S': 5, 'M': 2, 'L': 10}), isTrue);
    });

    test('returns false when every size has >= 3 units', () {
      expect(InventoryItem.computeLowStock({'S': 3, 'M': 4, 'L': 10}), isFalse);
    });

    test('returns true when quantity map is empty', () {
      expect(InventoryItem.computeLowStock(const {}), isTrue);
    });
  });

  group('InventoryItem.totalQuantity', () {
    test('sums quantities across sizes', () {
      final item = InventoryItem(
        id: 'x',
        name: 'Saree',
        category: 'Saree',
        colors: const ['Red'],
        sizes: const ['Free'],
        quantity: const {'Free': 7},
        price: 1999,
        costPrice: 1200,
        imageUrl: '',
        pattern: null,
        lowStock: false,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      expect(item.totalQuantity, 7);
    });
  });
}
