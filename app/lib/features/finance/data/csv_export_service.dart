import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/security/ledger_cipher.dart';
import 'ledger_repository.dart';

/// Exports a date range of ledger entries to a CSV file inside the
/// app's sandboxed documents directory. The UPI reference is decrypted
/// locally via [LedgerCipher] at export time — plaintext never leaves
/// the device over the network.
class CsvExportService {
  CsvExportService({
    required LedgerRepository repository,
    required LedgerCipher cipher,
  }) : _repository = repository,
       _cipher = cipher;

  final LedgerRepository _repository;
  final LedgerCipher _cipher;

  Future<File> exportRange({
    required DateTime from,
    required DateTime to,
  }) async {
    final entries = await _repository.fetchRange(from: from, to: to);
    final rows = <List<Object?>>[
      ['id', 'date', 'type', 'amount', 'note', 'itemRef', 'upiRef'],
    ];
    final isoDate = DateFormat('yyyy-MM-dd HH:mm:ss');
    for (final e in entries) {
      rows.add([
        e.id,
        isoDate.format(e.date.toLocal()),
        e.type.wireName,
        e.amount,
        e.note ?? '',
        e.itemRef ?? '',
        e.upiRefEncrypted == null
            ? ''
            : await _decryptQuiet(e.upiRefEncrypted!),
      ]);
    }
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/vanij_ledger_$stamp.csv');
    await file.writeAsString(csv, flush: true);
    return file;
  }

  Future<String> _decryptQuiet(String envelope) async {
    try {
      return await _cipher.decrypt(envelope);
    } catch (_) {
      // Device key missing (e.g. user re-installed) — emit a marker
      // rather than failing the whole export.
      return '<decrypt-failed>';
    }
  }
}

final csvExportServiceProvider = Provider<CsvExportService>((ref) {
  return CsvExportService(
    repository: ref.watch(ledgerRepositoryProvider),
    cipher: ref.watch(ledgerCipherProvider),
  );
});
