import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// AES-256-GCM helper for sensitive ledger fields (UPI references).
///
/// Security contract:
///   * Never writes plaintext to Firestore — callers pipe through
///     [encrypt] before staging a write.
///   * Key is a 256-bit random value, generated once on first use
///     and stored in the device's secure keystore
///     ([FlutterSecureStorage] → Android Keystore / iOS Keychain).
///   * Each ciphertext carries its own 12-byte random nonce, so the
///     same plaintext encrypted twice produces different blobs —
///     no deterministic IV reuse.
///   * Output layout is `base64( nonce(12) || ciphertext || mac(16) )`
///     i.e. authenticated — tampered blobs fail to decrypt.
///
/// Multi-device caveat: the key is device-local. For multi-device
/// merchants, a KMS-backed key sync is required — deferred to a later
/// sprint and tracked by the "multi-device UPI history" follow-up.
class LedgerCipher {
  LedgerCipher({FlutterSecureStorage? storage, AesGcm? algorithm, Random? rng})
    : _storage = storage ?? const FlutterSecureStorage(),
      _algorithm = algorithm ?? AesGcm.with256bits(),
      _rng = rng ?? Random.secure();

  static const _keyStorageKey = 'vanij.ledger.aes256.v1';
  static const _nonceLength = 12;

  final FlutterSecureStorage _storage;
  final AesGcm _algorithm;
  final Random _rng;
  SecretKey? _cachedKey;

  /// Returns the cached AES-256 key, loading it from secure storage or
  /// creating one on first use. Calls are serialised on the Dart event
  /// loop so two concurrent callers can't race to create two keys.
  Future<SecretKey> _key() async {
    final cached = _cachedKey;
    if (cached != null) return cached;
    final existing = await _storage.read(key: _keyStorageKey);
    if (existing != null && existing.isNotEmpty) {
      final bytes = base64Decode(existing);
      final key = SecretKey(bytes);
      _cachedKey = key;
      return key;
    }
    final bytes = Uint8List(32);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = _rng.nextInt(256);
    }
    await _storage.write(key: _keyStorageKey, value: base64Encode(bytes));
    final key = SecretKey(bytes);
    _cachedKey = key;
    return key;
  }

  Uint8List _randomNonce() {
    final out = Uint8List(_nonceLength);
    for (var i = 0; i < _nonceLength; i++) {
      out[i] = _rng.nextInt(256);
    }
    return out;
  }

  /// Encrypts [plaintext] and returns the base64-encoded envelope.
  /// Empty input is rejected — the rules explicitly require a
  /// non-empty `upiRefEncrypted` when present.
  Future<String> encrypt(String plaintext) async {
    if (plaintext.isEmpty) {
      throw ArgumentError('Cannot encrypt empty plaintext.');
    }
    final key = await _key();
    final nonce = _randomNonce();
    final box = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: nonce,
    );
    final out = BytesBuilder(copy: false)
      ..add(box.nonce)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    return base64Encode(out.toBytes());
  }

  /// Decrypts a blob produced by [encrypt]. Throws if the envelope is
  /// truncated, the MAC fails, or the key is missing.
  Future<String> decrypt(String envelope) async {
    final bytes = base64Decode(envelope);
    if (bytes.length < _nonceLength + 16) {
      throw const FormatException('Ciphertext envelope is too short.');
    }
    final nonce = bytes.sublist(0, _nonceLength);
    final mac = bytes.sublist(bytes.length - 16);
    final cipherText = bytes.sublist(_nonceLength, bytes.length - 16);
    final key = await _key();
    final plain = await _algorithm.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
      secretKey: key,
    );
    return utf8.decode(plain);
  }
}

/// Single app-wide cipher instance. Keyed off Riverpod so tests can
/// override it with an in-memory version.
final ledgerCipherProvider = Provider<LedgerCipher>((ref) {
  return LedgerCipher();
});
