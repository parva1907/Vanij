import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanij/core/security/ledger_cipher.dart';

/// In-memory double for the platform [FlutterSecureStorage] — lets us
/// exercise [LedgerCipher] in a pure Dart unit test without spinning
/// up a real MethodChannel / Android Keystore.
class _FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _store.remove(key);
    } else {
      _store[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _store[key];
  }

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _store.containsKey(key);
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _store.remove(key);
  }

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return Map.of(_store);
  }

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _store.clear();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('LedgerCipher', () {
    test('round-trips plaintext through AES-256-GCM', () async {
      final cipher = LedgerCipher(storage: _FakeSecureStorage());
      const input = 'UPI/REF/ABCD1234';
      final envelope = await cipher.encrypt(input);
      expect(envelope, isNot(equals(input)));
      expect(envelope.length, greaterThan(input.length));
      final out = await cipher.decrypt(envelope);
      expect(out, equals(input));
    });

    test(
      'two encryptions of the same plaintext produce different blobs',
      () async {
        final cipher = LedgerCipher(storage: _FakeSecureStorage());
        const input = 'UPI/REF/SAME';
        final a = await cipher.encrypt(input);
        final b = await cipher.encrypt(input);
        expect(
          a,
          isNot(equals(b)),
          reason: 'nonce reuse — would leak information',
        );
        expect(await cipher.decrypt(a), equals(input));
        expect(await cipher.decrypt(b), equals(input));
      },
    );

    test('rejects empty plaintext', () async {
      final cipher = LedgerCipher(storage: _FakeSecureStorage());
      expect(() => cipher.encrypt(''), throwsArgumentError);
    });

    test('decryption fails on tampered ciphertext', () async {
      final cipher = LedgerCipher(storage: _FakeSecureStorage());
      final envelope = await cipher.encrypt('UPI/REF/TAMPER');
      // Flip one character near the end (inside the MAC region).
      final bad =
          envelope.substring(0, envelope.length - 4) +
          (envelope.endsWith('A') ? 'BBBB' : 'AAAA');
      expect(() => cipher.decrypt(bad), throwsA(isA<Exception>()));
    });

    test('reuses the same key across cipher instances (persisted)', () async {
      final storage = _FakeSecureStorage();
      final first = LedgerCipher(storage: storage);
      final envelope = await first.encrypt('UPI/REF/SHARED');
      // Second instance shares the underlying storage, so it must read
      // the same key back and decrypt successfully.
      final second = LedgerCipher(storage: storage);
      expect(await second.decrypt(envelope), equals('UPI/REF/SHARED'));
    });

    test('concurrent first-use calls share a single generated key', () async {
      final storage = _FakeSecureStorage();
      final cipher = LedgerCipher(storage: storage);
      // Fire many encryptions concurrently on a fresh storage so the
      // key-load path races with itself.
      final blobs = await Future.wait([
        for (var i = 0; i < 16; i++) cipher.encrypt('UPI/REF/RACE-$i'),
      ]);
      final all = await storage.readAll();
      expect(
        all.length,
        1,
        reason: 'multiple keys would indicate a race-generated second key',
      );
      // Every blob must decrypt with the single persisted key.
      final fresh = LedgerCipher(storage: storage);
      for (var i = 0; i < blobs.length; i++) {
        expect(await fresh.decrypt(blobs[i]), 'UPI/REF/RACE-$i');
      }
    });

    test('nonces are not repeated over 64 consecutive encryptions', () async {
      final cipher = LedgerCipher(
        storage: _FakeSecureStorage(),
        rng: Random.secure(),
      );
      final seen = <String>{};
      for (var i = 0; i < 64; i++) {
        final blob = await cipher.encrypt('UPI/REF/$i');
        // Nonce is the first 12 bytes — compare prefix.
        final prefix = blob.substring(0, 16);
        expect(
          seen.add(prefix),
          isTrue,
          reason: 'nonce collision on iteration $i',
        );
      }
    });
  });
}
