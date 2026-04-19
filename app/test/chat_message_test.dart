import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanij/features/crm/data/models/chat_message.dart';

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
  group('ChatMessage', () {
    test('ChatSender.fromWire maps all enum values round-trip', () {
      for (final s in ChatSender.values) {
        expect(ChatSender.fromWire(s.wireName), s);
      }
    });

    test('ChatSender.fromWire falls back to merchant for unknown input', () {
      expect(ChatSender.fromWire('mystery'), ChatSender.merchant);
    });

    test('toCreatePayload emits body, sender, and createdAt only', () {
      final m = ChatMessage(
        id: '',
        sender: ChatSender.merchant,
        body: 'Hello',
        createdAt: DateTime(2024, 1, 1),
      );
      final payload = m.toCreatePayload();
      expect(payload['sender'], 'merchant');
      expect(payload['body'], 'Hello');
      expect(payload.containsKey('createdAt'), isTrue);
      expect(payload.containsKey('edited'), isFalse);
    });

    test('toUpdatePayload keeps original sender and marks edited', () {
      final m = ChatMessage(
        id: 'mid',
        sender: ChatSender.agent,
        body: 'Original',
        createdAt: DateTime(2024, 1, 1),
      );
      final updated = m.copyWith(body: 'Overridden by merchant', edited: true);
      final payload = updated.toUpdatePayload();
      expect(payload['sender'], 'agent');
      expect(payload['body'], 'Overridden by merchant');
      expect(payload['edited'], true);
      expect(payload.containsKey('editedAt'), isTrue);
    });

    test('fromDoc parses edited flag with safe default', () {
      final doc = _FakeDoc('m1', {
        'sender': 'customer',
        'body': 'Hi',
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
      });
      final m = ChatMessage.fromDoc(doc);
      expect(m.sender, ChatSender.customer);
      expect(m.edited, false);
    });
  });
}
