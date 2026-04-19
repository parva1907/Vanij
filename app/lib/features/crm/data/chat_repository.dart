import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import 'models/chat_message.dart';

/// Page size for chat history reads. WhatsApp-style screens typically
/// fetch 30–50 rows at a time — we match the inventory/ledger limit.
const int kChatHistoryPageSize = 40;

class ChatRepository {
  ChatRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  }) : _firestore = firestore,
       _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('ChatRepository requires a signed-in user.');
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _messages(
    String uid,
    String customerId,
  ) {
    return _firestore
        .collection('merchants')
        .doc(uid)
        .collection('customers')
        .doc(customerId)
        .collection('messages');
  }

  DocumentReference<Map<String, dynamic>> _customer(
    String uid,
    String customerId,
  ) {
    return _firestore
        .collection('merchants')
        .doc(uid)
        .collection('customers')
        .doc(customerId);
  }

  /// Live stream of the most recent [kChatHistoryPageSize] messages,
  /// ordered newest-first so the chat list can render in reverse.
  Stream<List<ChatMessage>> watchRecent(String customerId) {
    final uid = _requireUid();
    return _messages(uid, customerId)
        .orderBy('createdAt', descending: true)
        .limit(kChatHistoryPageSize)
        .snapshots()
        .map((snap) => snap.docs.map(ChatMessage.fromDoc).toList());
  }

  /// Append a new message and bump the parent customer's
  /// `lastMessageAt` + `updatedAt` inside a batch so the list view
  /// re-orders atomically.
  Future<String> sendMessage({
    required String customerId,
    required ChatMessage draft,
  }) async {
    final uid = _requireUid();
    final batch = _firestore.batch();
    final ref = _messages(uid, customerId).doc();
    batch.set(ref, draft.toCreatePayload());
    batch.update(_customer(uid, customerId), <String, dynamic>{
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return ref.id;
  }

  /// Merchant override of an existing message body. Rules enforce that
  /// `sender` is unchanged — [ChatMessage.toUpdatePayload] re-sends the
  /// original sender value along with the new body.
  Future<void> editMessage({
    required String customerId,
    required ChatMessage message,
  }) async {
    final uid = _requireUid();
    await _messages(
      uid,
      customerId,
    ).doc(message.id).update(message.toUpdatePayload());
  }

  /// Delete a message. Rules currently permit owner deletes; merchants
  /// may want to clean up accidental sends.
  Future<void> deleteMessage({
    required String customerId,
    required String messageId,
  }) async {
    final uid = _requireUid();
    await _messages(uid, customerId).doc(messageId).delete();
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});
