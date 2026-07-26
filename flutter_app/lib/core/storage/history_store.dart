import '../services/history_manager.dart';

abstract class HistoryStore {
  Future<List<HistoryEntry>> loadEntries();

  Future<void> saveEntries(List<HistoryEntry> entries);
}

class InMemoryHistoryStore implements HistoryStore {
  List<HistoryEntry> _entries = [];

  @override
  Future<List<HistoryEntry>> loadEntries() async => List.of(_entries);

  @override
  Future<void> saveEntries(List<HistoryEntry> entries) async {
    _entries = List.of(entries);
  }
}
