/// Thin wrapper over Firebase Analytics exposing only the bounded
/// event set we support (``events.dart``). Call sites never pass raw
/// strings — they call ``logSignInSuccess()`` / ``logInventoryCreated``
/// etc. — which keeps PII out of the analytics payload structurally.
library;

import 'package:firebase_analytics/firebase_analytics.dart';

import 'events.dart';

class AnalyticsService {
  AnalyticsService(this._analytics);

  final FirebaseAnalytics _analytics;

  /// Bind the signed-in user id. Firebase Analytics hashes it on the
  /// device; we intentionally do not pass any other PII here.
  Future<void> setUserId(String? uid) => _analytics.setUserId(id: uid);

  Future<void> logSignInSuccess({required String method}) {
    return _analytics.logEvent(
      name: VanijEvents.signInSuccess,
      parameters: {'method': method},
    );
  }

  Future<void> logInventoryCreated({required String category}) {
    return _analytics.logEvent(
      name: VanijEvents.inventoryItemCreated,
      parameters: {'category': category},
    );
  }

  Future<void> logLedgerEntryAdded({required String type}) {
    return _analytics.logEvent(
      name: VanijEvents.ledgerEntryAdded,
      parameters: {'type': type},
    );
  }

  Future<void> logChatMessageSent() {
    return _analytics.logEvent(name: VanijEvents.chatMessageSent);
  }

  Future<void> logAgentDraftReviewed({required bool edited}) {
    return _analytics.logEvent(
      name: VanijEvents.agentDraftReviewed,
      parameters: {'edited': edited ? 1 : 0},
    );
  }
}
