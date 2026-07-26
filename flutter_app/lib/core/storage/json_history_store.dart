import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../services/history_manager.dart';
import 'history_store.dart';

/// Persists transcription history as JSON under the app support directory.
class JsonHistoryStore implements HistoryStore {
  JsonHistoryStore({String fileName = 'history.json'}) : _fileName = fileName;

  final String _fileName;
  File? _file;

  Future<File> _ensureFile() async {
    if (_file != null) {
      return _file!;
    }
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'FluidVoice'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _file = File(p.join(dir.path, _fileName));
    return _file!;
  }

  @override
  Future<List<HistoryEntry>> loadEntries() async {
    final file = await _ensureFile();
    if (!await file.exists()) {
      return [];
    }
    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is! List) {
        return [];
      }
      return [
        for (final item in raw)
          if (item is Map)
            HistoryEntry(
              id: item['id']?.toString() ?? '',
              text: item['text']?.toString() ?? '',
              rawText: item['rawText']?.toString(),
              createdAt: DateTime.tryParse(item['createdAt']?.toString() ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0),
            ),
      ].where((e) => e.id.isNotEmpty && e.text.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveEntries(List<HistoryEntry> entries) async {
    final file = await _ensureFile();
    final payload = [
      for (final e in entries)
        {
          'id': e.id,
          'text': e.text,
          'rawText': e.rawText,
          'createdAt': e.createdAt.toIso8601String(),
        },
    ];
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(payload));
  }
}
