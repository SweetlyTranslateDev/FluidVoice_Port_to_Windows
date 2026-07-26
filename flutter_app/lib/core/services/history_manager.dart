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

  Future<void> load() async {
    _entries
      ..clear()
      ..addAll(await _store.loadEntries());
  }

  Future<void> addFromResult(TranscriptResult result) async {
    final entry = HistoryEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: result.text,
      rawText: result.rawText,
      createdAt: DateTime.now(),
    );
    _entries.insert(0, entry);
    await _store.saveEntries(_entries);
  }

  Future<void> clear() async {
    _entries.clear();
    await _store.saveEntries(_entries);
  }
}
