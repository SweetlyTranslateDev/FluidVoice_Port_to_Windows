import '../models/transcript_models.dart';
import '../storage/history_store.dart';

class HistoryEntry {
  HistoryEntry({
    required this.id,
    required this.text,
    required this.createdAt,
    this.rawText,
  });

  final String id;
  final String text;
  final DateTime createdAt;
  final String? rawText;
}

/// Transcription history owned by Dart core.
class HistoryManager {
  HistoryManager(this._store);

  final HistoryStore _store;
  final List<HistoryEntry> _entries = [];

  List<HistoryEntry> get entries => List.unmodifiable(_entries);

  Future<void> load({int retentionDays = 0}) async {
    _entries
      ..clear()
      ..addAll(await _store.loadEntries());
    await pruneOlderThan(retentionDays);
  }

  Future<void> addFromResult(
    TranscriptResult result, {
    int retentionDays = 0,
  }) async {
    final entry = HistoryEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: result.text,
      rawText: result.rawText,
      createdAt: DateTime.now(),
    );
    _entries.insert(0, entry);
    await pruneOlderThan(retentionDays);
  }

  /// Removes entries older than [retentionDays]. `0` / negative keeps all.
  Future<void> pruneOlderThan(int retentionDays) async {
    if (retentionDays <= 0) {
      await _store.saveEntries(_entries);
      return;
    }
    final cutoff = DateTime.now().subtract(Duration(days: retentionDays));
    _entries.removeWhere((e) => e.createdAt.isBefore(cutoff));
    await _store.saveEntries(_entries);
  }

  Future<void> clear() async {
    _entries.clear();
    await _store.saveEntries(_entries);
  }
}
