import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'aes_gcm_cipher.dart';

/// AES-256-GCM helper for sensitive ledger fields (UPI references).
///
/// Thin alias over [AesGcmCipher] with a dedicated keystore namespace.
/// See [AesGcmCipher] for the full security contract.
class LedgerCipher extends AesGcmCipher {
  LedgerCipher({super.storage, super.algorithm, super.rng})
    : super(storageKey: 'vanij.ledger.aes256.v1');
}

/// Single app-wide cipher instance. Keyed off Riverpod so tests can
/// override it with an in-memory version.
final ledgerCipherProvider = Provider<LedgerCipher>((ref) {
  return LedgerCipher();
});
