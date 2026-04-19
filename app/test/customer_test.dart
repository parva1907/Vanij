import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanij/features/crm/data/models/customer.dart';

// ignore: subtype_of_sealed_class
class _FakeDoc extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDoc(this._id, this._data);
  final String _id;
  final Map<String, dynamic>? _data;

  @override
  String get id => _id;

  @override
  Map<String, dynamic>? data() => _data;
}

void main() {
  group('Customer', () {
    test('toCreatePayload omits optional fields when empty', () {
      final c = Customer(
        id: '',
        name: 'Aman',
        phoneEncrypted: 'BASE64==',
        createdAt: DateTime(2024, 1, 1),
      );
      final payload = c.toCreatePayload();
      expect(payload['name'], 'Aman');
      expect(payload['phoneEncrypted'], 'BASE64==');
      expect(payload.containsKey('tags'), isFalse);
      expect(payload.containsKey('notes'), isFalse);
      expect(payload.containsKey('phone'), isFalse);
    });

    test('toCreatePayload never includes plaintext phone key', () {
      final c = Customer(
        id: '',
        name: 'Aman',
        phoneEncrypted: 'BASE64==',
        createdAt: DateTime(2024, 1, 1),
        tags: const ['vip', 'diwali'],
        notes: 'Regular buyer',
      );
      final payload = c.toCreatePayload();
      expect(payload.containsKey('phone'), isFalse);
      expect(payload['tags'], ['vip', 'diwali']);
      expect(payload['notes'], 'Regular buyer');
    });

    test('toUpdatePayload bumps updatedAt and resends required fields', () {
      final c = Customer(
        id: 'abc',
        name: 'Aman',
        phoneEncrypted: 'BASE64==',
        createdAt: DateTime(2024, 1, 1),
      );
      final payload = c.toUpdatePayload();
      expect(payload['name'], 'Aman');
      expect(payload['phoneEncrypted'], 'BASE64==');
      expect(payload.containsKey('updatedAt'), isTrue);
      expect(payload.containsKey('phone'), isFalse);
    });

    test('fromDoc parses tags and timestamps defensively', () {
      final doc = _FakeDoc('cid', {
        'name': 'Aman',
        'phoneEncrypted': 'BASE64==',
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
        'tags': ['vip', 42, 'loyal'],
      });
      final c = Customer.fromDoc(doc);
      expect(c.id, 'cid');
      expect(c.name, 'Aman');
      expect(c.tags, ['vip', 'loyal']);
      expect(c.createdAt.year, 2024);
      expect(c.updatedAt, isNull);
      expect(c.lastMessageAt, isNull);
    });
  });
}
