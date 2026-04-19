import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Reusable AES-256-GCM helper for sensitive string fields.
///
/// Security contract:
///   * Never writes plaintext to Firestore — callers pipe through
///     [encrypt] before staging a write.
///   * Key is a 256-bit random value, generated once on first use
///     and stored in the device's secure keystore
///     ([FlutterSecureStorage] → Android Keystore / iOS Keychain),
///     namespaced by [storageKey] so different sensitive fields get
///     independent keys.
///   * Each ciphertext carries its own 12-byte random nonce, so the
///     same plaintext encrypted twice produces different blobs —
///     no deterministic IV reuse.
///   * Output layout is `base64( nonce(12) || ciphertext || mac(16) )`
///     i.e. authenticated — tampered blobs fail to decrypt.
///
/// Multi-device caveat: the key is device-local. For multi-device
/// merchants, a KMS-backed key sync is required — deferred.
class AesGcmCipher {
  AesGcmCipher({
    required this.storageKey,
    FlutterSecureStorage? storage,
    AesGcm? algorithm,
    Random? rng,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _algorithm = algorithm ?? AesGcm.with256bits(),
       _rng = rng ?? Random.secure();

  /// Namespaced key name under which the 256-bit AES key is persisted.
  /// Different sensitive fields (ledger UPI, customer phone, ...) pass
  /// distinct values so one key's compromise doesn't cross-contaminate.
  final String storageKey;
  static const _nonceLength = 12;

  final FlutterSecureStorage _storage;
  final AesGcm _algorithm;
  final Random _rng;

  /// Shared future for the key-load. Using a single future (not a
  /// resolved value) means every concurrent caller awaits the same
  /// load/generate flow — no race window where two callers both see
  /// the keystore empty and both write a fresh key.
  Future<SecretKey>? _keyFuture;

  Future<SecretKey> _key() {
    return _keyFuture ??= _loadOrCreateKey();
  }

  Future<SecretKey> _loadOrCreateKey() async {
    try {
      final existing = await _storage.read(key: storageKey);
      if (existing != null && existing.isNotEmpty) {
        return SecretKey(base64Decode(existing));
      }
      final bytes = Uint8List(32);
      for (var i = 0; i < bytes.length; i++) {
        bytes[i] = _rng.nextInt(256);
      }
      await _storage.write(key: storageKey, value: base64Encode(bytes));
      return SecretKey(bytes);
    } catch (e) {
      _keyFuture = null;
      rethrow;
    }
  }

  Uint8List _randomNonce() {
    final out = Uint8List(_nonceLength);
    for (var i = 0; i < _nonceLength; i++) {
      out[i] = _rng.nextInt(256);
    }
    return out;
  }

  /// Encrypts [plaintext] and returns the base64-encoded envelope.
  /// Empty input is rejected — rules require non-empty ciphertext
  /// fields when present.
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
