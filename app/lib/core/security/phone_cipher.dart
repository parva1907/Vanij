import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'aes_gcm_cipher.dart';

/// AES-256-GCM helper for sensitive customer fields (phone numbers).
///
/// Thin alias over [AesGcmCipher] with a dedicated keystore namespace
/// so a compromise of the ledger key cannot decrypt phone numbers and
/// vice-versa. See [AesGcmCipher] for the full security contract.
class PhoneCipher extends AesGcmCipher {
  PhoneCipher({super.storage, super.algorithm, super.rng})
    : super(storageKey: 'vanij.phone.aes256.v1');
}

/// Single app-wide cipher instance. Keyed off Riverpod so tests can
/// override it with an in-memory version.
final phoneCipherProvider = Provider<PhoneCipher>((ref) {
  return PhoneCipher();
});
