/// Vanij analytics event catalogue (Sprint 8).
///
/// Analytics exists to answer two questions only:
/// - Is the merchant actually reaching the main verbs (create item,
///   log ledger entry, reply to a customer)?
/// - Is the agent draft flow being used or edited before send?
///
/// Per spec rule #3, no customer content, no UPI ref, no phone, no
/// message body may be logged. Every event here carries either no
/// parameters or bounded integers/enums.
library;

/// Canonical event names. Firebase Analytics truncates above 40 chars
/// and rejects hyphens, so we stick to snake_case ≤ 40.
class VanijEvents {
  VanijEvents._();

  /// Sign-in completed (email or Google). No uid in params — Firebase
  /// Analytics already binds the user via ``setUserId`` at install.
  static const signInSuccess = 'sign_in_success';

  /// Merchant finished the "new inventory item" flow. Carries only
  /// the category enum (e.g. "Saree") so we can see mix.
  static const inventoryItemCreated = 'inventory_item_created';

  /// Merchant created a ledger entry. Carries the ``type`` enum only
  /// (sale / expense / refund) — NEVER the amount or the UPI ref.
  static const ledgerEntryAdded = 'ledger_entry_added';

  /// Merchant sent a chat message to a customer (via the composer).
  /// No params — a counter per merchant.
  static const chatMessageSent = 'chat_message_sent';

  /// Merchant reviewed an agent draft and either sent as-is or edited.
  /// Carries a single ``edited`` boolean so we can see how often the
  /// agent's output was kept verbatim.
  static const agentDraftReviewed = 'agent_draft_reviewed';
}
