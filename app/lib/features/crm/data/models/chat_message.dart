import 'package:cloud_firestore/cloud_firestore.dart';

/// Sender of a chat message. Matches the rule enum
/// `sender in ['merchant', 'customer', 'agent']`.
enum ChatSender {
  merchant,
  customer,
  agent;

  String get wireName => name;

  static ChatSender fromWire(String raw) {
    return ChatSender.values.firstWhere(
      (s) => s.wireName == raw,
      orElse: () => ChatSender.merchant,
    );
  }
}

/// An immutable message under
/// `merchants/{uid}/customers/{id}/messages/{messageId}`.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sender,
    required this.body,
    required this.createdAt,
    this.edited = false,
  });

  final String id;
  final ChatSender sender;
  final String body;
  final DateTime createdAt;

  /// True if the merchant has overridden a previously-written message
  /// (same rule-preserved `sender`, new `body`).
  final bool edited;

  ChatMessage copyWith({String? body, bool? edited}) {
    return ChatMessage(
      id: id,
      sender: sender,
      body: body ?? this.body,
      createdAt: createdAt,
      edited: edited ?? this.edited,
    );
  }

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ChatMessage(
      id: doc.id,
      sender: ChatSender.fromWire((data['sender'] as String?) ?? 'merchant'),
      body: (data['body'] as String?) ?? '',
      createdAt: _toDate(data['createdAt']),
      edited: (data['edited'] as bool?) ?? false,
    );
  }

  /// Firestore payload for `create`. Rules require a non-empty `body`
  /// and `sender` in the allowed enum.
  Map<String, dynamic> toCreatePayload() {
    return <String, dynamic>{
      'sender': sender.wireName,
      'body': body,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Firestore payload for `update`. Rules enforce that `sender` is
  /// not changed, so we re-send the original value unchanged.
  Map<String, dynamic> toUpdatePayload() {
    return <String, dynamic>{
      'sender': sender.wireName,
      'body': body,
      'edited': true,
      'editedAt': FieldValue.serverTimestamp(),
    };
  }
}

DateTime _toDate(Object? v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return DateTime.fromMillisecondsSinceEpoch(0);
}
