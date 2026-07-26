import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'settings_store.dart';

/// Persists settings as JSON under the app support directory.
class JsonSettingsStore implements SettingsStore {
  JsonSettingsStore({String fileName = 'settings.json'}) : _fileName = fileName;

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
  Future<Map<String, String>> readAll() async {
    final file = await _ensureFile();
    if (!await file.exists()) {
      return {};
    }
    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) {
        return {};
      }
      return {
        for (final entry in raw.entries)
          entry.key.toString(): entry.value?.toString() ?? '',
      };
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> writeAll(Map<String, String> values) async {
    final file = await _ensureFile();
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(values));
  }
}
