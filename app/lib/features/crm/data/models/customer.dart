import 'package:cloud_firestore/cloud_firestore.dart';

/// An immutable customer row under `merchants/{uid}/customers/{id}`.
///
/// `phoneEncrypted` holds AES-256-GCM ciphertext (base64) of the phone
/// number. Plaintext `phone` is never stored — Firestore rules reject
/// any write that contains the `phone` key. Decryption happens on-device
/// via [PhoneCipher] when the merchant opens a customer or exports data.
class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phoneEncrypted,
    required this.createdAt,
    this.updatedAt,
    this.lastMessageAt,
    this.tags = const <String>[],
    this.notes,
  });

  final String id;
  final String name;
  final String phoneEncrypted;
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// Timestamp of the most recent message exchanged with this customer.
  /// Used to sort the customers list in WhatsApp-style recency order.
  final DateTime? lastMessageAt;

  final List<String> tags;
  final String? notes;

  Customer copyWith({
    String? name,
    String? phoneEncrypted,
    DateTime? updatedAt,
    DateTime? lastMessageAt,
    List<String>? tags,
    String? notes,
  }) {
    return Customer(
      id: id,
      name: name ?? this.name,
      phoneEncrypted: phoneEncrypted ?? this.phoneEncrypted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
    );
  }

  factory Customer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Customer(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      phoneEncrypted: (data['phoneEncrypted'] as String?) ?? '',
      createdAt: _toDate(data['createdAt']),
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      lastMessageAt: data['lastMessageAt'] is Timestamp
          ? (data['lastMessageAt'] as Timestamp).toDate()
          : null,
      tags: ((data['tags'] as List?) ?? const <Object?>[])
          .whereType<String>()
          .toList(),
      notes: data['notes'] as String?,
    );
  }

  /// Firestore payload for `create`. Rules require `name` and
  /// `phoneEncrypted`, and reject any `phone` key.
  Map<String, dynamic> toCreatePayload() {
    return <String, dynamic>{
      'name': name,
      'phoneEncrypted': phoneEncrypted,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (tags.isNotEmpty) 'tags': tags,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }

  /// Firestore payload for `update`. Re-sends required fields so rules
  /// keep passing (rules evaluate against `request.resource.data`, not
  /// a diff), bumps `updatedAt`, and never emits a `phone` key.
  Map<String, dynamic> toUpdatePayload() {
    return <String, dynamic>{
      'name': name,
      'phoneEncrypted': phoneEncrypted,
      'updatedAt': FieldValue.serverTimestamp(),
      'tags': tags,
      if (notes != null) 'notes': notes,
    };
  }
}

DateTime _toDate(Object? v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return DateTime.fromMillisecondsSinceEpoch(0);
}
