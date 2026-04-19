import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanij/core/security/phone_cipher.dart';

class _FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _store = {};

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
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => Map.of(_store);
}

void main() {
  group('PhoneCipher', () {
    test('uses a keystore namespace distinct from LedgerCipher', () async {
      final storage = _FakeSecureStorage();
      final cipher = PhoneCipher(storage: storage, rng: Random(1));
      await cipher.encrypt('+91 98765 43210');
      final keys = (await storage.readAll()).keys.toList();
      expect(keys.length, 1);
      expect(keys.first, 'vanij.phone.aes256.v1');
      // The ledger namespace must not be touched by phone operations.
      expect(keys, isNot(contains('vanij.ledger.aes256.v1')));
    });

    test('round-trips a phone number', () async {
      final cipher = PhoneCipher(storage: _FakeSecureStorage(), rng: Random(2));
      final ct = await cipher.encrypt('+91 98765 43210');
      expect(await cipher.decrypt(ct), '+91 98765 43210');
    });

    test('concurrent first-use calls share a single generated key', () async {
      final storage = _FakeSecureStorage();
      final cipher = PhoneCipher(storage: storage);
      final blobs = await Future.wait([
        for (var i = 0; i < 16; i++) cipher.encrypt('+91 99999 0000$i'),
      ]);
      final all = await storage.readAll();
      expect(all.length, 1);
      final fresh = PhoneCipher(storage: storage);
      for (var i = 0; i < blobs.length; i++) {
        expect(await fresh.decrypt(blobs[i]), '+91 99999 0000$i');
      }
    });
  });
}
